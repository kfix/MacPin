/// MacPin WebViewDelegates
///
/// Handle modal & interactive webview prompts and errors

// lookup table for NSError codes gotten while browsing
// http://nshipster.com/nserror/#nsurlerrordomain-&-cfnetworkerrors
// https://github.com/WebKit/webkit/blob/master/Source/WebKit/mac/Misc/WebKitErrors.h
// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/Shared/API/c/WKErrorRef.h

// overriding right-click context menu: http://stackoverflow.com/a/28981319/3878712

#if os(iOS)
// WebKitError* not defined in iOS. Bizarre.
let WebKitErrorDomain = "WebKitErrorDomain"
#endif

import WebKit
import WebKitPrivates
import UTIKit

extension WKWebView {
	func clone(_ url: URL? = nil) -> MPWebView {
		// create a new MPWebView sharing the same cookie/sesssion data and useragent
		let clone = MPWebView(config: self.configuration, agent: self._customUserAgent)
		if let url = url { clone.gotoURL(url) }
		return clone
	}
}

extension AppScriptRuntime: WKScriptMessageHandler {

	// TODO proper main<->renderer IPC needed .... https://electronjs.org/docs/api/ipc-main
	//	webkit.messageHandlers cannot support a polyfill of electron.ipcRenderer.sendSync
	//		https://electronjs.org/docs/api/ipc-renderer#ipcrenderersendsyncchannel-arg1-arg2-
	//		https://www.chromium.org/developers/design-documents/inter-process-communication#Synchronous_messages
	// https://github.com/XWebView/XWebView/blob/master/XWebView/xwebview.js#L178

	func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
		if let webView = message.webView as? MPWebView {
			//called from JS: webkit.messageHandlers.<messsage.name>.postMessage(<message.body>);
			switch message.name {
				case "MacPinPollStates": // direct poll. app.js needs to authorize this handler per tab
					//FIXME: should iterate message.body's [varnames] to send events for
					webView.evaluateJavaScript( //for now, send an omnibus event with all varnames values
						"window.dispatchEvent(new window.CustomEvent('MacPinWebViewChanged',{'detail':{'transparent': \(webView.transparent)}})); ",
						completionHandler: nil)
				default: break
			}

			if let cbs = messageHandlers[message.name] {
				for cb in cbs {
					warn("\(message.name) cb:`<\(type(of: cb))>`")
						cb.call(withArguments: [webView, message.body])
				}
			} else if jsdelegate.hasProperty(message.name) { // support legacy app.js->{delegate} scripts
				warn("forwarding webkit.messageHandlers.\(message.name) to jsdelegate.\(message.name)(webview,msg)")
				jsdelegate.invokeMethod(message.name, withArguments: [webView, message.body])
			} else {
				warn("unhandled postMessage! \(message.name)() -> \(message.body)")
			}

		}
	}
}

//extension WebViewController: WKUIDelegate { } // javascript prompts, implemented per-platform
// window.beforeunload -> runBeforeUnloadConfirmPanelWithMessage https://github.com/WebKit/webkit/commit/204a88b497f6d2051997226e940f088e6ab51178

@objc extension WebViewController: WKNavigationDelegate, WKNavigationDelegatePrivate {

	// FUTURE: didPerformClientRedirectForNavigation https://github.com/WebKit/webkit/commit/9475f62f3602aa91309f00c64e4430a25d5ae4e9

