/// MacPin WebViewController
///
/// Interlocute WebViews to general app UI

import WebKit
import WebKitPrivates
import JavaScriptCore

// https://github.com/apple/swift-evolution/blob/master/proposals/0160-objc-inference.md#re-enabling-objc-inference-within-a-class-hierarchy
@objcMembers
class WebViewController: ViewController { //, WebViewControllerScriptExports {
	@objc unowned var webview: MPWebView

#if os(OSX)
	override func loadView() { view = NSView() } // NIBless
#endif

	let browsingReactor = AppScriptRuntime.shared
	// ^ this is a simple object that can re-broadcast events from the webview and return with confirmation that those events were "handled" or not.
	// this lets the controller know whether it should perform "reasonable browser-like actions" or to defer to the Reactor's business logic.

	required init?(coder: NSCoder) { self.webview = MPWebView(); super.init(coder: coder); } // required by NSCoding protocol
	override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) { self.webview = MPWebView(); super.init(nibName:nil, bundle:nil) } //calls loadView
	required init(webview: MPWebView) {
		self.webview = webview
		super.init(nibName: nil, bundle: nil)
		webview.navigationDelegate = self // allows/denies navigation actions: see WebViewDelegates
		//webview._formDelegate = self //FIXME: ._inputDelegate = self
		webview._findDelegate = self

		if WebKit_version >= (603, 1, 17) {
			// STP 57, Safari 12
			webview._iconLoadingDelegate = self
		}
		//webview._historyDelegate = self

#if DEBUG
		//webview._diagnosticLoggingDelegate = self
#endif
		webview.configuration.processPool._downloadDelegate = self
		webview.configuration.processPool._setCanHandleHTTPSServerTrustEvaluation(true)

		WebViewUICallbacks.subscribe(webview)

#if os(OSX)
		WebViewNotificationCallbacks.subscribe(webview)
		// sometimes the webview will go away on its own a minute after being closed, sometime it won't ...

		representedObject = webview	// OSX omnibox/browser uses KVC to interrogate webview
		view.addSubview(webview, positioned: .below, relativeTo: nil)
		// must retain the empty parent view for the inspector to co-attach to alongside the webview
#elseif os(iOS)
		view = webview
#endif
	}

	override func viewDidLoad() {
		super.viewDidLoad()
	}

	// func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) // iOS
	//@objc func dismiss(_ viewController: ViewController) { // OSX
	@objc dynamic func dismiss() {
#if os(OSX)
		//warn(obj: self)
		representedObject = nil
		//webview.stopLoading()
		//webview._close()
		view.nextKeyView = nil
		view.nextResponder = nil
#endif
		//webview.uiDelegate = nil
		//webview.navigationDelegate = nil
		//webview._findDelegate = nil
		if WebKit_version >= (603, 1, 17) {
			webview._iconLoadingDelegate = nil
		}
	}

	@objc func askToOpenCurrentURL() { askToOpenURL(webview.url as NSURL?) }

	// sugar for delgates' opening a new tab in parent browser VC
	func popup(_ webview: MPWebView) -> WebViewController {
		let wvc = type(of: self).init(webview: webview)
		parent?.addChildViewController(wvc)
		return wvc
	}

	@objc dynamic func focus() { warn("not implemented!") }

	deinit { warn(description) }

}
