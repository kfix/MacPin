/// MacPin WebViewController
///
/// Interlocute WebViews to general app UI

import WebKit
import JavaScriptCore

@objc protocol WebViewControllerScriptExports: JSExport { // $.browser.tabs[N]
#if os(OSX)
	var view: NSView { get }
#elseif os(iOS)
	var view: UIView! { get }
#endif
	var webview: MPWebView! { get }
}

@objc class WebViewController: ViewController, WebViewControllerScriptExports {
	var jsdelegate = AppScriptRuntime.shared.jsdelegate // FIXME: use webview.jsdelegate instead ??
	dynamic var webview: MPWebView! = nil

#if os(OSX)
	required init?(coder: NSCoder) { super.init(coder: coder) } // required by NSCoding protocol
	override init!(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) { super.init(nibName:nil, bundle:nil) } //calls loadView
	convenience required init(webview: MPWebView) {
		self.init(nibName: nil, bundle: nil) // calls init!() http://stackoverflow.com/a/26516534/3878712
		webview.UIDelegate = self //alert(), window.open(): see <platform>/WebViewDelegates
		webview.navigationDelegate = self // allows/denies navigation actions: see WebViewDelegates
		self.webview = webview
		representedObject = webview	// FIXME use NSProxy instead for both OSX and IOS
		view = webview
	}
#elseif os(iOS)
	required init(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }
	required init(webview: MPWebView) {
		super.init(nibName: nil, bundle: nil)
		webview.UIDelegate = self //alert(), window.open(): see <platform>/WebViewDelegates
		webview.navigationDelegate = self // allows/denies navigation actions: see WebViewDelegates
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

	func closeTab() { removeFromParentViewController() }
	func askToOpenCurrentURL() { askToOpenURL(webview.URL!) }

	// sugar for opening a new tab in parent browser VC
	func popup(webview: MPWebView) { parentViewController?.addChildViewController(self.dynamicType(webview: webview)) }
}
