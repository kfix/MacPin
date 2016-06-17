/// MacPin WebViewDelegatesIOS
///
/// Handle modal & interactive webview prompts and errors using iOS widgets

import WebKit

extension WebViewControllerIOS {

	func webView(webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: () -> Void) {
		let alerter = UIAlertController(title: webView.title, message: message, preferredStyle: .Alert) //.ActionSheet
		let OK = UIAlertAction(title: "OK", style: .Default) { (action) in completionHandler() }
		alerter.addAction(OK)
		self.presentViewController(alerter, animated: true, completion: nil)
	}

	func webView(webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: (Bool) -> Void) {
		let alerter = UIAlertController(title: webView.title, message: message, preferredStyle: .Alert) //.ActionSheet
		let OK = UIAlertAction(title: "OK", style: .Default) { (action) in completionHandler(true) }
		alerter.addAction(OK)
		let Cancel = UIAlertAction(title: "Cancel", style: .Cancel) { (action) in completionHandler(false) }
		alerter.addAction(Cancel)
		self.presentViewController(alerter, animated: true, completion: nil)
	}

	func webView(webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: (String!) -> Void) {
		let alerter = UIAlertController(title: webView.title, message: prompt, preferredStyle: .Alert)

		//var promptTF: UITextField?
		alerter.addTextFieldWithConfigurationHandler { (tf) in tf.placeholder = defaultText ?? "" } //; promptTF = tf; }

		let Submit = UIAlertAction(title: "Submit", style: .Default) { [unowned alerter] (_) in
			if let tf = alerter.textFields?.first { completionHandler(tf.text) }
			//completionHandler(promptTF?.text ?? "") //doesn't retain?
		}
		alerter.addAction(Submit)

		let Cancel = UIAlertAction(title: "Cancel", style: .Cancel) { (_) in completionHandler("") }
		alerter.addAction(Cancel)

		self.presentViewController(alerter, animated: true, completion: nil)
	}


	func _webView(webView: WKWebView, printFrame: WKFrameInfo) {
		warn("JS: `window.print();`")
		// do iOS printing here
	}

}

extension WebViewControllerIOS {

	func webView(webView: WKWebView, didReceiveAuthenticationChallenge challenge: NSURLAuthenticationChallenge,
		completionHandler: (NSURLSessionAuthChallengeDisposition, NSURLCredential!) -> Void) {

		if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
			completionHandler(.PerformDefaultHandling, nil)
			return
		}
		warn("(\(challenge.protectionSpace.authenticationMethod)) [\(webView.URL ?? String())]")

		let alerter = UIAlertController(title: webView.title, message: "auth challenge", preferredStyle: .Alert)

		alerter.addTextFieldWithConfigurationHandler { (tf) in
			tf.placeholder = "Login"
	 		if let cred = challenge.proposedCredential, let user = cred.user { tf.placeholder = user }
		}

		alerter.addTextFieldWithConfigurationHandler { (tf) in
			tf.placeholder = "Password"
	 		if let cred = challenge.proposedCredential, let passwd = cred.password { tf.placeholder = passwd }
			tf.secureTextEntry = true
		}

		let Login = UIAlertAction(title: "Login", style: .Default) { [unowned alerter] (_) in
			if let user = alerter.textFields?.first, pass = alerter.textFields?[1] {
				completionHandler(.UseCredential, NSURLCredential(
					user: user.text ?? "",
					password: pass.text ?? "",
					persistence: .Permanent
				))
			}
		}
		alerter.addAction(Login)

		let Cancel = UIAlertAction(title: "Cancel", style: .Cancel) { (_) in
			// need to cancel request, else user can get locked into a modal prompt loop
			completionHandler(.PerformDefaultHandling, nil)
			webView.stopLoading()
		}
		alerter.addAction(Cancel)

		self.presentViewController(alerter, animated: true, completion: nil)
	}
}
