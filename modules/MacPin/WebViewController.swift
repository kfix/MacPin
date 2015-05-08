/// MacPin WebViewController
///
/// Interlocute WebViews to general app UI

/// http://doing-it-wrong.mikeweller.com/2013/06/ios-app-architecture-and-tdd-1.html

import WebKit
import JavaScriptCore
	
@objc class WebViewController: ViewController {

	var jsdelegate: JSValue = JSRuntime.jsdelegate // point to the singleton, for now

	dynamic var webview: MPWebView! = nil

#if os(OSX)
	required init?(coder: NSCoder) { super.init(coder: coder) } // required by NSCoding protocol
	override init!(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) { super.init(nibName:nil, bundle:nil) } //calls loadView
#elseif os(iOS)
#endif

	convenience required init(webview: MPWebView) {
		self.init(nibName: nil, bundle: nil)
		webview.UIDelegate = self //alert(), window.open(): see <platform>/WebViewDelegates
		webview.navigationDelegate = self // allows/denies navigation actions: see WebViewDelegates
		self.webview = webview
#if os(OSX)
		representedObject = webview
#endif
		view = webview
	}

	override func viewDidLoad() {
		super.viewDidLoad() 
	}
	
	func closeTab() { removeFromParentViewController() }
	
	// sugar for opening a new tab in parent browser VC
	func popup(webview: MPWebView) { parentViewController?.addChildViewController(self.dynamicType(webview: webview)) }
}
