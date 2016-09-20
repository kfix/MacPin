/// MacPin WebViewDelegates
///
/// Handle modal & interactive webview prompts and errors

// WK2 on Mac is missing a <input type="file"> picker & uploader delegate
// iOS WK2: https://github.com/WebKit/webkit/commit/a12c1fc70fa906a39a0593aa4124f24427e232e7
// for now, just drag files onto file-input buttons, it really works!

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
	func clone(url: NSURL? = nil) -> MPWebView {
		// create a new MPWebView sharing the same cookie/sesssion data and useragent
		let clone = MPWebView(config: self.configuration, agent: self._customUserAgent)
		if let url = url { clone.gotoURL(url) }
		return clone
	}
}

extension AppScriptRuntime: WKScriptMessageHandler {
	func userContentController(userContentController: WKUserContentController, didReceiveScriptMessage message: WKScriptMessage) {
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

extension WebViewController: WKNavigationDelegate, WKNavigationDelegatePrivate {
	func webView(webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
		if let url = webView.URL {
			warn("'\(url)'")
			// check url against regex'd keys of MatchedAddressOptions
			// or just call a JS delegate to do that?

			if let webview = webView as? MPWebView, iconDB = webview.iconDB { // pull icon from WebCore's IconDatabase if its already cached
				if let wkurl = WKIconDatabaseCopyIconURLForPageURL(iconDB, WKURLCreateWithCFURL(url)) as? WKURLRef where wkurl != nil {
					WKIconDatabaseRetainIconForURL(iconDB, wkurl)
					webview.favicon.url = WKURLCopyCFURL(kCFAllocatorDefault, wkurl) as NSURL
				}
			}
		}
#if os(iOS)
		UIApplication.sharedApplication().networkActivityIndicatorVisible = true // use webview._networkRequestsInProgress ??
#endif
	}

	func webView(webView: WKWebView, decidePolicyForNavigationAction navigationAction: WKNavigationAction, decisionHandler: (WKNavigationActionPolicy) -> Void) {
		if let url = navigationAction.request.URL, scheme = url.scheme {
			switch scheme {
				case "data": fallthrough
				case "file": fallthrough
				case "about": fallthrough
				case "javascript": fallthrough
				case "http": fallthrough
				case "https": break
				default: //weird protocols, or app launches like itmss:
					askToOpenURL(url)
					decisionHandler(.Cancel)
			}

			if jsdelegate.tryFunc("decideNavigationForURL", url.description, webView) { decisionHandler(.Cancel); return }

			switch navigationAction.navigationType {
				case .LinkActivated:
#if os(OSX)
					let mousebtn = navigationAction.buttonNumber
					let modkeys = navigationAction.modifierFlags
					if modkeys.contains(.Option) { NSWorkspace.sharedWorkspace().openURL(url) } //alt-click opens externally
						else if modkeys.contains(.Command) { popup(webView.clone(url)) } // cmd-click pops open a new tab
						else if modkeys.contains(.Command) { popup(MPWebView(url: url, agent: webView._customUserAgent)) } // shift-click pops open a new tab w/ new session state
						// FIXME: same keymods should work with Enter in omnibox controller
						else if !jsdelegate.tryFunc("decideNavigationForClickedURL", url.description, webView) { // allow override from JS
							if navigationAction.targetFrame != nil && mousebtn == 1 { fallthrough } // left-click on in_frame target link
							popup(webView.clone(url))
						}
#elseif os(iOS)
					// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/ios/WKActionSheetAssistant.mm
					if !jsdelegate.tryFunc("decideNavigationForClickedURL", url.description, webView) { // allow override from JS
						if navigationAction.targetFrame != nil { fallthrough } // tapped in_frame target link
						popup(webView.clone(url))  // out of frame target link
					}
#endif
					warn("-> .Cancel -- user clicked <a href=\(url) target=_blank> or middle-clicked: opening externally")
    		        decisionHandler(.Cancel)

				// FIXME: allow JS to hook all of these
				case .FormSubmitted: fallthrough
				case .FormResubmitted:
					if let method = navigationAction.request.HTTPMethod, headers = navigationAction.request.allHTTPHeaderFields where method == "POST" { warn("POSTing headers: \(headers)") }
					if let post = navigationAction.request.HTTPBody { warn("POSTing body: \(post)") }
					if let postStream = navigationAction.request.HTTPBodyStream {
						var buffer = [UInt8](count: 500, repeatedValue: 0)
						//while postStream.hasBytesAvailable {
							// err, don't want to loop this with big files.....
							if postStream.read(&buffer, maxLength: buffer.count) > 0 {
								let post = String(bytes: buffer, encoding: NSUTF8StringEncoding)
								warn("POSTing body: \(post)")
							}
						//]
					}
					fallthrough
				case .BackForward: fallthrough
				case .Reload: fallthrough
					// FIXME: check if user is forcing Download
				case .Other: fallthrough
				default: decisionHandler(.Allow)
			}
		} else {
			// invalid url? should raise error
			warn("navType:\(navigationAction.navigationType.rawValue) sourceFrame:(\(navigationAction.sourceFrame.request.URL)) -> No URL!")
			decisionHandler(.Cancel)
			//decisionHandler(WKNavigationActionPolicy._WKNavigationActionPolicyDownload);
		}
	}

	func webView(webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
		if let url = webView.URL { warn("~> [\(url)]") }
	}

	func webView(webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: NSError) { //error returned by webkit when loading content
		if let url = webView.URL {
			warn("'\(url)' -> `\(error.localizedDescription)` [\(error.domain)] [\(error.code)] `\(error.localizedFailureReason ?? String())` : \(error.userInfo)")

			switch (error.domain, error.code) {
				// https://developer.apple.com/reference/cfnetwork/cfnetworkerrors
				// https://developer.apple.com/library/mac/documentation/Networking/Reference/CFNetworkErrors/index.html#//apple_ref/c/tdef/CFNetworkErrors
				case (kCFErrorDomainCFNetwork as NSString, Int(CFNetworkErrors.CFErrorHTTPProxyConnectionFailure.rawValue)):
					NSUserDefaults.standardUserDefaults().removeObjectForKey("WebKit2HTTPProxy") // FIXME: should prompt first
					fallthrough //webview.flushProcessPool()
				case (kCFErrorDomainCFNetwork as NSString, Int(CFNetworkErrors.CFErrorHTTPSProxyConnectionFailure.rawValue)):
					NSUserDefaults.standardUserDefaults().removeObjectForKey("WebKit2HTTPSProxy") // FIXME: should prompt first
					fallthrough ////webview.flushProcessPool()
				case(NSPOSIXErrorDomain, 1): // Operation not permitted
					warn("Sandboxed?")
					fallthrough
				case(WebKitErrorDomain, kWKErrorCodeFrameLoadInterruptedByPolicyChange): //`Frame load interrupted` WebKitErrorFrameLoadInterruptedByPolicyChange
					warn("Attachment received from an IFrame and was converted to a download? webView.loading == \(webView.loading)")
					return
				// https://developer.apple.com/reference/foundation/nsurlerror
				case (NSURLErrorDomain, NSURLErrorCancelled) where !webView.loading: return // ignore stopLoading() and HTTP redirects
				default:
					displayError(error, self)
			}
		}
	}

	func webView(webView: WKWebView, didCommitNavigation navigation: WKNavigation!) {
		//content starts arriving...I assume <body> has materialized in the DOM?
		//(webView as? MPWebView)?.scrapeIcon()
	}

	func webView(webView: WKWebView, decidePolicyForNavigationResponse navigationResponse: WKNavigationResponse, decisionHandler: (WKNavigationResponsePolicy) -> Void) {
		let mime = navigationResponse.response.MIMEType!
		let url = navigationResponse.response.URL!
		let fn = navigationResponse.response.suggestedFilename!
		//let len = navigationResponse.response.expectedContentLength
		//let enc = navigationResponse.response.textEncodingName

		if jsdelegate.tryFunc("decideNavigationForMIME", mime, url.description, webView) { decisionHandler(.Cancel); return } //FIXME perf hit?

		// if explicitly attached as file, download it
		if let httpResponse = navigationResponse.response as? NSHTTPURLResponse {
			//let code = httpResponse.statusCode
			//let status = NSHTTPURLResponse.localizedStringForStatusCode(code)
			//let hdr = resp.allHeaderFields
			//if let cd = hdr.objectForKey("Content-Disposition") as? String where cd.hasPrefix("attachment") { warn("got attachment! \(cd) \(fn)") }
			if let headers = httpResponse.allHeaderFields as? [String: String], url = httpResponse.URL {
				let cookies = NSHTTPCookie.cookiesWithResponseHeaderFields(headers, forURL: url)
				//let cookies = NSHTTPCookie._parsedCookiesWithResponseHeaderFields(headers, forURL: url) //ElCap
				for cookie in cookies { jsdelegate.tryFunc("receivedCookie", webView, cookie.name, cookie.value) }

				if let cd = headers["Content-Disposition"] where cd.hasPrefix("attachment") {
					// JS hook?
					warn("got attachment! \(cd) \(fn)")
					//decisionHandler(WKNavigationResponsePolicy(rawValue: WKNavigationResponsePolicy.Allow.rawValue + 1)!) // .BecomeDownload - offer to download
					decisionHandler(_WKNavigationResponsePolicyBecomeDownload)
					return
				}
			}
		}

		if !navigationResponse.canShowMIMEType {
			if !jsdelegate.tryFunc("handleUnrenderableMIME", mime, url.description, fn, webView) {
				//let uti = UTI(MIMEType: mime)
				warn("cannot render requested MIME-type:\(mime) @ \(url)")
				// if scheme is not http|https && askToOpenURL(url)
					 // .Cancel & return if we open()'d
				// else if askToOpenURL(open, uti: uti) // if compatible app for mime
					 // .Cancel & return if we open()'d
				// else download it
					decisionHandler(WKNavigationResponsePolicy(rawValue: WKNavigationResponsePolicy.Allow.rawValue + 1)!) // .BecomeDownload - offer to download
					return
			}
		}

		decisionHandler(.Allow)
	}

	func webView(webView: WKWebView, didFailNavigation navigation: WKNavigation!, withError error: NSError) { //error during commited main frame navigation
		// like server-issued error Statuses with no page content
		if let url = webView.URL {
			warn("[\(url)] -> `\(error.localizedDescription)` [\(error.domain)] [\(error.code)] `\(error.localizedFailureReason ?? String())` : \(error.userInfo)")
			if error.domain == WebKitErrorDomain && error.code == kWKErrorCodePlugInWillHandleLoad { askToOpenURL(url) } // `Plug-in handled load!` video/mp4
			if error.domain == WebKitErrorDomain && error.code == kWKErrorCodeFrameLoadInterruptedByPolicyChange { warn("IFrame converted to download?") }
			if error.domain == NSURLErrorDomain && error.code != NSURLErrorCancelled { // dont catch on stopLoading() and HTTP redirects
				displayError(error, self)
			}
		}
#if os(iOS)
		UIApplication.sharedApplication().networkActivityIndicatorVisible = false
#endif
    }

	func webView(webView: WKWebView, didFinishNavigation navigation: WKNavigation!) {
		warn(webView.description)
		//let title = webView.title ?? String()
		//let url = webView.URL ?? NSURL(string:"")!
		//warn("\"\(title)\" [\(url)]")
		//(webView as? MPWebView)?.scrapeIcon()
#if os(iOS)
		UIApplication.sharedApplication().networkActivityIndicatorVisible = false
#endif
	}

	func webView(webView: WKWebView, createWebViewWithConfiguration configuration: WKWebViewConfiguration, forNavigationAction navigationAction: WKNavigationAction,
                windowFeatures: WKWindowFeatures) -> WKWebView? {
		// called via JS:window.open()
		// https://developer.mozilla.org/en-US/docs/Web/API/window.open
		// https://developer.apple.com/library/prerelease/ios/documentation/WebKit/Reference/WKWindowFeatures_Ref/index.html

		let srcurl = navigationAction.sourceFrame.request.URL ?? NSURL(string:String())!
		let openurl = navigationAction.request.URL ?? NSURL(string:String())!
		let tgt = (navigationAction.targetFrame == nil) ? NSURL(string:String())! : navigationAction.targetFrame!.request.URL
		//let tgtdom = navigationAction.targetFrame?.request.mainDocumentURL ?? NSURL(string:String())!
		//^tgt is given as a string in JS and WKWebView synthesizes a WKFrameInfo from it _IF_ it matches an iframe title in the DOM
		// otherwise == nil
		// RDAR? would like the tgt string to be passed here

		warn("JS <\(srcurl)>: `window.open(\(openurl), \(tgt));`")
		if jsdelegate.tryFunc("decideWindowOpenForURL", openurl.description, webView) { return nil }
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
				if !webView.inFullScreenMode && (!window.styleMask.contains(.FullScreen)) {
					warn("resizing window to match window.open() size parameters passed: origin,size[\(newframe)]")
					window.setFrame(newframe, display: true)
				}
			}
		}
#endif
		//if !tgt.description.isEmpty { evalJS("window.name = '\(tgt)';") }
		if !openurl.description.isEmpty { wv.gotoURL(openurl) } // this should be deferred with a timer so all chained JS calls on the window.open() instanciation can finish executing
		jsdelegate.tryFunc("DidWindowOpenForURL", openurl.description, wv, webView) // allow app.js to tweak any created windows
		return wv // window.open() -> Window()
		//return nil //window.open() -> undefined
	}

	func webViewDidClose(webView: WKWebView) {
		warn("JS <\(webView.URL)>: `window.close();`")
		closeTab() // FIXME: need to ensure webView was window.open()'d by a JS script
	}

	func _webViewWebProcessDidCrash(webView: WKWebView) {
	    warn("reloading page")
		webView.reload()
	}
}

extension WebViewController: _WKFormDelegate { } // form input hooks, implemented per-platform
extension WebViewController: _WKFindDelegate { } // text finder handling, implemented per-platform
