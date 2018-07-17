/// MacPin WebViewDelegates
///
/// Handle modal & interactive webview prompts and errors using OSX widgets

import WebKit
import WebKitPrivates

extension WebViewControllerOSX: WKUIDelegate {

	func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
		//focus()
			// tab switches, but re-draw of webview is frozen because webthread is stuck waiting for this delegated call to finish...
		let alert = NSAlert()
		alert.messageText = webView.title ?? ""
		alert.addButton(withTitle: "Dismiss")
		alert.informativeText = message
		alert.icon = webview.favicon.icon
		alert.alertStyle = .informational // .Warning .Critical
		displayAlert(alert) { (response: NSApplication.ModalResponse) -> Void in completionHandler() }
	}

	func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
		let alert = NSAlert()
		alert.messageText = webView.title ?? ""
		alert.addButton(withTitle: "OK")
		alert.addButton(withTitle: "Cancel")
		alert.informativeText = message
		alert.icon = NSApplication.shared.applicationIconImage
		displayAlert(alert) { (response: NSApplication.ModalResponse) -> Void in completionHandler(response == .alertFirstButtonReturn ? true : false) }
	}

	func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String?) -> Void) {
		let alert = NSAlert()
		alert.messageText = webView.title ?? ""
		alert.addButton(withTitle: "Submit")
		alert.informativeText = prompt
		alert.icon = NSApplication.shared.applicationIconImage
		let input = NSTextField(frame: NSMakeRect(0, 0, 200, 24))
		input.stringValue = defaultText ?? ""
		input.isEditable = true
 		alert.accessoryView = input
		displayAlert(alert) { (response: NSApplication.ModalResponse) -> Void in completionHandler(input.stringValue) }
	}
}

extension WebViewControllerOSX {

	// https://github.com/WebKit/webkit/commit/fa99fc8295905850b2b9444ba019a7250996ee7d
	@objc func webView(_ webView: WKWebView, didReceiveAuthenticationChallenge challenge: URLAuthenticationChallenge,
		completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

		if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
			if let scheme = challenge.protectionSpace.`protocol` {
				warn("(\(challenge.protectionSpace.authenticationMethod)) \(scheme)://\(challenge.protectionSpace.host):\(challenge.protectionSpace.port) [\(webView.urlstr)]")
			}

			if #available(OSX 10.12, iOS 10, *) {
				// https://developer.apple.com/documentation/foundation/urlsession/authchallengedisposition/performdefaulthandling
				completionHandler(.performDefaultHandling, nil)
			} else {
				// performDefaultHandlingForAuthenticationChallenge(:) not implemented by older OSXs WebKits, so reject this out of hand
				// https://developer.apple.com/documentation/foundation/urlauthenticationchallengesender/1414590-performdefaulthandling
				//  Terminating app due to uncaught exception 'NSInvalidArgumentException'
				//  reason: '-[WebCoreAuthenticationClientAsChallengeSender performDefaultHandlingForAuthenticationChallenge:]: unrecognized selector sent to instance 0x7fd12dc0a4b0'
				completionHandler(.rejectProtectionSpace, nil)
			}

			return
		}
		warn("(\(challenge.protectionSpace.authenticationMethod)) [\(webView.urlstr)]")

		let alert = NSAlert()
		alert.messageText = webView.title ?? ""
		alert.addButton(withTitle: "Submit")
		alert.addButton(withTitle: "Cancel")
		alert.informativeText = "auth challenge"
		alert.icon = NSApplication.shared.applicationIconImage

		let prompts = NSView(frame: NSMakeRect(0, 0, 200, 64))

		let userbox = NSTextField(frame: NSMakeRect(0, 40, 200, 24))
		userbox.stringValue = "Enter user"
 		if let cred = challenge.proposedCredential {
			if let user = cred.user { userbox.stringValue = user }
		}
		userbox.isEditable = true

		let passbox = NSTextField(frame: NSMakeRect(0, 0, 200, 24))
		passbox.stringValue = "Enter password"
 		if let cred = challenge.proposedCredential {
			if cred.hasPassword { passbox.stringValue = cred.password! }
		}
		passbox.isEditable = true

		prompts.subviews = [userbox, passbox]

 		alert.accessoryView = prompts

		//alert.beginSheetModalForWindow(webView.window!, completionHandler:{(response: NSApplication.ModalResponse) -> Void in
		displayAlert(alert) { (response: NSApplication.ModalResponse) -> Void in
			if response == .alertFirstButtonReturn {
				completionHandler(.useCredential, URLCredential(
					user: userbox.stringValue,
					password: passbox.stringValue,
					persistence: .permanent
				))
			} else {
				// need to cancel request, else user can get locked into a modal prompt loop
				//completionHandler(.PerformDefaultHandling, nil)
				completionHandler(.rejectProtectionSpace, nil)
				webView.stopLoading()
			}
 		}
	}
}