	func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
		if let url = webView.url {
			warn("'\(url)'")
			// check url against regex'd keys of MatchedAddressOptions
			// or just call a JS delegate to do that?
		}
#if os(iOS)
		UIApplication.sharedApplication().networkActivityIndicatorVisible = true // use webview._networkRequestsInProgress ??
#endif
	}

	func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
		//navigationAction ._originalURL ._userInitiated ._canHandleRequest 13+:._isRedirect 11+:._shouldOpenExternalSchemes 11+:._shouldOpenAppLinks
		if let url = navigationAction.request.url, let scheme = url.scheme {
			switch scheme {
				case "data": fallthrough
				case "file": fallthrough
				case "about": fallthrough
				case "javascript": fallthrough
				case "http": fallthrough
				case "https": break
				default: //weird protocols, or app launches like itmss:
					askToOpenURL(url)
					decisionHandler(.cancel)
			}

			// https://developer.mozilla.org/en-US/docs/Web/HTML/Element/a#attr-target
			let targetIsMainFrame = navigationAction.targetFrame?.isMainFrame ?? false // target == _self

			if browsingReactor.anyHandled(.decideNavigationForURL, url.absoluteString as NSString, webView, targetIsMainFrame) { decisionHandler(.cancel); return }

			switch navigationAction.navigationType {
				case .linkActivated:
#if os(OSX)
					let mousebtn = navigationAction.buttonNumber
					let modkeys = navigationAction.modifierFlags
					if modkeys.contains(.option) { NSWorkspace.shared.open(url) } //alt-click opens externally
						else if modkeys.contains(.command) { popup(webView.clone(url)) } // cmd-click pops open a new tab
						else if modkeys.contains(.command) { popup(MPWebView(url: url as NSURL, agent: webView._customUserAgent)) } // shift-click pops open a new tab w/ new session state
						// FIXME: same keymods should work with Enter in omnibox controller
						else if !browsingReactor.anyHandled(.decideNavigationForClickedURL, url.absoluteString as NSString, webView, targetIsMainFrame) { // allow override from JS
							if navigationAction.targetFrame != nil && mousebtn == 1 { fallthrough } // left-click on in_frame target link
							popup(webView.clone(url)).focus() // clicked out-of-frame target link
							// auto-focusing on these is standard safari behavior
						}
#elseif os(iOS)
					// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/ios/WKActionSheetAssistant.mm
					if !browsingReactor.anyHandled(.decideNavigationForClickedURL, url.absoluteString as NSString, webView, targetIsMainFrame) { // allow override from JS
						if navigationAction.targetFrame != nil { fallthrough } // tapped in_frame target link
						popup(webView.clone(url)).focus() // out of frame target link
					}
#endif
					warn("-> .Cancel -- user clicked <a href=\(url) target!=_self> or middle-clicked: opening externally")
    		        decisionHandler(.cancel)

				// FIXME: allow JS to hook all of these
				case .formSubmitted: fallthrough
				case .formResubmitted:
					if let method = navigationAction.request.httpMethod, let headers = navigationAction.request.allHTTPHeaderFields, method == "POST" { warn("POST \(url) <- headers: \(headers)") }
					if let post = navigationAction.request.httpBody { warn("POSTing body: \(post)") }
					if let postStream = navigationAction.request.httpBodyStream {
						var buffer = [UInt8](repeating: 0, count: 500)
						//while postStream.hasBytesAvailable {
							// err, don't want to loop this with big files.....
							if postStream.read(&buffer, maxLength: buffer.count) > 0 {
								let post = String(bytes: buffer, encoding: String.Encoding.utf8)
								warn("POSTing body: \(post)")
							}
						//]
					}
					fallthrough
				case .backForward: fallthrough
				case .reload: fallthrough
					// FIXME: check if user is forcing Download
				case .other: fallthrough
				default: decisionHandler(.allow)
			}
		} else {
			// invalid url? should raise error
			warn("navType:\(navigationAction.navigationType.rawValue) sourceFrame:(\(navigationAction.sourceFrame.request.url)) -> No URL!")
			decisionHandler(.cancel)
			//decisionHandler(WKNavigationActionPolicy._WKNavigationActionPolicyDownload);
		}
	}

	func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
		guard let url = webView.url else { return }
		warn("~> [\(url)]")
		browsingReactor.anyHandled(.receivedRedirectionToURL, url.absoluteString as NSString, webView)
	}

	func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { //error returned by webkit when loading content
		let url = webView.url ?? URL(string: "about:nil-url")! // no URL? pish-posh!
		// maybe if webView.loadData was used...
		//	& the anon-URL data had a head/metadata redirect to a URL, which failed. oic wut u did there

		warn("'\(url)' -> `\(error.localizedDescription)` [\(error._domain)] [\(error._code)]")

		if let error = error as? LocalizedError, let desc = error.errorDescription, let reas = error.failureReason {
			warn("\(desc): \(reas)")
			//warn(obj: error)
		}

		if let error = error as? URLError { // https://mjtsai.com/blog/2017/07/24/matching-and-bridging-nserrors-in-swfit/
			// https://developer.apple.com/reference/foundation/nsurlerror
			// https://developer.apple.com/documentation/foundation/nsurlerrordomain
			// https://developer.apple.com/documentation/foundation/1508628-url_loading_system_error_codes

			switch (error._domain, error._code) {
				case (NSURLErrorDomain, NSURLErrorCancelled) where !webView.isLoading: return // ignore stopLoading() and HTTP redirects

				case (NSURLErrorDomain, Int(CFNetworkErrors.cfurlErrorServerCertificateUntrusted.rawValue)):
					warn("invalid cert ... need to allow to bypass via allowInsecure & reload?")
					displayError(error as NSError, self)
					// error[_WKRecoveryAttempterErrorKey]: <WKReloadFrameErrorRecoveryAttempter>
					// https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/ErrorHandlingCocoa/ErrorObjectsDomains/ErrorObjectsDomains.html#//apple_ref/doc/uid/TP40001806-CH202-BBCJHJIG
					if (error as NSError).localizedRecoverySuggestion != nil {
						let nserror = error as NSError
						//let rcerror = error as? RecoverableError
						warn("recoverable! `\(nserror.localizedRecoverySuggestion)` opts: [\(nserror.localizedRecoveryOptions)]")
						// https://github.com/WebKit/webkit/blob/1c25b3b7d83b54a1421f187fa01efad7d4d1429a/Source/WebKit/UIProcess/Cocoa/WKReloadFrameErrorRecoveryAttempter.mm#L61
						if let wkrcattempter = nserror.userInfo[_WKRecoveryAttempterErrorKey] {
								warn("wkrecovering! \(wkrcattempter)")
								//(wkrcattempter as! _WKErrorRecoveryAttempting).attemptRecovery()
								// ^^ rebrowses and loops the error ...
								// probably need to add error[NSErrorPeerCertificateChainKey] to the temp cert store for [NSErrorFailingURLKey]
								// or else frobble webView to not care about SSL validity...
							//}
						}
					}

					//warn(String(describing: (error as NSError).recoveryAttempter))
					//warn(String(describing: (error as NSError).localizedRecoveryOptions))
					//	if options = nil , then OK is the only choice ...
					//let underlyingError = (error as NSError).userInfo[NSUnderlyingErrorKey] as? Error ?? error
					//displayError(underlyingError as NSError, self)
					//attemptRecovery()
					fallthrough

				case (NSURLErrorDomain, _):
					// TODO make webView page show the error in-line, like Safari
					// 	also allow the user to then go back to the origin URL (even about:*), and then forward to retry this failed URL, like Safari

					fallthrough // just dump a generic app error for now

				default:
					displayError(error as NSError, self)

			}

		} else {
			// CoreFoundation needs to upgrade its annotations to NS_ERROR_ENUM() so we can enumerate moar errors without hand-casing all of these consts
			// https://github.com/apple/swift-evolution/blob/master/proposals/0112-nserror-bridging.md#importing-error-types-from-objective-c
			// https://github.com/apple/swift-evolution/blob/master/proposals/0112-nserror-bridging.md#better-tooling-for-describing-errors

			switch (error._domain, error._code) {
				// https://developer.apple.com/reference/cfnetwork/cfnetworkerrors
				// https://developer.apple.com/library/mac/documentation/Networking/Reference/CFNetworkErrors/index.html#//apple_ref/c/tdef/CFNetworkErrors
				case (String(kCFErrorDomainCFNetwork), Int(CFNetworkErrors.cfErrorHTTPProxyConnectionFailure.rawValue)):
					UserDefaults.standard.removeObject(forKey: "WebKit2HTTPProxy") // FIXME: should prompt first
					fallthrough //webview.flushProcessPool()
				case (String(kCFErrorDomainCFNetwork), Int(CFNetworkErrors.cfErrorHTTPSProxyConnectionFailure.rawValue)):
					UserDefaults.standard.removeObject(forKey: "WebKit2HTTPSProxy") // FIXME: should prompt first
					fallthrough ////webview.flushProcessPool()
				//case (kCFErrorDomainCFNetwork as NSString, Int(CFNetworkErrors.CFURLErrorZeroByteResource.rawValue)):
				//case (kCFErrorDomainCFNetwork as NSString, Int(CFNetworkErrors.CFErrorHTTPConnectionLost.rawValue)):
				//	fallthrough // retry?
				case (NSURLErrorDomain, Int(CFNetworkErrors.cfurlErrorNotConnectedToInternet.rawValue)):
					// JS console *might* error-say: "Failed to load resource: The Internet connection appears to be offline."
					warn("Network is disconnected?")
					//fallthrough // machine might not be awake and wifi is off
					// URL never appears in the address bar if it was the primary addr
					// this should not be the case. it should show struck-through or red or italic or something.
					// or SOS bonk noises
					browsingReactor.anyHandled(.networkIsOffline, url.absoluteString as NSString, webView)
				case(NSPOSIXErrorDomain, 1): // Operation not permitted
					warn("Sandboxed?")
					//fallthrough
				case(WebKitErrorDomain, kWKErrorCodeFrameLoadInterruptedByPolicyChange): //`Frame load interrupted` WebKitErrorFrameLoadInterruptedByPolicyChange
					warn("Attachment received from an IFrame and was converted to a download? webView.loading == \(webView.isLoading)")
					if let scheme = url.scheme, scheme == "about", let webview = webView as? MPWebView, let hint = URL(string: "about:downloading") {
						webview.gotoURL(hint) // if webview is a stub _blank popup, then indicate its uselessness...
						// FIXME. implement a ".downloader" prop so this can be .hide()n and auto-destructs when done with its transfer ...
					}
					return
				default:
					displayError(error as NSError, self)
			}
		}

		// after return, webView.url seems to revert to pre-navigation value
	}

	func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
		//content starts arriving...I assume <body> has materialized in the DOM?
	}

	func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
		let mime = navigationResponse.response.mimeType!
		let url = navigationResponse.response.url!
		let fn = navigationResponse.response.suggestedFilename!
		//let len = navigationResponse.response.expectedContentLength
		//let enc = navigationResponse.response.textEncodingName

		if navigationResponse.isForMainFrame && browsingReactor.anyHandled(.decideNavigationForMIME, mime as NSString, url.absoluteString as NSString, webView) {
			// runtime claims to have handled the situation, so abort the webview's load
			decisionHandler(.cancel)
			return
		}

		// if explicitly attached as file, download it
		if let httpResponse = navigationResponse.response as? HTTPURLResponse {
			//let code = httpResponse.statusCode
			//let status = NSHTTPURLResponse.localizedStringForStatusCode(code)
			//let hdr = resp.allHeaderFields
			//if let cd = hdr.objectForKey("Content-Disposition") as? String where cd.hasPrefix("attachment") { warn("got attachment! \(cd) \(fn)") }
			if let headers = httpResponse.allHeaderFields as? [String: String], let url = httpResponse.url {
				let cookies = HTTPCookie.cookies(withResponseHeaderFields: headers, for: url)
				//let cookies = NSHTTPCookie._parsedCookiesWithResponseHeaderFields(headers, forURL: url) //ElCap
				for cookie in cookies { browsingReactor.anyHandled(.receivedCookie, webView, cookie.name as NSString, cookie.value as NSString) }
				//FUTURE: API for this https://github.com/WebKit/webkit/commit/a01fab49a9571e9bcf6703b30dadf5419d87bc11

				if let cd = headers["Content-Disposition"], cd.hasPrefix("attachment") {
					// JS hook?
					warn("got attachment! \(cd) \(fn)")
					decisionHandler(_WKNavigationResponsePolicyBecomeDownload)
					return
				}
			}
		}

		if !navigationResponse.canShowMIMEType {
			if !browsingReactor.anyHandled(.handleUnrenderableMIME, mime as NSString, url.absoluteString as NSString, fn as NSString, webView) {
				//let uti = UTI(MIMEType: mime)
				warn("cannot render requested MIME-type:\(mime) @ \(url)")
				// if scheme is not http|https && askToOpenURL(url)
					 // .Cancel & return if we open()'d
				// else if askToOpenURL(open, uti: uti) // if compatible app for mime
					 // .Cancel & return if we open()'d
				// else download it
					decisionHandler(_WKNavigationResponsePolicyBecomeDownload)
					return
			}
		}

		if url.isFileURL && (mime == "audio/mpegurl") {
			// offer to cache HLS streams to an asset for offline-play
			// AVFoundation plugin will not stream from file:///*.m3u8 without caching them
			//  https://github.com/r-plus/HLSion AVAssetDownloadURLSession
			// TODO: need to copy webview's request cookies/headers for remote AVAssetDownloads...
			warn(mime)
			// or ... at least convert to an HTML5 <video> player with the url injected into it
			//   will allow inspector to work properly...dunno about session state (cookies/headers/blah blah)
				//decisionHandler(.Cancel)
		    //webView.goto(MP_HLS_PLAYER_URL + "?src=\(url)")
		}
		decisionHandler(.allow)
	}

	func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { //error during commited main frame navigation
		// like server-issued error Statuses with no page content
		if let url = webView.url {
			warn("[\(url)] -> `\(error.localizedDescription)` [\(error._domain)] [\(error._code)]")
			if error._domain == WebKitErrorDomain && error._code == kWKErrorCodePlugInWillHandleLoad {
				warn("allowing plugin to handle \(url)")
				// FIXME: get MIME somehow?? video/mp4 video/m3u8
				// FIXME: can't catch & handle AVFoundation plugin's errors
				//  [2017-02-22 19:55:57 +0000] <modules/MacPin/WebViewController.swift:78:126> [_webView(_:logDiagnosticMessageWithValue:description:value:)] media || video == loading
				//  [2017-02-22 19:55:57 +0000] <modules/MacPin/WebViewController.swift:78:126> [_webView(_:logDiagnosticMessageWithValue:description:value:)] engineFailedToLoad || AVFoundation == 0
				// GOOD: [2017-02-22 19:57:55 +0000] <modules/MacPin/WebViewController.swift:76:102> [_webView(_:logDiagnosticMessage:description:)] mediaLoaded || AVFoundation
			}
			if error._domain == WebKitErrorDomain && error._code == kWKErrorCodeFrameLoadInterruptedByPolicyChange { warn("IFrame converted to download?") }
			if error._domain == NSURLErrorDomain && error._code != NSURLErrorCancelled { // dont catch on stopLoading() and HTTP redirects
				// needs to be async
				displayError(error as NSError, self)
			}
		}
#if os(iOS)
		UIApplication.sharedApplication().networkActivityIndicatorVisible = false
#endif
    }

	func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
		// no-loads from fresh tabs to pages while offline end up here with no errors fired on provisonal navigation handlers....
		//  need to be able check final disposition here and throw a notification
		//  A navigation object is returned from the web view load methods and is also passed to the navigation delegate methods to uniquely identify a webpage load from start to finish. It has no method or properties of its own.
		// so MPWebView(Controller) needs to track top-level WKNavigations so we can compare the webView.url to see if the related-url for this particular WKNavigation matches it.
		//   if not, then the navigation was unsuccessful (but not failed, and the difference is ...?)
		warn(webView.description)
		//let title = webView.title ?? String()
		//let url = webView.URL ?? NSURL(string:"")!
		//warn("\"\(title)\" [\(url)]")
