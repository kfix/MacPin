/// MacPin WebViewDelegates
///
/// Handle modal & interactive webview prompts and errors

// need a <input type="file"> picker & uploader protocol delegate
// https://github.com/WebKit/webkit/commit/a12c1fc70fa906a39a0593aa4124f24427e232e7
// https://developer.apple.com/library/prerelease/ios/documentation/General/Conceptual/ExtensibilityPG/ExtensionScenarios.html#//apple_ref/doc/uid/TP40014214-CH21-SW2
// https://developer.apple.com/library/mac/documentation/Foundation/Reference/NSURLSessionUploadTask_class/index.html

//and how about downloads? right now they are passed to safari
// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/Cocoa/_WKDownloadDelegate.h
// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/Cocoa/DownloadClient.mm

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
				//case "MacPinGotDownloadedChunk":
					//msg = [dst_uri, range, data]
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

extension WebViewController: WKNavigationDelegate {
	func webView(webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
		if let url = webView.URL {
			warn("'\(url)'")
			// check url against regex'd keys of MatchedAddressOptions
			// or just call a JS delegate to do that?
		}
#if os(iOS)
		UIApplication.sharedApplication().networkActivityIndicatorVisible = true
#endif
	}

	func webView(webView: WKWebView, decidePolicyForNavigationAction navigationAction: WKNavigationAction, decisionHandler: (WKNavigationActionPolicy) -> Void) {
		let url = navigationAction.request.URL
		if let url = url, scheme = url.scheme {
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

			if jsdelegate.tryFunc("decideNavigationForURL", url.description) { decisionHandler(.Cancel); return }

			switch navigationAction.navigationType {
				case .LinkActivated:
#if os(OSX)
					let mousebtn = navigationAction.buttonNumber
					let modkeys = navigationAction.modifierFlags
					if (modkeys & NSEventModifierFlags.AlternateKeyMask).rawValue != 0 { NSWorkspace.sharedWorkspace().openURL(url) } //alt-click
						else if (modkeys & NSEventModifierFlags.CommandKeyMask).rawValue != 0 { popup(MPWebView(url: url, agent: webView._customUserAgent)) } //cmd-click
						else if !jsdelegate.tryFunc("decideNavigationForClickedURL", url.description) { // allow override from JS
							if navigationAction.targetFrame != nil && mousebtn == 1 { fallthrough } // left-click on in_frame target link
							popup(MPWebView(url: url, agent: webView._customUserAgent)) // middle-clicked, or out of frame target link
						}
#elseif os(iOS)
					if !jsdelegate.tryFunc("decideNavigationForClickedURL", url.description) { // allow override from JS
						if navigationAction.targetFrame != nil { fallthrough } // tapped in_frame target link
						popup(MPWebView(url: url, agent: webView._customUserAgent)) // out of frame target link
					}
#endif
					warn("-> .Cancel -- user clicked <a href=\(url) target=_blank> or middle-clicked: opening externally")
    		        decisionHandler(.Cancel)
				case .FormSubmitted: fallthrough
				case .BackForward: fallthrough
				case .Reload: fallthrough
				case .FormResubmitted: fallthrough
				case .Other: fallthrough
				default: decisionHandler(.Allow)
			}
		} else {
			// invalid url? should raise error
			warn("navType:\(navigationAction.navigationType.rawValue) sourceFrame:(\(navigationAction.sourceFrame?.request.URL)) -> \(url)")
			decisionHandler(.Cancel)
		}
	}

	func webView(webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
		if let url = webView.URL { warn("~> [\(url)]") }
	}

	func webView(webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: NSError) { //error returned by webkit when loading content
		if let url = webView.URL {
			warn("'\(url)' -> `\(error.localizedDescription)` [\(error.domain)] [\(error.code)] `\(error.localizedFailureReason ?? String())` : \(error.userInfo)")
			if error.domain == NSURLErrorDomain && error.code != NSURLErrorCancelled && !webView.loading { // dont catch on stopLoading() and HTTP redirects
				displayError(error, self)
			}
		}
	}

	func webView(webView: WKWebView, didCommitNavigation navigation: WKNavigation!) {
		//content starts arriving...I assume <body> has materialized in the DOM?
		(webView as? MPWebView)?.scrapeIcon()
	}

