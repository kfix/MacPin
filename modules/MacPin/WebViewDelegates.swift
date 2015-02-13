// need a file-picker>uploader delegate

public extension WKWebView {
	override func cancelOperation(sender: AnyObject?) { stopLoading(sender) } //make Esc key stop page load
}

extension MacPin: WKUIDelegate {
	func webView(webView: WKWebView!, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: () -> Void) {
		conlog("JS window.alert() -> \(message)")
		var alert = NSAlert()
		alert.messageText = webView.title
		alert.addButtonWithTitle("Dismiss")
		alert.informativeText = message
		alert.icon = app?.applicationIconImage
		alert.alertStyle = .InformationalAlertStyle // .Warning .Critical
		alert.beginSheetModalForWindow(windowController.window!, completionHandler:{(response:NSModalResponse) -> Void in
			completionHandler()
 		})
	}

	func webView(webView: WKWebView!, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: (Bool) -> Void) {
		conlog("JS window.confirm() -> \(message)")
		var alert = NSAlert()
		alert.messageText = webView.title
		alert.addButtonWithTitle("OK")
		alert.addButtonWithTitle("Cancel")
		alert.informativeText = message
		alert.icon = app?.applicationIconImage
		alert.beginSheetModalForWindow(windowController.window!, completionHandler:{(response:NSModalResponse) -> Void in
			completionHandler(response == NSAlertFirstButtonReturn ? true : false)
 		})
	}

	func webView(webView: WKWebView!, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: (String!) -> Void) {
		conlog("JS window.prompt() -> \(prompt)")
		var alert = NSAlert()
		alert.messageText = webView.title
		alert.addButtonWithTitle("Submit")
		alert.informativeText = prompt
		alert.icon = app?.applicationIconImage
		var input = NSTextField(frame: NSMakeRect(0, 0, 200, 24))
		input.stringValue = ""
		input.editable = true
 		alert.accessoryView = input
		alert.beginSheetModalForWindow(windowController.window!, completionHandler:{(response:NSModalResponse) -> Void in
			completionHandler(input.stringValue)
 		})
	}

	// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/Cocoa/WKUIDelegatePrivate.h
	// https://github.com/WebKit/webkit/blob/9fc59b8f8a54be88ca1de601435087018c0cc181/Source/WebKit2/UIProcess/ios/WKGeolocationProviderIOS.mm#L187
	// https://github.com/WebKit/webkit/search?q=GeolocationPosition.h http://support.apple.com/en-us/HT202080
	// http://www.cocoawithlove.com/2009/09/whereismymac-snow-leopard-corelocation.html
	func _webView(webView: WKWebView!, shouldRequestGeolocationAuthorizationForURL url: NSURL, isMainFrame: Bool, mainFrameURL: NSURL) -> Bool { return true }
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

extension MacPin: WKScriptMessageHandler {
	public func userContentController(userContentController: WKUserContentController, didReceiveScriptMessage message: WKScriptMessage) {
		//called from JS: webkit.messageHandlers.<messsage.name>.postMessage(<message.body>);
		switch message.name {
			default:
				conlog("JS \(message.name)() -> \(message.body)")
				if _jsapi.hasProperty(message.name) {
					warn("sending webkit.messageHandlers.\(message.name) to JSCore: postMessage(\(message.body))")
					_jsapi.invokeMethod(message.name, withArguments: [message.body])
				}
		}
	}
}

extension MacPin: WKNavigationDelegate {

	//func webView(webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { }

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

		if _jsapi.tryFunc("decideNavigationForURL", url.description) { decisionHandler(.Cancel); return }

