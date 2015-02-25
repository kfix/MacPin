// need a <input type="file"> picker & uploader delegate
// https://github.com/WebKit/webkit/commit/a12c1fc70fa906a39a0593aa4124f24427e232e7
// https://developer.apple.com/library/prerelease/ios/documentation/General/Conceptual/ExtensibilityPG/ExtensionScenarios.html#//apple_ref/doc/uid/TP40014214-CH21-SW2
// https://developer.apple.com/library/mac/documentation/Foundation/Reference/NSURLSessionUploadTask_class/index.html

import WebKit

extension WebViewController: WKScriptMessageHandler {
	func userContentController(userContentController: WKUserContentController, didReceiveScriptMessage message: WKScriptMessage) {
		//called from JS: webkit.messageHandlers.<messsage.name>.postMessage(<message.body>);
		switch message.name {
			case "MacPinPollStates": // direct poll. app.js needs to authorize this handler per tab
				//FIXME: should iterate message.body's [varnames] to send events for. just shotgun them right now
				//or send an omnibus event with all varnames values?
				webview?.evaluateJavaScript(
					"window.dispatchEvent(new window.CustomEvent('MacPinTransparencyChanged',{'detail':{'isTransparent': \(browser?.isTransparent ?? false)}})); ",	
					completionHandler: nil)
				fallthrough // also let jsruntime get the request
			default:
				warn("JS \(message.name)() -> \(message.body)")
				if jsruntime.delegate.hasProperty(message.name) {
					warn("sending webkit.messageHandlers.\(message.name) to JSCore: postMessage(\(message.body))")
					jsruntime.delegate.invokeMethod(message.name, withArguments: [message.body])
				}
		}
	}
}

// alert.icons should be the current tab icon, which may not be the app icon
extension WebViewController: WKUIDelegate {
	func webView(webView: WKWebView!, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: () -> Void) {
		conlog("JS window.alert() -> \(message)")
		var alert = NSAlert()
		alert.messageText = webView.title
		alert.addButtonWithTitle("Dismiss")
		alert.informativeText = message
		alert.icon = NSApplication.sharedApplication().applicationIconImage
		alert.alertStyle = .InformationalAlertStyle // .Warning .Critical
		if let window = grabWindow() {
			alert.beginSheetModalForWindow(window, completionHandler:{(response:NSModalResponse) -> Void in
				completionHandler()
	 		})
		}
	}

	func webView(webView: WKWebView!, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: (Bool) -> Void) {
		conlog("JS window.confirm() -> \(message)")
		var alert = NSAlert()
		alert.messageText = webView.title
		alert.addButtonWithTitle("OK")
		alert.addButtonWithTitle("Cancel")
		alert.informativeText = message
		alert.icon = NSApplication.sharedApplication().applicationIconImage
		if let window = grabWindow() {
			alert.beginSheetModalForWindow(window, completionHandler:{(response:NSModalResponse) -> Void in
				completionHandler(response == NSAlertFirstButtonReturn ? true : false)
 			})
		}
	}

	func webView(webView: WKWebView!, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: (String!) -> Void) {
		conlog("JS window.prompt() -> \(prompt)")
		var alert = NSAlert()
		alert.messageText = webView.title
		alert.addButtonWithTitle("Submit")
		alert.informativeText = prompt
		alert.icon = NSApplication.sharedApplication().applicationIconImage
		var input = NSTextField(frame: NSMakeRect(0, 0, 200, 24))
		input.stringValue = ""
		input.editable = true
 		alert.accessoryView = input
		if let window = grabWindow() {
			alert.beginSheetModalForWindow(window, completionHandler:{(response:NSModalResponse) -> Void in
				completionHandler(input.stringValue)
	 		})
		}
	}

	// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/Cocoa/WKUIDelegatePrivate.h
	// https://github.com/WebKit/webkit/blob/9fc59b8f8a54be88ca1de601435087018c0cc181/Source/WebKit2/UIProcess/ios/WKGeolocationProviderIOS.mm#L187
	// https://github.com/WebKit/webkit/search?q=GeolocationPosition.h http://support.apple.com/en-us/HT202080
	// http://www.cocoawithlove.com/2009/09/whereismymac-snow-leopard-corelocation.html
	func _webView(webView: WKWebView!, shouldRequestGeolocationAuthorizationForURL url: NSURL, isMainFrame: Bool, mainFrameURL: NSURL) -> Bool { return false } // always allow
	func _webView(webView: WKWebView!, printFrame: WKFrameInfo) { 
		conlog("JS: window.print()")
		var printer = NSPrintOperation(view: webView, printInfo: NSPrintInfo.sharedPrintInfo())
		// seems to work very early on in the first loaded page, then just becomes blank pages
		// PDF = This view requires setWantsLayer:YES when blendingMode == NSVisualEffectBlendingModeWithinWindow

		//var wkview = (webView.subviews.first as WKView)
		// https://github.com/WebKit/webkit/blob/d3e9af22a535887f7d4d82e37817ba5cfc03e957/Source/WebKit2/UIProcess/API/mac/WKView.mm#L3848
		//var view = WKPrintingView(printFrame, view: wkview)
		// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/mac/WKPrintingView.mm
		//var printer = wkview.printOperationWithPrintInfo(NSPrintInfo.sharedPrintInfo(), forFrame: printFrame) //crash on retain

		printer.showsPrintPanel = true
		printer.runOperation()
	}

}