#if os(iOS)
		UIApplication.sharedApplication().networkActivityIndicatorVisible = false
#endif
	}

	// (webView:createWebViewWithConfiguration:forNavigationAction:windowFeatures:)
	@objc func webView(_ webView: WKWebView, createWebViewWithConfiguration configuration: WKWebViewConfiguration, forNavigationAction navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
	//func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
		// called via JS:window.open()
		// https://developer.mozilla.org/en-US/docs/Web/API/window.open
		// https://developer.apple.com/library/prerelease/ios/documentation/WebKit/Reference/WKWindowFeatures_Ref/index.html

		let srcurl = navigationAction.sourceFrame.request.url
		let openurl = navigationAction.request.url // JS can request a pageless window `window.open()`, but webkit will convert it to about:blank ...
		let tgt: URL? = (navigationAction.targetFrame == nil) ? nil : navigationAction.targetFrame!.request.url
		//let tgtdom = navigationAction.targetFrame?.request.mainDocumentURL ?? NSURL(string:String())!
		//^tgt is given as a string in JS and WKWebView synthesizes a WKFrameInfo from it _IF_ it matches an iframe title in the DOM
		// otherwise == nil
		// RDAR? would like the tgt string to be passed here

		warn("JS <\(srcurl?.absoluteString ?? "")>: `window.open('\(openurl?.absoluteString ?? "")', '\(tgt?.absoluteString ?? "")');`")
		if browsingReactor.anyHandled(.decideWindowOpenForURL, openurl?.absoluteString ?? "", webView) { return nil }
		let wv = MPWebView(config: configuration, agent: webView._customUserAgent)
#if os(OSX)
		if (windowFeatures.allowsResizing ?? 0) == 1 {
			if let window = view.window {
				let newframe = CGRect(
					x: CGFloat(truncating: windowFeatures.x ?? window.frame.origin.x as NSNumber),
					y: CGFloat(truncating: windowFeatures.y ?? window.frame.origin.y as NSNumber),
					width: CGFloat(truncating: windowFeatures.width ?? window.frame.size.width as NSNumber),
					height: CGFloat(truncating: windowFeatures.height ?? window.frame.size.height as NSNumber)
				)
				if !webView.isInFullScreenMode && (!window.styleMask.contains(.fullScreen)) {
					warn("resizing window to match window.open() size parameters passed: origin,size[\(newframe)]")
					window.setFrame(newframe, display: true)
				}
			}
		}
#endif
		//if !tgt.description.isEmpty { evalJS("window.name = '\(tgt)';") }
		if let url = openurl, let scheme = url.scheme, url.scheme != "about" { wv.gotoURL(url) } // decideWindowOpen has allowed us to get this far, so start the load now
		if !browsingReactor.anyHandled(.didWindowOpenForURL, openurl?.absoluteString ?? "", wv, webView) { popup(wv) }
		return wv // window.open() -> Window()
		//return nil //window.open() -> undefined
	}

	func webViewDidClose(_ webView: WKWebView) {
		// https://developer.mozilla.org/en-US/docs/Web/API/Window/close
		// only called for tabs opened by scripts being window.close()d by themselves or by their creating tabs
		warn("JS [\(webView.urlstr)]: window.close();`")
		if !browsingReactor.anyHandled(.didWindowClose, webView) {
			close() // ask parent vc to defenstrate this webview
		}
	}
	//func webViewClose(_ webView: WKWebView) // only Close or DidClose will be called, not both

	//func _webView(_ webView: WKWebView, takeFocus: WKFocusDirection) //.backward .forward
	//func _webViewRunModal(_ webView: WKWebView)
	//func _webViewDidScroll(_ webView: WKWebView)
	//func _webView(_ webView: WKWebView, setWindowFrame: NSRect)
	//func _webView(_ webView: WKWebView, setResizable: Bool)

	//func _showWebView(_ webView: WKWebView)
		// document.hidden document.visibilityState

	func _unfocusWebView(_ webView: WKWebView) {
		// https://developer.mozilla.org/en-US/docs/Web/API/Window/blur
		warn("JS [\(webView.urlstr)]: window.focus();`")
		dismiss() // ask parent vc to conceal this webview
	}

	func _focusWebView(_ webView: WKWebView) {
		// https://developer.mozilla.org/en-US/docs/Web/API/Window/focus
		warn("JS [\(webView.urlstr)]: window.focus();`")
		focus() // ask parent vc to promulgate this webview
		// should consider marking tab "hasBeenFocused+=1" so it can be rate-limited
		//	https://stackoverflow.com/a/11344328/3878712
	}

	func _webViewWebProcessDidCrash(_ webView: WKWebView) {
	    //warn("reloading page")
		//webView.reload()
		warn("webview crashed!!")
	}

	// FIXME: STP v20: per-site preferences: https://github.com/WebKit/webkit/commit/d9f6f7249630d7756e4b6ca572b29ac61d5c38d7
			//if WebKit_version >= (605, 1, 8) {
				//WKWebsitePolicies for header additions https://bugs.webkit.org/show_bug.cgi?id=177255
				//WKDownload.wasUserInitated https://bugs.webkit.org/show_bug.cgi?id=177435
	//func _webView(_ webView: WKWebView!, decidePolicyForNavigationAction navigationAction: WKNavigationAction!, decisionHandler: ((WKNavigationActionPolicy, _WKWebsitePolicies?) -> Void)! {
	//	warn()
	//	decisionHandler() { navPolicy, sitePolicies in
	// 		sitePolicies.customHeaderFields[]
	//	}
	//}

}