// modules/WebKitPrivates/_WKDownloadDelegate.h
// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/Cocoa/DownloadClient.mm
// https://github.com/WebKit/webkit/blob/master/Tools/TestWebKitAPI/Tests/WebKit2Cocoa/Download.mm
extension WebViewControllerOSX { // _WKDownloadDelegate
	override func _download(_ download: _WKDownload!, decideDestinationWithSuggestedFilename filename: String!, allowOverwrite: UnsafeMutablePointer<ObjCBool>) -> String! {
		warn(download.description)
		//pop open a save Panel to dump data into file
		let saveDialog = NSSavePanel()
		saveDialog.canCreateDirectories = true
		saveDialog.nameFieldStringValue = filename
		if let webview = download.originatingWebView, let window = webview.window {
			NSApplication.shared.requestUserAttention(.informationalRequest)
			saveDialog.beginSheetModal(for: window) { (choice: NSApplication.ModalResponse) -> Void in
				NSApp.stopModal(withCode: choice)
				return
			}
			if NSApp.runModal(for: window) != .abort { if let url = saveDialog.url { return url.path } }
		}
		download.cancel()
		return ""
	}
}

extension WebViewControllerOSX { // HTML5 fullscreen
	func _webViewFullscreenMayReturnToInline(_ webView: WKWebView) -> Bool {
		// https://developer.apple.com/reference/webkit/wkwebviewconfiguration/1614793-allowsinlinemediaplayback
		warn()
		return true
	}

	// https://developer.mozilla.org/en-US/docs/Web/API/Fullscreen_API
	//   https://github.com/WebKit/webkit/blob/fdbe0fbe284beb61d253ee00119346b5e3f41957/Source/WebKit2/Shared/WebPreferencesDefinitions.h#L142

	// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/mac/WKFullScreenWindowController.mm
	//  https://github.com/WebKit/webkit/search?q=fullScreenWindowController
	// https://github.com/WebKit/webkit/blob/master/Source/WebCore/platform/mac/WebVideoFullscreenInterfaceMac.mm
	func _webViewDidEnterFullscreen(_ webView: WKWebView) {
		warn("JS <\(webView.urlstr)>: `<video>.requestFullscreen(); // begun`")
	}
	func _webViewDidExitFullscreen(_ webView: WKWebView) {
		warn("JS <\(webView.urlstr)>: `<video>.requestFullscreen(); // finished`")
	}
}

extension WebViewControllerOSX { // _WKFindDelegate
	func _webView(_ webView: WKWebView!, didCountMatches matches: UInt, forString string: String!) {
		warn()
	}
	func _webView(_ webView: WKWebView!, didFindMatches matches: UInt, forString string: String!, withMatchIndex matchIndex: Int) {
		warn()
	}
	func _webView(_ webView: WKWebView!, didFailToFindString string: String!) {
		warn()
	}
}

extension WebViewController { // _WKInputDelegate
	func _webView(_ webView: WKWebView!, didStart inputSession: _WKFormInputSession!) {
		//inputSession.valid .userObject .focusedElementInfo==[.Link,.Image]
		warn()
	}

	@objc func _webView(_ webView: WKWebView!, willSubmitFormValues values: [AnyHashable: Any]!, userObject: (NSSecureCoding & NSObjectProtocol)!, submissionHandler: (() -> Void)!) {
		warn(values.description)
		//userObject: https://github.com/WebKit/webkit/commit/c65916009f1e95f53f329ce3cfe69bf70616cc02#diff-776c38c9a3b2252729ea3ac028367308R1201
		submissionHandler()
	}
}

@available(OSX 10.12, *)
@objc extension WebViewControllerOSX { // WKOpenPanel for <input> file uploading
	// https://bugs.webkit.org/show_bug.cgi?id=137759
	// https://github.com/WebKit/webkit/blob/4b7052ab44fa581810188638d1fdf074e7d754ca/Tools/MiniBrowser/mac/WK2BrowserWindowController.m#L451
	func webView(_ webView: WKWebView!, runOpenPanelWith parameters: WKOpenPanelParameters!, initiatedByFrame frame: WKFrameInfo!, completionHandler: (([NSURL]?) -> Void)!) {
		warn("<input> file upload panel opening!")
		//pop open a save Panel to dump data into file
		let openDialog = NSOpenPanel()
		openDialog.allowsMultipleSelection =  parameters.allowsMultipleSelection
		if let window = webview.window {
			NSApplication.shared.requestUserAttention(.informationalRequest)
			openDialog.beginSheetModal(for: window) { (choice: NSApplication.ModalResponse) -> Void in
				if choice == .OK {
					completionHandler(openDialog.urls as [NSURL]?)
				} else {
					completionHandler(nil)
				}
			}
		}
	}
}

@objc extension WebViewControllerOSX: WKUIDelegatePrivate {

