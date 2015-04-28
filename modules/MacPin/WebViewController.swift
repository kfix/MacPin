/// MacPin WebViewController
///
/// Provides sugar to initialize and modify WKWebViews
/// Should probably move most of this logic to a WKWebView subclass, but its been marked final?

import WebKit
import WebKitPrivates
import JavaScriptCore
	
var GlobalUserScripts: [String] = [] // $.globalUserScripts singleton
		
@objc protocol WebViewScriptExports : JSExport { // $.WebView & $.browser.tabs[WebView]
	init?(object: [String:AnyObject]) //> new WebView({url: 'http://example.com'});
	// can only JSExport one init*() func!
	// https://github.com/WebKit/webkit/blob/master/Source/JavaScriptCore/API/tests/testapi.mm
	// https://github.com/WebKit/webkit/blob/master/Source/JavaScriptCore/API/JSWrapperMap.mm#L412

	var transparent: Bool { get set }
	var userAgent: String { get set }
	func close()
	func evalJS(js: String, _ withCallback: JSValue?) 
	func loadURL(urlstr: String) -> Bool
	func loadIcon(icon: String) -> Bool
	func preinject(script: String)
	func postinject(script: String)
	func addHandler(handler: String)
	func subscribeTo(handler: String)
}

protocol WebViewControlling {
	init(config: WKWebViewConfiguration?, agent: String?)
	init(url: NSURL, agent: String?)
}

@objc class WebViewController: ViewController, WebViewControlling, WebViewScriptExports {

	static func make_webview(_ config: WKWebViewConfiguration = WKWebViewConfiguration()) -> WKWebView {
		// init webview with custom config, needed for JS:window.open() which links new child Windows to parent Window
		let prefs = WKPreferences() // http://trac.webkit.org/browser/trunk/Source/WebKit2/UIProcess/API/Cocoa/WKPreferences.mm
		prefs.plugInsEnabled = true // NPAPI for Flash, Java, Hangouts
		//prefs.minimumFontSize = 14 //for blindies
		prefs.javaScriptCanOpenWindowsAutomatically = true;
		prefs._developerExtrasEnabled = true // http://trac.webkit.org/changeset/172406 will land in OSX 10.10.3?
#if WK2LOG
		//prefs._diagnosticLoggingEnabled = true //10.10.3?
#endif
		config.preferences = prefs
		config.suppressesIncrementalRendering = false
		//withConfiguration._websiteDataStore = _WKWebsiteDataStore.nonPersistentDataStore
		return WKWebView(frame: CGRectZero, configuration: config)
	}

	lazy var webview: WKWebView = { return WebViewController.make_webview() }()
	
	dynamic unowned var favicon: Image = Image(named: NSImageNameApplicationIcon)! { // NSImageNameStatusNone
		didSet {
			//if let name = favicon.name() { warn("= \(name)") }
			favicon.size = CGSize(width: 16, height: 16)
		}
		//need 24 & 36px**2 representations for the NSImage for bigger grid views
		// https://developer.apple.com/library/ios/documentation/AppleApplications/Reference/SafariWebContent/ConfiguringWebApplications/ConfiguringWebApplications.html
		// just C, no Cocoa API yet: WKIconDatabaseCopyIconURLForPageURL(icodb, url) WKIconDatabaseCopyIconDataForPageURL(icodb, url)
		// also https://github.com/WebKit/webkit/commit/660d1e55c2d1ee19ece4a7565d8df8cab2e15125
		// OSX has libxml2 built-in https://developer.apple.com/library/mac/samplecode/LinkedImageFetcher/Listings/Read_Me_About_LinkedImageFetcher_txt.html
	}
		
	var userAgent: String { 
		get { return webview._customUserAgent ?? webview._userAgent ?? "" }
		// https://github.com/WebKit/webkit/blob/master/Source/WebCore/page/mac/UserAgentMac.mm#L48
		set(agent) { if !agent.isEmpty { webview._customUserAgent = agent } }
	}

/*
	var preinjects: [String]: [] { didSet { webview.configuration.userContentController.removeAllUserScripts(); for script in preinjects { wvc.preinject(script) } } }
	//var postinjects: [String]: [] { didSet { for script in postinjects { wvc.postinject(script) } } }
	var subscribed: [String]: [] { didSet { for handler in subscribed { webview.configuration.userContentController.removeScriptMessageHandlerForName(handler); wvc.addHandler(handler) } } }
*/