extension WebViewController: _WKFormDelegate { } // form input hooks, implemented per-platform
extension WebViewController: _WKFindDelegate { } // text finder handling, implemented per-platform

extension WebViewController: _WKDiagnosticLoggingDelegate {
	func _webView(_ webView: WKWebView, logDiagnosticMessage message: String, description: String) { warn("\(message) || \(description) << \(webView.url?.absoluteString ?? String())") }
	func _webView(_ webView: WKWebView, logDiagnosticMessageWithResult message: String, description: String, result: _WKDiagnosticLoggingResultType) { warn("\(message) || \(description) >> \(String(describing: result)) << \(webView.url?.absoluteString ?? String())") }
	func _webView(_ webView: WKWebView, logDiagnosticMessageWithValue message: String, description: String, value: String) { warn("\(message) || \(description) == \(value) << \(webView.url?.absoluteString ?? String())") }
}

extension WebViewController: _WKDownloadDelegate {
    func _downloadDidStart(_ download: _WKDownload!) { warn(download.request.description) }
	func _download(_ download: _WKDownload!, didReceive response: URLResponse!) { warn(response.description) }
	func _download(_ download: _WKDownload!, didReceiveData length: UInt64) { warn(length.description) }
	func _download(_ download: _WKDownload!, decideDestinationWithSuggestedFilename filename: String!, allowOverwrite: UnsafeMutablePointer<ObjCBool>) -> String! {
		warn("NOIMPL: " + download.request.description)
		download.cancel()
		return ""
	}
	func _downloadDidFinish(_ download: _WKDownload!) { warn(download.request.description) }
	func _download(_ download: _WKDownload!, didFailWithError error: Error!) { warn(error.localizedDescription) }
	func _downloadDidCancel(_ download: _WKDownload!) { warn(download.request.description) }
}