	func webView(webView: WKWebView, decidePolicyForNavigationResponse navigationResponse: WKNavigationResponse, decisionHandler: (WKNavigationResponsePolicy) -> Void) {
		let mime = navigationResponse.response.MIMEType!
		let url = navigationResponse.response.URL!
		let fn = navigationResponse.response.suggestedFilename!

		if jsdelegate.tryFunc("decideNavigationForMIME", mime, url.description) { decisionHandler(.Cancel); return } //FIXME perf hit?

		if navigationResponse.canShowMIMEType {
			decisionHandler(.Allow)
		} else {
			warn("cannot render requested MIME-type:\(mime) @ \(url)")
			if !jsdelegate.tryFunc("handleUnrenderableMIME", mime, url.description, fn) { askToOpenURL(url) }
			decisionHandler(.Cancel)
		}
	}

	func webView(webView: WKWebView, didFailNavigation navigation: WKNavigation!, withError error: NSError) { //error during commited main frame navigation
		// like server-issued error Statuses with no page content
		if let url = webView.URL {
			warn("[\(url)] -> `\(error.localizedDescription)` [\(error.domain)] [\(error.code)] `\(error.localizedFailureReason ?? String())` : \(error.userInfo)")
			if error.domain == WebKitErrorDomain && error.code == 204 { askToOpenURL(url) } // `Plug-in handled load!` video/mp4 kWKErrorCodePlugInWillHandleLoad
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
		//scrapeIcon(webView)
#if os(iOS)
		UIApplication.sharedApplication().networkActivityIndicatorVisible = false
#endif
	}

	func webView(webView: WKWebView, createWebViewWithConfiguration configuration: WKWebViewConfiguration, forNavigationAction navigationAction: WKNavigationAction,
                windowFeatures: WKWindowFeatures) -> WKWebView? {
		// called via JS:window.open()
		// https://developer.mozilla.org/en-US/docs/Web/API/window.open
		// https://developer.apple.com/library/prerelease/ios/documentation/WebKit/Reference/WKWindowFeatures_Ref/index.html

		let srcurl = navigationAction.sourceFrame?.request.URL ?? NSURL(string:String())!
		let openurl = navigationAction.request.URL ?? NSURL(string:String())!
		let tgt = (navigationAction.targetFrame == nil) ? NSURL(string:String())! : navigationAction.targetFrame!.request.URL
		let tgtdom = navigationAction.targetFrame?.request.mainDocumentURL ?? NSURL(string:String())!
		//^tgt is given as a string in JS and WKWebView synthesizes a WKFrameInfo from it _IF_ it matches an iframe title in the DOM
		// otherwise == nil
		// RDAR? would like the tgt string to be passed here

		warn("<\(srcurl)>: window.open(\(openurl), \(tgt))")
		if jsdelegate.tryFunc("decideWindowOpenForURL", openurl.description) { return nil }
		let wv = MPWebView(config: configuration, agent: webView._customUserAgent)
		popup(wv)
#if os(OSX)
		if (windowFeatures.allowsResizing ?? 0) == 1 {
			if let window = view.window {
				var newframe = CGRect(
					x: CGFloat(windowFeatures.x ?? window.frame.origin.x as NSNumber),
					y: CGFloat(windowFeatures.y ?? window.frame.origin.y as NSNumber),
					width: CGFloat(windowFeatures.width ?? window.frame.size.width as NSNumber),
					height: CGFloat(windowFeatures.height ?? window.frame.size.height as NSNumber)
				)
				if !webView.inFullScreenMode && (window.styleMask & NSFullScreenWindowMask == 0) {
					warn("resizing window to match window.open() size parameters passed: origin,size[\(newframe)]")
					window.setFrame(newframe, display: true)
				}
			}
		}
#endif
		//if !tgt.description.isEmpty { evalJS("window.name = '\(tgt)';") }
		if !openurl.description.isEmpty { wv.gotoURL(openurl) } // this should be deferred with a timer so all chained JS calls on the window.open() instanciation can finish executing
		jsdelegate.tryFunc("DidWindowOpenForURL", openurl.description, wv) // allow app.js to tweak any created windows 
		return wv // window.open() -> Window()
		//return nil //window.open() -> undefined
	}

	func _webViewWebProcessDidCrash(webView: WKWebView) {
	    warn("reloading page")
		webView.reload()
	}
}
