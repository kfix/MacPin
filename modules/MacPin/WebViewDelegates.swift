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
	func clone(_ url: NSURL? = nil) -> MPWebView {
		// create a new MPWebView sharing the same cookie/sesssion data and useragent
		let clone = MPWebView(config: self.configuration, agent: self._customUserAgent)
		if let url = url { clone.gotoURL(url) }
		return clone
	}
}

extension AppScriptRuntime: WKScriptMessageHandler {
	func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
		if let webView = message.webView as? MPWebView {
			//called from JS: webkit.messageHandlers.<messsage.name>.postMessage(<message.body>);
			switch message.name {
				case "getGeolocation":
					Geolocator.shared.sendLocationEvent(webView) // add this webview as a one-time subscriber
				//case "watchGeolocation":
					// Geolocator.subscribeToLocationEvents(webView) // add this webview as a continuous subscriber
				//case "unwatchGeolocation":
					// Geolocator.unsubscribeFromLocationEvents(webView) // remove this webview from subscribers
				case "MacPinPollStates": // direct poll. app.js needs to authorize this handler per tab
					//FIXME: should iterate message.body's [varnames] to send events for
					webView.evaluateJavaScript( //for now, send an omnibus event with all varnames values
						"window.dispatchEvent(new window.CustomEvent('MacPinWebViewChanged',{'detail':{'transparent': \(webView.transparent)}})); ",
						completionHandler: nil)
				default:
					true // no-op
			}

			if jsdelegate.hasProperty(message.name) {
				warn("forwarding webkit.messageHandlers.\(message.name) to jsdelegate.\(message.name)(webview,msg)")
				jsdelegate.invokeMethod(message.name, withArguments: [webView, message.body])
			} else {
				warn("unhandled postMessage! \(message.name)() -> \(message.body)")
			}

		}
	}
}

extension WebViewController: WKUIDelegate { } // javascript prompts, implemented per-platform
// window.beforeunload -> runBeforeUnloadConfirmPanelWithMessage https://github.com/WebKit/webkit/commit/204a88b497f6d2051997226e940f088e6ab51178

extension WebViewController: WKNavigationDelegate, WKNavigationDelegatePrivate {

	// FUTURE: didPerformClientRedirectForNavigation https://github.com/WebKit/webkit/commit/9475f62f3602aa91309f00c64e4430a25d5ae4e9