@objc extension WebViewController: _WKIconLoadingDelegate {
	func webView(_ webView: WKWebView, shouldLoadIconWith parameters: _WKLinkIconParameters, completionHandler: (@escaping (Data) -> Void) -> Void) {
		// make doc is wrong about the annotation: https://bugs.swift.org/browse/SR-8873 https://github.com/apple/swift/commit/8cf6189f128c9d6fc409e5826f2cf28019cd6d63
		completionHandler() { [unowned webView] data in
			// data.length
			//parameters . mimeType iconType
			switch parameters.iconType {
				case .favicon:
					warn("page (\(webView.url?.absoluteString ?? "") got favicon from <- \(parameters.url?.absoluteString ?? "")")
					if let webview = webView as? MPWebView {
						webview.favicon.data = data as NSData //skip the middleman
					}
				default: break
			}
		}
	}

}

@available(OSX 10.10, *)
@objc extension WebViewController: WKHistoryDelegatePrivate {
   @objc func _webView(_ webView: WKWebView!, didPerformClientRedirectFrom sourceURL: URL!, to destinationURL: URL!) { warn() }
   @objc func _webView(_ webView: WKWebView!, didPerformServerRedirectFrom sourceURL: URL!, to destinationURL: URL!) { warn() }
   @objc func _webView(_ webView: WKWebView!, didUpdateHistoryTitle title: String!, for URL: URL!) { warn() }
}

@objc extension WebViewController { //WKUIDelegatePrivate .. but platform/Delagtes will declare the conformation
	// https://github.com/WebKit/webkit/blob/master/Tools/TestWebKitAPI/Tests/WebKitCocoa/UIDelegate.mm
	//@objc func _webView(_ webView: WKWebView!, getToolbarsAreVisibleWithCompletionHandler completionHandler: ((Bool) -> Void)!)

	//func _webView(_ webView: WKWebView!, requestNotificationPermissionFor securityOrigin: WKSecurityOrigin!, decisionHandler: ((Bool) -> Void)!) {
	func _webView(_ webView: WKWebView!, requestNotificationPermissionForSecurityOrigin securityOrigin: WKSecurityOrigin!, decisionHandler: ((Bool) -> Void)!) {
		warn("Notification.requestPermission(...) <= \(webView.url?.absoluteString ?? "")")
		//FIXME: prompt
		decisionHandler(true) // Notification.permission == "default" => "granted"
	}

}
