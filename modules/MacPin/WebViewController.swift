/// MacPin WebViewController
///
/// Interlocute WebViews to general app UI

import WebKit
import WebKitPrivates
//import WebKitPlus
import JavaScriptCore

@objc class WebViewController: ViewController { //, WebViewControllerScriptExports {
	var jsdelegate: JSValue { get { return AppScriptRuntime.shared.jsdelegate } }
	dynamic var webview: MPWebView! = nil

	//lazy var observer: WebViewObserver = WebViewObserver(obserbee: self.webview) // https://github.com/yashigani/WebKitPlus#webviewobserver

#if os(OSX)
	required init?(coder: NSCoder) { super.init(coder: coder) } // required by NSCoding protocol
	override init!(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) { super.init(nibName:nil, bundle:nil) } //calls loadView
	override func loadView() { view = NSView() } // NIBless
	convenience required init(webview: MPWebView) {
		self.init(nibName: nil, bundle: nil) // calls init!() http://stackoverflow.com/a/26516534/3878712
		webview.uiDelegate = self //alert(), window.open(): see <platform>/WebViewDelegates
		webview.navigationDelegate = self // allows/denies navigation actions: see WebViewDelegates
		//webview._historyDelegate = self
		webview._formDelegate = self //FIXME: ._inputDelegate = self
		webview._findDelegate = self
		webview._iconLoadingDelegate = self
#if DEBUG
		webview._diagnosticLoggingDelegate = self
#endif
		webview.configuration.processPool._downloadDelegate = self
		self.webview = webview
		representedObject = webview	// FIXME use NSProxy instead for both OSX and IOS

		view.addSubview(webview, positioned: .below, relativeTo: nil) // need an empty parent view for the inspector to attach to
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
	        if let wti = webview.title, !wti.isEmpty { return wti }
				else if !webview.urlstr.isEmpty { return webview.urlstr }
				else { return "Untitled" }
		}
		set {
			//noop
		}
	}

	override func viewDidLoad() {
		super.viewDidLoad()
	}

	func dismiss() { webview._close(); view.removeFromSuperview(); removeFromParentViewController(); warn() }
	func askToOpenCurrentURL() { askToOpenURL(webview.url as NSURL?) }

	// sugar for delgates' opening a new tab in parent browser VC
	func popup(_ webview: MPWebView) { parent?.addChildViewController(type(of: self).init(webview: webview)) }

	deinit { warn(description) }
}

extension WebViewController: _WKDiagnosticLoggingDelegate {
	func _webView(_ webView: WKWebView, logDiagnosticMessage message: String, description: String) { warn("\(message) || \(description) << \(webView.url?.absoluteString ?? String())") }
	func _webView(_ webView: WKWebView, logDiagnosticMessageWithResult message: String, description: String, result: _WKDiagnosticLoggingResultType) { warn("\(message) || \(description) >> \(String(describing: result)) << \(webView.url?.absoluteString ?? String())") }
	func _webView(_ webView: WKWebView, logDiagnosticMessageWithValue message: String, description: String, value: String) { warn("\(message) || \(description) == \(value) << \(webView.url?.absoluteString ?? String())") }
}

extension WebViewController: _WKDownloadDelegate {
    func _downloadDidStart(_ download: _WKDownload!) { warn(download.request.description) }
	func _download(_ download: _WKDownload!, didReceive response: URLResponse!) { warn(response.description) }
	func _download(_ download: _WKDownload!, didReceiveData length: UInt64) { warn(length.description) }
	func _download(_ download: _WKDownload!, decideDestinationWithSuggestedFilename filename: String!, allowOverwrite: UnsafeMutablePointer<ObjCBool>) -> String! {
		warn("NOIMPL: " + download.request.description)
		download.cancel()
		return ""
	}
	func _downloadDidFinish(_ download: _WKDownload!) { warn(download.request.description) }
	func _download(_ download: _WKDownload!, didFailWithError error: Error!) { warn(error.localizedDescription) }
	func _downloadDidCancel(_ download: _WKDownload!) { warn(download.request.description) }
}

// extensions WebViewController: WebsitePoliciesDelegate // FIXME: STP v20: per-site preferences: https://github.com/WebKit/webkit/commit/d9f6f7249630d7756e4b6ca572b29ac61d5c38d7

extension WebViewController: _WKIconLoadingDelegate {
	@objc func webView(_ webView: WKWebView, shouldLoadIconWith parameters: _WKLinkIconParameters, completionHandler: @escaping ((Data) -> Void) -> Void) {
		completionHandler() { data in
			// data.length
			warn("page (\(webView.url?.absoluteString) got icon from <- \(parameters.url.absoluteString)")
		}
	}
}