	func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
		if let url = webView.url {
			warn("'\(url)'")
			// check url against regex'd keys of MatchedAddressOptions
			// or just call a JS delegate to do that?

			if let webview = webView as? MPWebView, let iconDB = webview.iconDB { // pull icon from WebCore's IconDatabase if its already cached
				if let wkurl = WKIconDatabaseCopyIconURLForPageURL(iconDB, WKURLCreateWithCFURL(url as CFURL!)) {
					WKIconDatabaseRetainIconForURL(iconDB, wkurl)
					webview.favicon.url = WKURLCopyCFURL(kCFAllocatorDefault, wkurl) as NSURL
				}
			}
		}
#if os(iOS)
		UIApplication.sharedApplication().networkActivityIndicatorVisible = true // use webview._networkRequestsInProgress ??
#endif
	}

	func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
		if let url = navigationAction.request.url, let scheme = url.scheme {
			switch scheme {
				case "data": fallthrough
				case "file": fallthrough
				case "about": fallthrough
				case "javascript": fallthrough
				case "http": fallthrough
				case "https": break
				default: //weird protocols, or app launches like itmss:
					askToOpenURL(url as NSURL?)
					decisionHandler(.cancel)
			}

			if jsdelegate.tryFunc("decideNavigationForURL", url.absoluteString as NSString, webView) { decisionHandler(.cancel); return }

			switch navigationAction.navigationType {
				case .linkActivated:
#if os(OSX)
					let mousebtn = navigationAction.buttonNumber
					let modkeys = navigationAction.modifierFlags
					if modkeys.contains(.option) { NSWorkspace.shared().open(url) } //alt-click opens externally
						else if modkeys.contains(.command) { popup(webView.clone(url as NSURL?)) } // cmd-click pops open a new tab
						else if modkeys.contains(.command) { popup(MPWebView(url: url as NSURL, agent: webView._customUserAgent)) } // shift-click pops open a new tab w/ new session state
						// FIXME: same keymods should work with Enter in omnibox controller
						else if !jsdelegate.tryFunc("decideNavigationForClickedURL", url.absoluteString as NSString, webView) { // allow override from JS
							if navigationAction.targetFrame != nil && mousebtn == 1 { fallthrough } // left-click on in_frame target link
							popup(webView.clone(url as NSURL?))
						}
#elseif os(iOS)
					// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/ios/WKActionSheetAssistant.mm
					if !jsdelegate.tryFunc("decideNavigationForClickedURL", url.absoluteString as NSString, webView) { // allow override from JS
						if navigationAction.targetFrame != nil { fallthrough } // tapped in_frame target link
						popup(webView.clone(url as NSURL?))  // out of frame target link
					}
#endif
					warn("-> .Cancel -- user clicked <a href=\(url) target=_blank> or middle-clicked: opening externally")
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
		jsdelegate.tryFunc("receivedRedirectionToURL", url.absoluteString as NSString, webView)
	}

	func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { //error returned by webkit when loading content
		if let url = webView.url {
			warn("'\(url)' -> `\(error.localizedDescription)` [\(error._domain)] [\(error._code)]")

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
					jsdelegate.tryFunc("networkIsOffline", url.absoluteString as NSString, webView)
				case(NSPOSIXErrorDomain, 1): // Operation not permitted
					warn("Sandboxed?")
					//fallthrough
				case(WebKitErrorDomain, kWKErrorCodeFrameLoadInterruptedByPolicyChange): //`Frame load interrupted` WebKitErrorFrameLoadInterruptedByPolicyChange
					warn("Attachment received from an IFrame and was converted to a download? webView.loading == \(webView.isLoading)")
					return
				// https://developer.apple.com/reference/foundation/nsurlerror
				case (NSURLErrorDomain, NSURLErrorCancelled) where !webView.isLoading: return // ignore stopLoading() and HTTP redirects
				default:
					displayError(error as NSError, self)
			}
		}
	}

	func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
		//content starts arriving...I assume <body> has materialized in the DOM?
		(webView as? MPWebView)?.scrapeIcon()
	}

	func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
		let mime = navigationResponse.response.mimeType!
		let url = navigationResponse.response.url!
		let fn = navigationResponse.response.suggestedFilename!
		//let len = navigationResponse.response.expectedContentLength
		//let enc = navigationResponse.response.textEncodingName

		if jsdelegate.tryFunc("decideNavigationForMIME", mime as NSString, url.absoluteString as NSString, webView) { decisionHandler(.cancel); return } //FIXME perf hit?

		// if explicitly attached as file, download it
		if let httpResponse = navigationResponse.response as? HTTPURLResponse {
			//let code = httpResponse.statusCode
			//let status = NSHTTPURLResponse.localizedStringForStatusCode(code)
			//let hdr = resp.allHeaderFields
			//if let cd = hdr.objectForKey("Content-Disposition") as? String where cd.hasPrefix("attachment") { warn("got attachment! \(cd) \(fn)") }
			if let headers = httpResponse.allHeaderFields as? [String: String], let url = httpResponse.url {
				let cookies = HTTPCookie.cookies(withResponseHeaderFields: headers, for: url)
				//let cookies = NSHTTPCookie._parsedCookiesWithResponseHeaderFields(headers, forURL: url) //ElCap
				for cookie in cookies { jsdelegate.tryFunc("receivedCookie", webView, cookie.name as NSString, cookie.value as NSString) }
				//FUTURE: API for this https://github.com/WebKit/webkit/commit/a01fab49a9571e9bcf6703b30dadf5419d87bc11

				if let cd = headers["Content-Disposition"], cd.hasPrefix("attachment") {
					// JS hook?
					warn("got attachment! \(cd) \(fn)")
					//decisionHandler(WKNavigationResponsePolicy(rawValue: WKNavigationResponsePolicy.Allow.rawValue + 1)!) // .BecomeDownload - offer to download
					decisionHandler(_WKNavigationResponsePolicyBecomeDownload)
					return
				}
			}
		}

		if !navigationResponse.canShowMIMEType {
			if !jsdelegate.tryFunc("handleUnrenderableMIME", mime as NSString, url.description as NSString, fn as NSString, webView) {
				//let uti = UTI(MIMEType: mime)
				warn("cannot render requested MIME-type:\(mime) @ \(url)")
				// if scheme is not http|https && askToOpenURL(url)
					 // .Cancel & return if we open()'d
				// else if askToOpenURL(open, uti: uti) // if compatible app for mime
					 // .Cancel & return if we open()'d
				// else download it
					decisionHandler(WKNavigationResponsePolicy(rawValue: WKNavigationResponsePolicy.allow.rawValue + 1)!) // .BecomeDownload - offer to download
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
		(webView as? MPWebView)?.scrapeIcon()
#if os(iOS)
		UIApplication.sharedApplication().networkActivityIndicatorVisible = false
#endif
	}

	func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction,
                windowFeatures: WKWindowFeatures) -> WKWebView? {
		// called via JS:window.open()
		// https://developer.mozilla.org/en-US/docs/Web/API/window.open
		// https://developer.apple.com/library/prerelease/ios/documentation/WebKit/Reference/WKWindowFeatures_Ref/index.html

		let srcurl = navigationAction.sourceFrame.request.url ?? NSURL(string:String())! as URL
		let openurl = navigationAction.request.url ?? NSURL(string:String())! as URL
		let tgt = (navigationAction.targetFrame == nil) ? NSURL(string:String())! as URL : navigationAction.targetFrame!.request.url
		//let tgtdom = navigationAction.targetFrame?.request.mainDocumentURL ?? NSURL(string:String())!
		//^tgt is given as a string in JS and WKWebView synthesizes a WKFrameInfo from it _IF_ it matches an iframe title in the DOM
		// otherwise == nil
		// RDAR? would like the tgt string to be passed here

		warn("JS <\(srcurl)>: `window.open(\(openurl), \(tgt));`")
		if jsdelegate.tryFunc("decideWindowOpenForURL", openurl.description as NSString, webView) { return nil }
		let wv = MPWebView(config: configuration, agent: webView._customUserAgent)
		popup(wv)
#if os(OSX)
		if (windowFeatures.allowsResizing ?? 0) == 1 {
			if let window = view.window {
				let newframe = CGRect(
					x: CGFloat(windowFeatures.x ?? window.frame.origin.x as NSNumber),
					y: CGFloat(windowFeatures.y ?? window.frame.origin.y as NSNumber),
					width: CGFloat(windowFeatures.width ?? window.frame.size.width as NSNumber),
					height: CGFloat(windowFeatures.height ?? window.frame.size.height as NSNumber)
				)
				if !webView.isInFullScreenMode && (!window.styleMask.contains(.fullScreen)) {
					warn("resizing window to match window.open() size parameters passed: origin,size[\(newframe)]")
					window.setFrame(newframe, display: true)
				}
			}
		}
#endif
		//if !tgt.description.isEmpty { evalJS("window.name = '\(tgt)';") }
		if !openurl.description.isEmpty { wv.gotoURL(openurl as NSURL) } // this should be deferred with a timer so all chained JS calls on the window.open() instanciation can finish executing
		jsdelegate.tryFunc("DidWindowOpenForURL", openurl.absoluteString as NSString, wv, webView) // allow app.js to tweak any created windows
		return wv // window.open() -> Window()
		//return nil //window.open() -> undefined
	}

	func webViewDidClose(_ webView: WKWebView) {
		warn("JS <\(webView.url)>: `window.close();`")
		dismiss() // FIXME: need to ensure webView was window.open()'d by a JS script
	}

	func _webViewWebProcessDidCrash(_ webView: WKWebView) {
	    //warn("reloading page")
		//webView.reload()
		warn("webview crashed!!")
	}
}

extension WebViewController: _WKFormDelegate { } // form input hooks, implemented per-platform
extension WebViewController: _WKFindDelegate { } // text finder handling, implemented per-platform