		//conlog("WebView decidePolicy() navType:\(navigationAction.navigationType.rawValue) sourceFrame:(\(navigationAction.sourceFrame?.request.URL)) -> \(url)")
		switch navigationAction.navigationType {
			case .LinkActivated:
				let mousebtn = navigationAction.buttonNumber
				let modkeys = navigationAction.modifierFlags
				if (modkeys & NSEventModifierFlags.AlternateKeyMask).rawValue != 0 { NSWorkspace.sharedWorkspace().openURL(url) } //alt-click
					else if (modkeys & NSEventModifierFlags.CommandKeyMask).rawValue != 0 { newAppTab(url.description) } //cmd-click
					else if !_jsapi.tryFunc("decideNavigationForClickedURL", url.description) { // allow override from JS 
						if navigationAction.targetFrame != nil && mousebtn == 1 { fallthrough } // left-click on in_frame target link
						newAppTab(url.description) // middle-clicked, or out of frame target link
					}
				conlog("webView.decidePolicy() -> .Cancel -- user clicked <a href=\(url) target=_blank> or middle-clicked: opening externally")
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

	public func webView(webView: WKWebView, didReceiveAuthenticationChallenge challenge: NSURLAuthenticationChallenge,
		completionHandler: (NSURLSessionAuthChallengeDisposition, NSURLCredential!) -> Void) {
		conlog("prompt for credentials!")
			
		completionHandler(.PerformDefaultHandling, nil)
		return // FIXME finish this

		var alert = NSAlert()
		alert.messageText = webView.title
		alert.addButtonWithTitle("Submit")
		alert.informativeText = "auth challenge"
		alert.icon = app?.applicationIconImage

		var userbox = NSTextField(frame: NSMakeRect(0, 0, 200, 24))
		userbox.stringValue = "Enter user"
 		if let cred = challenge.proposedCredential {
			if let user = cred.user { userbox.stringValue = user }
		}
		userbox.editable = true

		var passbox = NSTextField(frame: NSMakeRect(0, 0, 200, 24))
		passbox.stringValue = "Enter password"
 		if let cred = challenge.proposedCredential {
			if cred.hasPassword { passbox.stringValue = cred.password! }
		}
		passbox.editable = true

 		alert.accessoryView = passbox //need a second one for user & password

		alert.beginSheetModalForWindow(windowController.window!, completionHandler:{(response:NSModalResponse) -> Void in
			completionHandler(.UseCredential, NSURLCredential(
				user: userbox.stringValue,
				password: passbox.stringValue,
				persistence: .Permanent
			))
 		})

	}

	public func webView(webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: NSError) { //error returned by webkit when loading content
		//	URL is not always the requested (And invalid) domain name, just the previously loaded location
		//  fixed?: https://github.com/WebKit/webkit/commit/9f890e75fcf7e94aad588881b7ed973c742d3cc8
		if let url = (viewController.urlbox.cell() as NSSearchFieldCell).recentSearches.last as? String ?? webView.URL?.absoluteString ?? "about:blank" {
			conlog("webView.didFailProvisionalNavigation() [\(url)] -> `\(error.localizedDescription)` [\(error.domain)] [\(error.code)] `\(error.localizedFailureReason ?? String())`")
			if error.domain == NSURLErrorDomain && error.code != -999 && !webView.loading { // thrown often on working links
				//`The operation couldn't be completed. (NSURLErrorDomain error -999.)` [NSURLErrorDomain] [-999]
				webView.loadHTMLString("<html><body><pre>`\(error.localizedDescription)`\n\(error.domain)\n\(error.code)\n`\(error.localizedFailureReason ?? String())`\n\(url)</pre></body></html>", baseURL: NSURL(string: url)!)
				// FIXME: use status bar or alert panel instead of clobbering page
			}
		}
	}

	//func webView(webView: WKWebView!, didCommitNavigation navigation: WKNavigation!) { updateTitleFromPage(webView) } //content starts arriving

	func webView(webView: WKWebView!, decidePolicyForNavigationResponse navigationResponse: WKNavigationResponse, decisionHandler: (WKNavigationResponsePolicy) -> Void) {
		let mime = navigationResponse.response.MIMEType!
		let url = navigationResponse.response.URL!
		let fn = navigationResponse.response.suggestedFilename!

		if _jsapi.tryFunc("decideNavigationForMIME", mime, url.description) { decisionHandler(.Cancel); return } //FIXME perf hit?

		if navigationResponse.canShowMIMEType { 
			decisionHandler(.Allow)
		} else {
			conlog("webView cannot render requested MIME-type:\(mime) @ \(url)")
			if !_jsapi.tryFunc("handleUnrenderableMIME", mime, url.description, fn) { askToOpenURL(url) }
			decisionHandler(.Cancel)
		}
	}

	public func webView(webView: WKWebView, didFailNavigation navigation: WKNavigation!, withError error: NSError) { //error during commited main frame navigation
		// like server-issued error Statuses with no page content
		if let url = webView.URL { 
			conlog("webView.didFailNavigation() [\(url)] -> `\(error.localizedDescription)` [\(error.domain)] [\(error.code)] `\(error.localizedFailureReason ?? String())`")
			if error.domain == WebKitErrorDomain && error.code == 204 { askToOpenURL(url) } // `Plug-in handled load!` video/mp4 Open in New Window
			if error.domain == NSURLErrorDomain && error.code != -999 { // thrown on stopLoading()
				webView.loadHTMLString("<html><body><pre>`\(error.localizedDescription)`\n\(error.domain)\n\(error.code)\n`\(error.localizedFailureReason ?? String())`\n\(url)</pre></body></html>", baseURL: url)
				// FIXME: use status bar or alert panel instead of clobbering page
			}
		}
    }
	
	func webView(webView: WKWebView!, didFinishNavigation navigation: WKNavigation!) {
		let title = webView.title ?? String()
		let url = webView.URL ?? NSURL(string:"")!
		conlog("webView.didFinishNavigation() \"\(title)\" [\(url)]")
		webView.evaluateJavaScript("window.dispatchEvent(new window.CustomEvent('macpinTransparencyChanged',{'detail':{'isTransparent': \(isTransparent)}})); ", completionHandler: nil)
	}
	
	func webView(webView: WKWebView!, createWebViewWithConfiguration configuration: WKWebViewConfiguration, forNavigationAction navigationAction: WKNavigationAction,
                windowFeatures: WKWindowFeatures) -> WKWebView? {
		// called via JS:window.open()
		// https://developer.mozilla.org/en-US/docs/Web/API/window.open
		// https://developer.apple.com/library/prerelease/ios/documentation/WebKit/Reference/WKWindowFeatures_Ref/index.html

		let window = windowController.window!
		var url = navigationAction.request.URL ?? NSURL(string:String())!
		var tgt = (navigationAction.targetFrame == nil) ? NSURL(string:String())! : navigationAction.targetFrame!.request.URL
		//^tgt is given as a string in JS and WKWebView synthesizes a WKFrameInfo from it _IF_ it matches an iframe title in the DOM
		// otherwise == nil
		var newframe = CGRect(
			x: CGFloat(windowFeatures.x ?? window.frame.origin.x as NSNumber),
			y: CGFloat(windowFeatures.y ?? window.frame.origin.y as NSNumber),
			width: CGFloat(windowFeatures.width ?? window.frame.size.width as NSNumber),
			height: CGFloat(windowFeatures.height ?? window.frame.size.height as NSNumber)
		)

		conlog("JS@\(navigationAction.sourceFrame?.request.URL ?? String()) window.open(\(url), \(tgt))")

		if _jsapi.tryFunc("decideWindowOpenForURL", url.description) { return nil }

		if url.description.isEmpty { 
			conlog("url-less JS popup request!")
		} else if (windowFeatures.allowsResizing ?? 0) == 1 { 
			conlog("JS popup request with size settings, origin,size[\(newframe)]")
			windowController.window!.setFrame(newframe, display: true)
			if let cell = viewController.urlbox.cell() as? NSSearchFieldCell { cell.recentSearches.append(url.description) } //FIXME until WKNavigation is fixed
			var webview = newWebView(url, withAgent: webView._customUserAgent, withConfiguration: configuration)
			newTab(webview)
			conlog("window.open() completed for url[\(url)] origin,size[\(newframe)]")
			return webview // window.open() -> Window()
		} else if tgt.description.isEmpty { //target-less request, assuming == 'top' 
			webView.loadRequest(navigationAction.request)
		} else {
			conlog("redirecting JS popup to system browser")
			NSWorkspace.sharedWorkspace().openURL(url) //send to default browser
		}

		return nil //window.open() -> undefined
	}

	func _webViewWebProcessDidCrash(webView: WKWebView) {
	    warn("WebContent process crashed; reloading")
		webView.reload()
	}
}
