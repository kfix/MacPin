/// MacPin WebViewController
///
/// Interlocute WebViews to general app UI

import WebKit
import WebKitPrivates
import JavaScriptCore

@objc class WebViewController: ViewController { //, WebViewControllerScriptExports {
	var jsdelegate = AppScriptRuntime.shared.jsdelegate // FIXME: use webview.jsdelegate instead ??
	dynamic var webview: MPWebView! = nil

#if os(OSX)
	required init?(coder: NSCoder) { super.init(coder: coder) } // required by NSCoding protocol
	override init!(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) { super.init(nibName:nil, bundle:nil) } //calls loadView
	convenience required init(webview: MPWebView) {
		self.init(nibName: nil, bundle: nil) // calls init!() http://stackoverflow.com/a/26516534/3878712
		webview.UIDelegate = self //alert(), window.open(): see <platform>/WebViewDelegates
		webview.navigationDelegate = self // allows/denies navigation actions: see WebViewDelegates
#if DEBUG
		webview._diagnosticLoggingDelegate = self
#endif
		webview.configuration.processPool._downloadDelegate = self
		self.webview = webview
		representedObject = webview	// FIXME use NSProxy instead for both OSX and IOS
		view = webview
	}
#elseif os(iOS)
	required init?(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }
	required init!(webview: MPWebView) {
		super.init(nibName: nil, bundle: nil)
		webview.UIDelegate = self //alert(), window.open(): see <platform>/WebViewDelegates
		webview.navigationDelegate = self // allows/denies navigation actions: see WebViewDelegates
#if DEBUG
		webview._diagnosticLoggingDelegate = self
#endif
		webview.configuration.processPool._downloadDelegate = self
		self.webview = webview
		view = webview
	}
#endif

	override var title: String? {
		get {
	        if let wti = webview.title where !wti.isEmpty { return wti }
				else if let urlstr = webview.URL?.absoluteString where !urlstr.isEmpty { return urlstr }
				else { return "Untitled" }
		}
		set {
			//noop
		}
	}

	override func viewDidLoad() {
		super.viewDidLoad()
	}

	func closeTab() { removeFromParentViewController(); webview = nil }
	func askToOpenCurrentURL() { askToOpenURL(webview.URL!) }

	// sugar for delgates' opening a new tab in parent browser VC
	func popup(webview: MPWebView) { parentViewController?.addChildViewController(self.dynamicType.init(webview: webview)) }
}

extension WebViewController: _WKDiagnosticLoggingDelegate {
	func _webView(webView: WKWebView, logDiagnosticMessage message: String, description: String) { warn("\(message) || \(description)") }
	func _webView(webView: WKWebView, logDiagnosticMessageWithResult message: String, description: String, result: _WKDiagnosticLoggingResultType) { warn("\(message) || \(description) >> \(String(result))") }
	func _webView(webView: WKWebView, logDiagnosticMessageWithValue message: String, description: String, value: String) { warn("\(message) || \(description) == \(value)") }
}

extension WebViewController: _WKDownloadDelegate {
    func _downloadDidStart(download: _WKDownload!) { warn(download.request.description) }
	func _download(download: _WKDownload!, didRecieveResponse response: NSURLResponse!) { warn(response.description) }
	func _download(download: _WKDownload!, didRecieveData length: UInt64) { warn(length.description) }
	func _download(download: _WKDownload!, decideDestinationWithSuggestedFilename filename: String!, allowOverwrite: UnsafeMutablePointer<ObjCBool>) -> String! {
		warn("NOIMPL: " + download.request.description)
		download.cancel()
		return ""
	}
	func _downloadDidFinish(download: _WKDownload!) { warn(download.request.description) }
	func _download(download: _WKDownload!, didFailWithError error: NSError!) { warn(error.description) }
	func _downloadDidCancel(download: _WKDownload!) { warn(download.request.description) }
}
