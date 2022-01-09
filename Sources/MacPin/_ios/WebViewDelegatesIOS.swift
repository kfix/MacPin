/// MacPin WebViewDelegatesIOS
///
/// Handle modal & interactive webview prompts and errors using iOS widgets

import WebKit

extension WebViewControllerIOS {

	func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
		let alerter = UIAlertController(title: webView.title, message: message, preferredStyle: .alert) //.ActionSheet
		let OK = UIAlertAction(title: "OK", style: .default) { (action) in completionHandler() }
		alerter.addAction(OK)
		self.present(alerter, animated: true, completion: nil)
	}

	func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
		let alerter = UIAlertController(title: webView.title, message: message, preferredStyle: .alert) //.ActionSheet
		let OK = UIAlertAction(title: "OK", style: .default) { (action) in completionHandler(true) }
		alerter.addAction(OK)
		let Cancel = UIAlertAction(title: "Cancel", style: .cancel) { (action) in completionHandler(false) }
		alerter.addAction(Cancel)
		self.present(alerter, animated: true, completion: nil)
	}

	func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (String) -> Void) {
		let alerter = UIAlertController(title: webView.title, message: prompt, preferredStyle: .alert)

		//var promptTF: UITextField?
		alerter.addTextField { (tf) in tf.placeholder = defaultText ?? "" } //; promptTF = tf; }

		let Submit = UIAlertAction(title: "Submit", style: .default) { [unowned alerter] (_) in
			if let tf = alerter.textFields?.first { completionHandler(tf.text ?? "") }
			//completionHandler(promptTF?.text ?? "") //doesn't retain?
		}
		alerter.addAction(Submit)

		let Cancel = UIAlertAction(title: "Cancel", style: .cancel) { (_) in completionHandler("") }
		alerter.addAction(Cancel)

		self.present(alerter, animated: true, completion: nil)
	}


	func _webView(_ webView: WKWebView, printFrame: WKFrameInfo) {
		warn("JS: `window.print();`")
		// do iOS printing here
	}

}

extension WebViewControllerIOS {

	func webView(_ webView: WKWebView, didReceiveAuthenticationChallenge challenge: URLAuthenticationChallenge,
		completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

		if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
			completionHandler(.performDefaultHandling, nil)
			return
		}
		warn("(\(challenge.protectionSpace.authenticationMethod)) [\(webView.url?.absoluteString ?? String())]")

		let alerter = UIAlertController(title: webView.title, message: "auth challenge", preferredStyle: .alert)

		alerter.addTextField { (tf) in
			tf.placeholder = "Login"
	 		if let cred = challenge.proposedCredential, let user = cred.user { tf.placeholder = user }
		}

		alerter.addTextField { (tf) in
			tf.placeholder = "Password"
	 		if let cred = challenge.proposedCredential, let passwd = cred.password { tf.placeholder = passwd }
			tf.isSecureTextEntry = true
		}

		let Login = UIAlertAction(title: "Login", style: .default) { [unowned alerter] (_) in
			if let user = alerter.textFields?.first, let pass = alerter.textFields?[1] {
				completionHandler(.useCredential, URLCredential(
					user: user.text ?? "",
					password: pass.text ?? "",
					persistence: .permanent
				))
			}
		}
		alerter.addAction(Login)

		let Cancel = UIAlertAction(title: "Cancel", style: .cancel) { (_) in
			// need to cancel request, else user can get locked into a modal prompt loop
			completionHandler(.performDefaultHandling, nil)
			//
			webView.stopLoading()
		}
		alerter.addAction(Cancel)

		self.present(alerter, animated: true, completion: nil)
	}
}
