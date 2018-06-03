import Foundation
import WebKit

class MPRetriever: NSObject, WKURLSchemeHandler {
	func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
		warn()
		//urlSchemeTask.didReceive(URLResponse(...))
		urlSchemeTask.didFinish()
	}
	func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) { warn() }
}