	/*
	//override func _webView(_ webView: WKWebView!, requestNotificationPermissionForSecurityOrigin securityOrigin: WKSecurityOrigin!, decisionHandler: ((Bool) -> Void)!) {
	@objc override func _webView(_ webView: WKWebView!, requestNotificationPermissionFor securityOrigin: WKSecurityOrigin!, decisionHandler: ((Bool) -> Void)!) {
		warn()
		//super._webView(webView, requestNotificationPermissionForSecurityOrigin: securityOrigin, decisionHandler: decisionHandler)
		super._webView(webView, requestNotificationPermissionFor: securityOrigin, decisionHandler: decisionHandler)
	}
	*/

	//@available(OSX 10.13.4, *, iOS 11.3)
	@objc func _webView(_ webView: WKWebView!, requestGeolocationPermissionForFrame frame: WKFrameInfo!, decisionHandler: ((Bool) -> Void)!) {
		warn(webView.url?.absoluteString ?? "")

		//TODO: prompt for approval which could "unlock" the thunk that uiClient will fire after handler(). thunk actaully calls the C api to push approval
		// if unapproved, handle(false) & return now

		if let mpwv = webView as? MPWebView {
			decisionHandler(Geolocator.shared.subscribeToLocationEvents(webview: mpwv))
			return
		}

		decisionHandler(false)
	}

	//func _webView(_ webView: WKWebView!, editorStateDidChange editorState: [AnyHashable : Any]!)

	// handler for PDFViewer's Save-to-File button (blobbed PDFs)
	@objc func _webView(_ webView: WKWebView!, saveDataToFile data: Data!, suggestedFilename: String!, mimeType: String!, originatingURL url: URL!) {
		warn(url.description)
		//pop open a save Panel to dump data into file
		let saveDialog = NSSavePanel()
		saveDialog.canCreateDirectories = true
		saveDialog.nameFieldStringValue = suggestedFilename
		if let window = webview.window {
			NSApplication.shared.requestUserAttention(.informationalRequest)
			saveDialog.beginSheetModal(for: window) { (result: NSApplication.ModalResponse) -> Void in
				if let url = saveDialog.url, result == .OK {
					FileManager.default.createFile(atPath: url.path, contents: data, attributes: nil)
				}
			}
		}
	}

	//@available(OSX 10.13, *)
	@objc func _webView(_ webView: WKWebView!, requestUserMediaAuthorizationFor devices: _WKCaptureDevices, url: URL!, mainFrameURL: URL!, decisionHandler: ((Bool) -> Void)!) {
		warn(url.absoluteString)
		decisionHandler(true)
	}

	//@available(OSX 10.12.3, *)
	@objc func _webView(_ webView: WKWebView!, checkUserMediaPermissionFor url: URL!, mainFrameURL: URL!, frameIdentifier: UInt, decisionHandler: ((String?, Bool) -> Void)!) {
		warn(url.absoluteString)
		//decisionHandler(url.absoluteString, true)
		decisionHandler("0x987654321", true)
	}

	// JS window.beforeunload() handler
	func _webView(_ webView: WKWebView!, runBeforeUnloadConfirmPanelWithMessage message: String!, initiatedByFrame frame: WKFrameInfo!, completionHandler: ((Bool) -> Void)!) {
		let alert = NSAlert()
		alert.messageText = webView.title ?? ""
		alert.addButton(withTitle: "Leave Page")
		alert.addButton(withTitle: "Stay on Page")
		alert.informativeText = "Are you sure you want to leave this page?" //message
		// Safari 9.1+, Chrome 51+, & Firefox 44+ do not allow JS to customize the msgTxt. Thanks scammers.
		alert.icon = NSApplication.shared.applicationIconImage
		displayAlert(alert) { (response: NSApplication.ModalResponse) -> Void in completionHandler(response == .alertFirstButtonReturn) }
 }

	func _webView(_ webView: WKWebView, printFrame: WKFrameInfo) {
		warn("JS: `window.print();`")
		(webView as? MPWebView)?.printWebView(nil)
	}

	//@objc func _webView(_ webView: WKWebView!, drawHeaderInRect rect: CGRect, forPageWithTitle title: String!, URL url: URL!) { warn(); }
	// webview._webViewHeaderHeight
	//@objc func _webView(_ webView: WKWebView!, drawFooterInRect rect: CGRect, forPageWithTitle title: String!, URL url: URL!) { warn(); }
	// webview._webViewFooterHeight

	@available(OSX 10.13, *, iOS 11.0)
	@objc func webView(_ webView: WebView!, dragDestinationActionMaskForDraggingInfo draggingInfo: NSDraggingInfo!) -> Int {
		warn()
		return Int(WKDragDestinationAction.any.rawValue) // accept the drag
		// .none .DHTML .edit .load
	}
	// @objc func _webView(_ webView: WKWebView!, getContextMenuFromProposedMenu menu: NSMenu!, forElement element: _WKContextMenuElementInfoQ, userInfo: Any!, completionHandler: ((NSMenu) -> Void)!) {}

}
