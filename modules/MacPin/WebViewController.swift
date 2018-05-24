/// MacPin WebViewController
///
/// Interlocute WebViews to general app UI

import WebKit
import WebKitPrivates
//import WebKitPlus
import JavaScriptCore

@objc class WebViewController: ViewController { //, WebViewControllerScriptExports {
	var jsdelegate: JSValue { get { return AppScriptRuntime.shared.jsdelegate } }
	@objc dynamic var webview: MPWebView! = nil

	//lazy var observer: WebViewObserver = WebViewObserver(obserbee: self.webview) // https://github.com/yashigani/WebKitPlus#webviewobserver

#if os(OSX)
	required init?(coder: NSCoder) { super.init(coder: coder) } // required by NSCoding protocol
	override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) { super.init(nibName:nil, bundle:nil) } //calls loadView
	override func loadView() { view = NSView() } // NIBless
	convenience required init(webview: MPWebView) {
		self.init(nibName: nil, bundle: nil) // calls init!() http://stackoverflow.com/a/26516534/3878712
		webview.uiDelegate = self //alert(), window.open(): see <platform>/WebViewDelegates
		webview.navigationDelegate = self // allows/denies navigation actions: see WebViewDelegates
		webview._formDelegate = self //FIXME: ._inputDelegate = self
		webview._findDelegate = self

		if #available(OSX 10.13, iOS 11, *) {
			webview._iconLoadingDelegate = self
			//webview._historyDelegate = self
		}

		UserNotifier.shared.subscribe(webview: webview)

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
		webview.uiDelegate = self //alert(), window.open(): see <platform>/WebViewDelegates
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

	@objc dynamic func dismiss() { webview._close(); view.removeFromSuperview(); removeFromParentViewController(); warn() }
	@objc func askToOpenCurrentURL() { askToOpenURL(webview.url as NSURL?) }

	// sugar for delgates' opening a new tab in parent browser VC
	func popup(_ webview: MPWebView) { parent?.addChildViewController(type(of: self).init(webview: webview)) }

	deinit { warn(description) }
}