	var transparent: Bool = false
 
	var container: WebViewContainer? { get {
		if let container = presentingViewController?.representedObject as? WebViewContainer { return container }
		if let container = parentViewController?.representedObject as? WebViewContainer { return container }
		return nil
	}}

	required init?(coder: NSCoder) { super.init(coder: coder) } // required by NSCoding protocol
	override init!(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) { super.init(nibName:nil, bundle:nil) } //calls loadView
	override func loadView() { view = webview } // NIBless  

	convenience required init(config: WKWebViewConfiguration? = WKWebViewConfiguration(), agent: String? = nil) {
		self.init(nibName: nil, bundle: nil)
		if let config = config { webview = WebViewController.make_webview(config) }
		if let agent = agent { if !agent.isEmpty { userAgent = agent } }
	}

	convenience required init?(object: [String:AnyObject]) {
		self.init(config: nil)
		var url = NSURL(string: "about:blank")
		for (key, value) in object {
			switch value {
				case let urlstr as String where key == "url": url = NSURL(string: urlstr)
				case let agent as String where key == "agent": userAgent = agent
				case let icon as String where key == "icon": loadIcon(icon)
				case let transparent as Bool where key == "transparent": self.transparent = transparent
				case let value as [String] where key == "preinject": for script in value { preinject(script) }
				case let value as [String] where key == "postinject": for script in value { postinject(script) }
				case let value as [String] where key == "handlers": for handler in value { addHandler(handler) }
				default: warn("unhandled param: `\(key): \(value)`")
			}
		}

		for script in GlobalUserScripts { postinject(script) }
		if let url = url { gotoURL(url) } else { return nil }
	}

	convenience required init(url: NSURL, agent: String? = nil) {
		self.init(config: nil)
		if let agent = agent { if !agent.isEmpty { userAgent = agent } }
		gotoURL(url)
	}

	override var description: String { return "<\(reflect(self).summary)> `\(webview.title ?? String())` [\(webview.URL ?? String())]" }

	override func viewDidLoad() {
		super.viewDidLoad()
		webview.allowsBackForwardNavigationGestures = true
		webview.allowsMagnification = true
#if SAFARIDBG
		webview._allowsRemoteInspection = true // start webinspectord child
		// enables Safari.app->Develop-><computer name> remote debugging of JSCore and all webviews' JS threads
		// http://stackoverflow.com/questions/11361822/debug-ios-67-mobile-safari-using-the-chrome-devtools
#endif
		//webview._editable = true // https://github.com/WebKit/webkit/tree/master/Tools/WebEditingTester
		webview.navigationDelegate = self // allows/denies navigation actions
	}
	
	override func viewWillAppear() { // window popping up with this tab already selected & showing
		super.viewWillAppear() // or tab switching into view as current selection
		container?.transparent = transparent
		webview._drawsTransparentBackground = transparent
	}
}

/*
extension WebViewController: NSMenuDelegate {
	func menuNeedsUpdate(menu: NSMenu) {
		//if menu.tag == 1 //backlist
		for histItem in webview.backForwardList.backList {
			if let histItem = histItem as? WKBackForwardListItem {
				let mi = NSMenuItem(title:(histItem.title ?? histItem.URL.absoluteString!), action:Selector("gotoHistoryMenuURL:"), keyEquivalent:"" )
				mi.representedObject = histItem.URL
				mi.target = self
			}
		}
	}
}
*/

extension WebViewController: WebViewScriptExports { // AppGUI / ScriptRuntime funcs

	func evalJS(js: String, _ withCallback: JSValue? = nil) {
		if let withCallback = withCallback {
			if withCallback.isObject() { //is a function or a {}
				warn("withCallback: \(withCallback)")
				webview.evaluateJavaScript(js, completionHandler:{ (result: AnyObject!, exception: NSError!) -> Void in
					// (result: WebKit::WebSerializedScriptValue*, exception: WebKit::CallbackBase::Error)
					//withCallback.callWithArguments([result, exception]) // crashes, need to translate exception into something javascripty
					//warn("()~> \(result),\(exception)")
					withCallback.callWithArguments([result, true]) // unowning withCallback causes a crash and weaking it muffs the call
					return
				})
				return
			}
		}
		webview.evaluateJavaScript(js, completionHandler: nil)
	}

