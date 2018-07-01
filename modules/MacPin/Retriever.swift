import Foundation
import WebKit

class MPRetriever: NSObject, WKURLSchemeHandler {
	@objc func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
		warn()
		//urlSchemeTask.didReceive(URLResponse(...))
		urlSchemeTask.didFinish()
	}
	@objc func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) { warn() }
}