extension WebViewController: WKNavigationDelegate {
	func webView(webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { 
		if let url = webView.URL {
			conlog("\(__FUNCTION__) [\(url)]")
			//browser.navigations[navigation] = url //make a backref for when we may have to present an error later
		}
	}

	func webView(webView: WKWebView!, decidePolicyForNavigationAction navigationAction: WKNavigationAction, decisionHandler: (WKNavigationActionPolicy) -> Void) {
		let url = navigationAction.request.URL

		if let scheme = url.scheme? {
			switch scheme {
				case "file": fallthrough
				case "about": fallthrough
				case "http": fallthrough
				case "https": break
				default: //weird protocols, or app launches like itmss:
					askToOpenURL(url)
    	        	decisionHandler(.Cancel)
			}
		}

		if jsruntime.delegate.tryFunc("decideNavigationForURL", url.description) { decisionHandler(.Cancel); return }

		//conlog("WebView decidePolicy() navType:\(navigationAction.navigationType.rawValue) sourceFrame:(\(navigationAction.sourceFrame?.request.URL)) -> \(url)")
		switch navigationAction.navigationType {
			case .LinkActivated:
				let mousebtn = navigationAction.buttonNumber
				let modkeys = navigationAction.modifierFlags
				if (modkeys & NSEventModifierFlags.AlternateKeyMask).rawValue != 0 { NSWorkspace.sharedWorkspace().openURL(url) } //alt-click
					else if (modkeys & NSEventModifierFlags.CommandKeyMask).rawValue != 0 { browser?.newTab(url) } //cmd-click
					else if !jsruntime.delegate.tryFunc("decideNavigationForClickedURL", url.description) { // allow override from JS 
						if navigationAction.targetFrame != nil && mousebtn == 1 { fallthrough } // left-click on in_frame target link
						browser?.newTab(url) // middle-clicked, or out of frame target link
					}
				conlog("\(__FUNCTION__) -> .Cancel -- user clicked <a href=\(url) target=_blank> or middle-clicked: opening externally")
    	        decisionHandler(.Cancel)
			case .FormSubmitted: fallthrough
			case .BackForward: fallthrough
			case .Reload: fallthrough
			case .FormResubmitted: fallthrough
			case .Other: fallthrough
			default: decisionHandler(.Allow) 
		}
	}

	//func webView(webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {}

	func webView(webView: WKWebView, didReceiveAuthenticationChallenge challenge: NSURLAuthenticationChallenge,
		completionHandler: (NSURLSessionAuthChallengeDisposition, NSURLCredential!) -> Void) {

		if let authMethod = challenge.protectionSpace.authenticationMethod {
			switch authMethod {
				case NSURLAuthenticationMethodClientCertificate: fallthrough;
				case NSURLAuthenticationMethodServerTrust:
					completionHandler(.PerformDefaultHandling, nil)
					return
				case NSURLAuthenticationMethodDefault: fallthrough;
				default:
					conlog("prompting user for \(authMethod) credentials: [\(webView.URL ?? String())]")	
			}
		}

		let alert = NSAlert()
		alert.messageText = webView.title
		alert.addButtonWithTitle("Submit")
		alert.addButtonWithTitle("Cancel")
		alert.informativeText = "auth challenge"
		alert.icon = NSApplication.sharedApplication().applicationIconImage

		let prompts = NSView(frame: NSMakeRect(0, 0, 200, 64))

		let userbox = NSTextField(frame: NSMakeRect(0, 40, 200, 24))
		userbox.stringValue = "Enter user"
 		if let cred = challenge.proposedCredential {
			if let user = cred.user { userbox.stringValue = user }
		}
		userbox.editable = true

		let passbox = NSTextField(frame: NSMakeRect(0, 0, 200, 24))
		passbox.stringValue = "Enter password"
 		if let cred = challenge.proposedCredential {
			if cred.hasPassword { passbox.stringValue = cred.password! }
		}
		passbox.editable = true

		prompts.subviews = [userbox, passbox]

 		alert.accessoryView = prompts

		alert.beginSheetModalForWindow(webView.window!, completionHandler:{(response:NSModalResponse) -> Void in
			if response == NSAlertFirstButtonReturn {
				completionHandler(.UseCredential, NSURLCredential(
					user: userbox.stringValue,
					password: passbox.stringValue,
					persistence: .Permanent
				))
			} else {
				// need to cancel request, else user can get locked into a modal prompt loop
				completionHandler(.PerformDefaultHandling, nil)
				webView.stopLoading()
			}
 		})
	}

	func webView(webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: NSError) { //error returned by webkit when loading content
		if let url = webView.URL { //?.absoluteString ?? "about:blank" {
		//	URL is the last requested (And invalid) domain name, just the last sucessfully-loaded location
		//   need to pull the URL back from didStartProvisionalNavigation
			conlog("\(__FUNCTION__) [\(url)] -> `\(error.localizedDescription)` [\(error.domain)] [\(error.code)] `\(error.localizedFailureReason ?? String())` : \(error.userInfo)")
			if error.domain == NSURLErrorDomain && error.code != -999 && !webView.loading { // 999 is thrown often on working links
				if let window = grabWindow() {
					presentError(error, modalForWindow: window, delegate: nil, didPresentSelector: nil, contextInfo: nil) }
				}
		}
	}

	//func webView(webView: WKWebView!, didCommitNavigation navigation: WKNavigation!) { } //content starts arriving

	func webView(webView: WKWebView!, decidePolicyForNavigationResponse navigationResponse: WKNavigationResponse, decisionHandler: (WKNavigationResponsePolicy) -> Void) {
		let mime = navigationResponse.response.MIMEType!
		let url = navigationResponse.response.URL!
		let fn = navigationResponse.response.suggestedFilename!

		if jsruntime.delegate.tryFunc("decideNavigationForMIME", mime, url.description) { decisionHandler(.Cancel); return } //FIXME perf hit?

		if navigationResponse.canShowMIMEType { 
			decisionHandler(.Allow)
		} else {
			conlog("\(__FUNCTION__) cannot render requested MIME-type:\(mime) @ \(url)")
			if !jsruntime.delegate.tryFunc("handleUnrenderableMIME", mime, url.description, fn) { askToOpenURL(url) }
			decisionHandler(.Cancel)
		}
	}

	func webView(webView: WKWebView, didFailNavigation navigation: WKNavigation!, withError error: NSError) { //error during commited main frame navigation
		// like server-issued error Statuses with no page content
		if let url = webView.URL { 
			conlog("\(__FUNCTION__) [\(url)] -> `\(error.localizedDescription)` [\(error.domain)] [\(error.code)] `\(error.localizedFailureReason ?? String())` : \(error.userInfo)")
			if error.domain == WebKitErrorDomain && error.code == 204 { askToOpenURL(url) } // `Plug-in handled load!` video/mp4
			if error.domain == NSURLErrorDomain && error.code != -999 { // 999 is thrown on stopLoading()
				if let window = grabWindow() {
					presentError(error, modalForWindow: window, delegate: nil, didPresentSelector: nil, contextInfo: nil) }
				}
		}
    }
	
	func webView(webView: WKWebView!, didFinishNavigation navigation: WKNavigation!) {
		let title = webView.title ?? String()
		let url = webView.URL ?? NSURL(string:"")!
		conlog("\(__FUNCTION__) \"\(title)\" [\(url)]")
	}
	
	func webView(webView: WKWebView!, createWebViewWithConfiguration configuration: WKWebViewConfiguration, forNavigationAction navigationAction: WKNavigationAction,
                windowFeatures: WKWindowFeatures) -> WKWebView? {
		// called via JS:window.open()
		// https://developer.mozilla.org/en-US/docs/Web/API/window.open
		// https://developer.apple.com/library/prerelease/ios/documentation/WebKit/Reference/WKWindowFeatures_Ref/index.html

		var url = navigationAction.request.URL ?? NSURL(string:String())!
		var tgt = (navigationAction.targetFrame == nil) ? NSURL(string:String())! : navigationAction.targetFrame!.request.URL
		//^tgt is given as a string in JS and WKWebView synthesizes a WKFrameInfo from it _IF_ it matches an iframe title in the DOM
		// otherwise == nil

		conlog("JS@\(navigationAction.sourceFrame?.request.URL ?? String()) window.open(\(url), \(tgt))")

		if jsruntime.delegate.tryFunc("decideWindowOpenForURL", url.description) { return nil }

		if url.description.isEmpty { 
			conlog("url-less JS popup request!")
		} else if (windowFeatures.allowsResizing ?? 0) == 1 { 
			if let window = grabWindow() {
				var newframe = CGRect(
					x: CGFloat(windowFeatures.x ?? window.frame.origin.x as NSNumber),
					y: CGFloat(windowFeatures.y ?? window.frame.origin.y as NSNumber),
					width: CGFloat(windowFeatures.width ?? window.frame.size.width as NSNumber),
					height: CGFloat(windowFeatures.height ?? window.frame.size.height as NSNumber)
				)
				conlog("adjusting window to match window.open() call with size settings: origin,size[\(newframe)]")
				window.setFrame(newframe, display: true)
			}
			if let wvc = WebViewController(agent: webView._customUserAgent, configuration: configuration) {
				browser?.newTab(wvc)
				wvc.gotoURL(url)
				conlog("window.open() completed for url[\(url)])")
				return wvc.view as? WKWebView// window.open() -> Window()
			}
		} else if tgt.description.isEmpty { //target-less request, assuming == 'top' 
			webView.loadRequest(navigationAction.request)
		} else {
			conlog("redirecting JS popup to system browser")
			askToOpenURL(url)
		}

		return nil //window.open() -> undefined
	}

	func _webViewWebProcessDidCrash(webView: WKWebView) {
	    conlog("\(__FUNCTION__) reloading page")
		webView.reload()
	}
}