	func close() { removeFromParentViewController() }

	func print(sender: AnyObject?) { warn(""); webview.print(sender) }

	//FIXME: support new scaling https://github.com/WebKit/webkit/commit/b40b702baeb28a497d29d814332fbb12a2e25d03
	func zoomIn() { webview.magnification += 0.2 }
	func zoomOut() { webview.magnification -= 0.2 }

	func toggleTransparency() { transparent = !transparent }

	func gotoURL(url: NSURL) {
		if url.scheme == "file" {
			//webview.loadFileURL(url, allowingReadAccessToURL: url.URLByDeletingLastPathComponent!) //load file and allow link access to its parent dir
			//		waiting on http://trac.webkit.org/changeset/174029/trunk to land
			//webview._addOriginAccessWhitelistEntry(WithSourceOrigin:destinationProtocol:destinationHost:allowDestinationSubdomains:)
			// need to allow loads from file:// to inject NSBundle's CSS
		}
		webview.loadRequest(NSURLRequest(URL: url))
	}

	func loadURL(urlstr: String) -> Bool { // overloading gotoURL is crashing Cocoa selectors
		if let url = NSURL(string: urlstr) { 
			gotoURL(url as NSURL)
			return true
		}
		return false // tell JS we were given a malformed URL
	}

	func askToOpenURL(url: NSURL?) {} // should override this in your platform-subclasses
	func askToOpenCurrentURL() { askToOpenURL(webview.URL) }

	func scrapeIcon(webview: WKWebView) {
		// https://code.google.com/p/cocoalicious/source/browse/trunk/cocoalicious/Utilities/SFHFFaviconCache.m
#if os(OSX)
		// check the cache first
		if let url = webview.URL {
			if let host = url.host {
				if let icon = Image(named: host) { //named: uses system NSImage cache 
					self.favicon = icon
					return
				}
			}
		}
#endif

		webview.evaluateJavaScript("if (icon = document.querySelector('link[rel$=icon]')) { icon.href };", completionHandler:{ [unowned self] (result: AnyObject!, exception: NSError!) -> Void in
			if let href = result as? String {
				self.loadIcon(href)
			} else {
				// look for a root-domain-level icon file
				if let url = webview.URL {
					let iconurlp = NSURLComponents(URL: url, resolvingAgainstBaseURL: false)!
					iconurlp.path = "/favicon.ico"
					self.loadIcon(iconurlp.string!)
				}
			}
		})
	}

	func loadIcon(icon: String) -> Bool {
		// http://stackoverflow.com/a/26540173/3878712
		// http://jamesonquave.com/blog/developing-ios-apps-using-swift-part-5-async-image-loading-and-caching/
		if let url = NSURL(string: icon) where !icon.isEmpty { 
			//favicon = NSImage(byReferencingURL: url) //FIXMEios
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { //[unowned self]
				if let data = NSData(contentsOfURL: url) { // downloaded from background thread. HTTP error should return nil...
					dispatch_async(dispatch_get_main_queue()) { // return to UI thread to update icon
						if let img = Image(data: data) {
							self.favicon = img
#if os(OSX)
							if let host = url.host { self.favicon.setName(host) } // add cache name
#endif
						}
					}
				}
			})
			return true // URL was parsed ok, does NOT mean icon was sucessfully downloaded and assigned
		}
		return false
	}

	func preinject(script: String) { loadUserScriptFromBundle(script, webview.configuration.userContentController, .AtDocumentStart, onlyForTop: false) }
	func postinject(script: String) { loadUserScriptFromBundle(script, webview.configuration.userContentController, .AtDocumentEnd, onlyForTop: false) }
	func addHandler(handler: String) { webview.configuration.userContentController.addScriptMessageHandler(self, name: handler) }
	func subscribeTo(handler: String) { webview.configuration.userContentController.addScriptMessageHandler(self, name: handler) }

	func REPL() {
		termiosREPL({ (line: String) -> Void in
			self.webview.evaluateJavaScript(line, completionHandler:{ [unowned self] (result: AnyObject!, exception: NSError!) -> Void in
				println(result)
				println(exception)
			})
		})
	}

}

//extension WebViewController: Printable {
//	//func description() -> String {
//	var description: String {
//		return "<\(reflect(self).summary)> `\(webview.title.description)` [\(webview.URL.description)]"
//	}
//}
