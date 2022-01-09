import Foundation
import WebKit

@available(macOS 10.13, iOS 10, *)
class MPRetriever: NSObject, WKURLSchemeHandler {
	@objc func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
		warn()
		//urlSchemeTask.didReceive(URLResponse(...))
		urlSchemeTask.didFinish()
	}
	@objc func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) { warn() }
}
