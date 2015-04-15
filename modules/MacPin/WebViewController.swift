import WebKit
import WebKitPrivates
import Prompt
	
var GlobalUserScripts: [String] = [] // $.globalUserScripts singleton
		
@objc protocol WebViewScriptExports : JSExport { // $.browser.tabs[WebView] & $.WebView.createWithObj()
	init(config: WKWebViewConfiguration?)
	// func _init() -> WebViewController
	//init(config: WKWebViewConfiguration? = WKWebViewConfiguration()) //swiftc segfaults!
	// should be able to call init()s with JS `new` : https://bugs.webkit.org/show_bug.cgi?id=123380 
	// https://github.com/WebKit/webkit/blob/master/Source/JavaScriptCore/API/tests/testapi.mm
		//>> new WebView();
		//	TypeError: MacPin.WebViewControllerConstructor is not a constructor (evaluating 'new WebView()')
		// the init()s are in $.WebView.prototype but not $.WebView .
		// JSExport compatible with swift-mangling? https://github.com/WebKit/webkit/blob/master/Source/JavaScriptCore/API/JSWrapperMap.mm#L412
		// [.text] __TFC6MacPin17WebViewController5_initfS0_FT_S0_
		// nm build/Frameworks/libMacPin.dylib | xcrun swift-demangle | grep Type | grep init | grep objc | grep WebViewController
		// https://securify.nl/blog/SFY20150302/hooking_swift_methods_for_fun_and_profit.html

	static func createWithObj(conf: [String:AnyObject]) -> WebViewController?
	//class func createWithObj(conf: [WebViewController.Properties:AnyObject]) -> WebViewController?

	var isTransparent: Bool { get set }
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

@objc class WebViewController: NSViewController {

/*
	// a JS-friendly property IDL
	//@objc enum Properties { // swift 1.2 !!
	enum Properties {
		case URL
		case Agent
		case Icon
		case Transparent
		case Preinject
		case Postinject
		case SubscribeTo
	}
	var props: [Properties: AnyObject] = [:]
	subscript(prop: Properties) -> AnyObject {
		get { return props[prop] }
			switch prop {
				case .URL: return webview.URL
				case .Agent: return userAgent
				case .Icon: return favicon
				case .Transparent: return isTransparent
				case .Preinject: fallthrough
				case .Postinject: return webview.configuration.userContentController.userScripts
				case .SubscribeTo: return subscribed
				default:
					warn("unhandled prop: `\(prop)`")
			}

		set(value) {
			switch prop {
				case .URL:
					if let urlstr = value as? String { if let url = NSURL(string: urlstr) { wvc.gotoURL(url) } }
				case .Agent:
					if let agent = value as? String { wvc.userAgent = agent }
				case .Icon:
					if let icon = value as? String { wvc.loadIcon(icon) }
				case .Transparent:
					if let transparent = value as? Bool { wvc.isTransparent = transparent }
				case .Preinject:
					if let value = value as? [String] { for script in value { wvc.preinject(script) } }
				case .Postinject:
					if let value = value as? [String] { for script in value { wvc.postinject(script) } }
				case .SubscribeTo:
					if let value = value as? [String] { for handler in value { wvc.addHandler(handler) } }
				default:
					warn("unhandled prop: `\(prop)`")
			}
		}
	}
*/

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

	//FIXME - static func?
	class func createWithObj(conf: [String:AnyObject]) -> WebViewController? { //factory method for JSExport
	//class func createWithObj(conf: [Properties:AnyObject]) -> WebViewController? { //factory method for JSExport
		var url = NSURL(string: "about:blank")
		let wvc = WebViewController(config: nil)

		for (key, value) in conf {
/*
			switch (key, value) {
				case ("url", let urlstr as? String): url = NSURL(string: urlstr)
				case ("agent", let agent as? String): wvc.userAgent = agent
				case ("icon", let icon as? String): wvc.loadIcon(icon)
				case ("transparent", let transparent as? Bool): wvc.isTransparent = transparent
				case ("preinject", let value as? [String]): for script in value { wvc.preinject(script) }
				case ("postinject", let value as? [String]): for script in value { wvc.postinject(script) }
				case ("handlers", _ ): fallthrough
				case ("subscribeTo", let value as? [String]): for handler in value { wvc.addHandler(handler) }
				default: warn("unhandled param: `\(key)`")
			}

			switch value {
				case let urlstr as? String where key == "url": url = NSURL(string: urlstr)
				case let agent as? String where key == "agent": wvc.userAgent = agent
				case let icon as? String where key == "icon": wvc.loadIcon(icon)
				case let transparent as? Bool where key == "transparent": wvc.isTransparent = transparent
				case let value as? [String] where key == "preinject": for script in value { wvc.preinject(script) }
				case let value as? [String] where key == "postinject": for script in value { wvc.postinject(script) }
				case let value as? [String] where key == "handlers": for handler in value { wvc.addHandler(handler) }
				default: warn("unhandled param: `\(key)`")
			}
*/

			switch key {
				case "url":
					if let urlstr = value as? String { url = NSURL(string: urlstr) }
				case "agent":
					if let agent = value as? String { wvc.userAgent = agent }
				case "icon":
					if let icon = value as? String { wvc.loadIcon(icon) }
				case "transparent":
					if let transparent = value as? Bool { wvc.isTransparent = transparent }
				case "preinject":
					if let value = value as? [String] { for script in value { wvc.preinject(script) } }
				case "postinject":
					if let value = value as? [String] { for script in value { wvc.postinject(script) } }
				case "handlers": fallthrough
				case "subscribeTo":
					if let value = value as? [String] { for handler in value { wvc.addHandler(handler) } }
				default:
					warn("unhandled param: `\(key)`")
					//self[key] = value
			}
		}

		for script in GlobalUserScripts { wvc.postinject(script) }
		if let url = url { wvc.gotoURL(url) } else { return nil }
		return wvc
	}

	lazy var webview: WKWebView = { return WebViewController.make_webview() }()

	//let backMenu = NSMenu()
	//let forwardMenu = NSMenu()
		
	dynamic unowned var favicon: NSImage = NSImage(named: NSImageNameApplicationIcon)! { // NSImageNameStatusNone
		didSet {
			if let name = favicon.name() { warn("= \(name)") }
			favicon.size = NSSize(width: 16, height: 16)
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

	var isTransparent: Bool = false {
		didSet {
			if let window = view.window {
				//window.disableFlushWindow()
				browser?.isTransparent = isTransparent
			}
			webview._drawsTransparentBackground = isTransparent
			//webview.layer?.backgroundColor = isTransparent ? NSColor.clearColor().CGColor : NSColor.whiteColor().CGColor
			//^ background-color:transparent sites immediately bleedthru to a black CALayer, which won't go clear until the content is reflowed or reloaded
			webview.setFrameSize(NSSize(width: webview.frame.size.width, height: webview.frame.size.height - 1)) //needed to fully redraw w/ dom-reflow or reload! 
			evalJS("window.dispatchEvent(new window.CustomEvent('MacPinTransparencyChanged',{'detail':{'isTransparent': \(isTransparent)}}));" +
				"document.head.appendChild(document.createElement('style')).remove();") //force redraw in case event didn't
				//"window.scrollTo();")
			webview.setFrameSize(NSSize(width: webview.frame.size.width, height: webview.frame.size.height + 1))
			//webview.window?.enableFlushWindow()
			webview.needsDisplay = true
			//webview.window?.flushWindowIfNeeded()
		}
	}

	var browser: BrowserViewController? { get {
		if let browser = presentingViewController as? BrowserViewController { return browser }
		if let browser = parentViewController as? BrowserViewController { return browser }
		return nil
	}}

	required init?(coder: NSCoder) { super.init(coder: coder) }
	override init!(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) { super.init(nibName:nil, bundle:nil) } //calls loadView
	override func loadView() { view = webview } // NIBless  

	convenience required init(config: WKWebViewConfiguration? = WKWebViewConfiguration()) {
		self.init(nibName: nil, bundle: nil)
		if let config = config { webview = WebViewController.make_webview(config) }
	}

	convenience init(agent: String? = nil, configuration: WKWebViewConfiguration? = nil) {
		self.init(config: configuration)
		if let agent = agent { if !agent.isEmpty { userAgent = agent } }
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		//view.wantsLayer = true //use CALayer to coalesce views
		//^ default=true:  https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/mac/WKView.mm#L3641
		view.autoresizingMask = .ViewWidthSizable | .ViewHeightSizable
		if let wkview = view.subviews.first as? WKView {
			//wkview.setValue(false, forKey: "shouldExpandToViewHeightForAutoLayout") //KVO
			//wkview.shouldExpandToViewHeightForAutoLayout = false
			//wkview.postsFrameChangedNotifications = false //FIXME stop webinspector flicker?
			//view.postsBoundsChangedNotifications = false //FIXME stop webinspector flicker?
		}

		//view.setContentHuggingPriority(NSLayoutPriorityDefaultLow, forOrientation:  NSLayoutConstraintOrientation.Vertical) // prevent autolayout-flapping when web inspector is docked to tab
		view.setContentHuggingPriority(250.0, forOrientation:  NSLayoutConstraintOrientation.Vertical) // prevent autolayout-flapping when web inspector is docked to tab

		webview._applicationNameForUserAgent = "Version/8.0.5 Safari/600.5.17"
		webview.allowsBackForwardNavigationGestures = true
		webview.allowsMagnification = true
#if SAFARIDBG
		webview._allowsRemoteInspection = true // start webinspectord child
		// enables Safari.app->Develop-><computer name> remote debugging of JSCore and all webviews' JS threads
		// http://stackoverflow.com/questions/11361822/debug-ios-67-mobile-safari-using-the-chrome-devtools
#endif
		//webview._editable = true // https://github.com/WebKit/webkit/tree/master/Tools/WebEditingTester
		bind(NSTitleBinding, toObject: webview, withKeyPath: "title", options: nil)
		webview.navigationDelegate = self // allows/denies navigation actions
		webview.UIDelegate = self //alert(), window.open()	
		//backMenu.delegate = self
		//forwardMenu.delegate = self
	}
	
	override func viewWillAppear() { // window popping up with this tab already selected & showing
		super.viewWillAppear() // or tab switching into view as current selection
		if let browser = browser { 
			browser.isTransparent = isTransparent
		 }
	}

	override func viewDidAppear() {
		super.viewDidAppear()
		//view.autoresizesSubviews = false
		//view.translatesAutoresizingMaskIntoConstraints = false
	}

	override func viewDidDisappear() {
		super.viewDidDisappear()
	}

	override func viewWillLayout() {
#if WK2LOG
		//warn("WKWebView \(view.frame)")
		//warn("WKWebView subviews #\(view.subviews.count)")
		//warn("WKWebView autoResizes subviews \(view.autoresizesSubviews)")i

		// https://github.com/WebKit/webkit/blob/aefe74816c3a4db1b389893469e2d9475bbc0fd9/Source/WebKit2/UIProcess/mac/WebInspectorProxyMac.mm#L809
		// inspectedViewFrameDidChange is looping itself
		// ignoreNextInspectedViewFrameDidChange is supposed to prevent this
		// fixed? https://bugs.webkit.org/show_bug.cgi?id=142892 https://github.com/WebKit/webkit/commit/eea322e40e200c93030702aa0a6524d249e9795f
		// moar feex http://trac.webkit.org/changeset/181927 http://trac.webkit.org/changeset/181972

		webview.resizeSubviewsWithOldSize(CGSizeZero)
		if let wkview = view.subviews.first as? NSView {
			if wkview.tag == 1000 { //WKInspectorViewTag
				// wkview.autoresizingMask == .ViewWidthSizable | .ViewMaxYMargin {
				warn("webinpector layout \(wkview.frame)") //probably a webinspector (WKWebInspectorWKWebView)
				if let pageView = view.subviews.last as? NSView { // tag=-1 should be the page content
					warn("page layout \(pageView.frame)")
					//pageView.autoresizingMask = .ViewWidthSizable
					//pageView.autoresizingMask = .ViewNotSizable
				}
			}
		}
#endif
		super.viewWillLayout()
	}

	override func updateViewConstraints() {
#if WK2LOG
		warn("\(view.frame)")
#endif
		//super.updateViewContraints()
		view.updateConstraints()
		//view.removeConstraints(view.constraints)
	}

	//override func removeFromParentViewController() { super.removeFromParentViewController() }

	deinit {
		warn("\(reflect(self).summary)")
		unbind(NSTitleBinding)
	}

}

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

extension WebViewController: WebViewScriptExports { // AppGUI / ScriptRuntime funcs
	override func cancelOperation(sender: AnyObject?) { webview.stopLoading(sender) } //make Esc key stop page load

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


	func conlog(msg: String) { // _ webview: WKWebView? = nil
		warn(msg)
#if APP2JSLOG
		evalJS("console.log(\'<\(__FILE__)> \(msg)\')")
#endif
	}

	func close() { removeFromParentViewController() }

	func grabWindow() -> NSWindow? {
		// make this take a closure instead?
		// and provide a window if one from the (non-existent?) parent isn't found?
		browser?.tabSelected = self
		if let window = view.window { return window }
		return nil
	}

	func print(sender: AnyObject?) { warn(""); webview.print(sender) }

	func zoomIn() { webview.magnification += 0.2 }
	func zoomOut() { webview.magnification -= 0.2 }
	func toggleTransparency() { isTransparent = !isTransparent }

	func highlightConstraints() { view.window?.visualizeConstraints(view.constraints) }

	func replaceContentView() { view.window?.contentView = view }

	func shareButtonClicked(sender: AnyObject?) {
		if let btn = sender as? NSView {
			if let url = webview.URL {
				var sharer = NSSharingServicePicker(items: [url] )
				sharer.delegate = self
				sharer.showRelativeToRect(btn.bounds, ofView: btn, preferredEdge: NSMinYEdge)
			}
		}
	}

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

	func gotoButtonClicked(sender: AnyObject?) {
		let urlbox = URLBoxController(webViewController: self)

		if let btn = sender as? NSButton {
			if let cell = btn.cell() as? NSCell {
				conlog("mouseDownFlags:\(cell.mouseDownFlags)")
			} 
		} 

		if let sender = sender as? NSView { //OpenTab toolbar button
			presentViewController(urlbox, asPopoverRelativeToRect: sender.bounds, ofView: sender, preferredEdge:NSMinYEdge, behavior: .Semitransient)
		} else { //keyboard shortcut
			//presentViewControllerAsSheet(urlbox) // modal, yuck
			var poprect = view.bounds
			poprect.size.height -= urlbox.preferredContentSize.height + 12 // make room at the top to stuff the popover
			presentViewController(urlbox, asPopoverRelativeToRect: poprect, ofView: view, preferredEdge: NSMaxYEdge, behavior: .Semitransient)
		}
	}

	func askToOpenURL(url: NSURL) {
		if let window = grabWindow() {
			if let opener = NSWorkspace.sharedWorkspace().URLForApplicationToOpenURL(url) {
				if opener == NSBundle.mainBundle().bundleURL {
					// macpin is already the registered handler for this (probably custom) url scheme, so just open it
					NSWorkspace.sharedWorkspace().openURL(url)
					return
				}
				conlog("[\(url)]")
				let alert = NSAlert()
				alert.messageText = "Open using App:\n\(opener)"
				alert.addButtonWithTitle("OK")
				alert.addButtonWithTitle("Cancel")
				alert.informativeText = url.description
				alert.icon = NSWorkspace.sharedWorkspace().iconForFile(opener.path!)
				alert.beginSheetModalForWindow(window, completionHandler:{(response:NSModalResponse) -> Void in
					if response == NSAlertFirstButtonReturn { NSWorkspace.sharedWorkspace().openURL(url) }
	 			})
				return
			}
			let error = NSError(domain: "MacPin", code: 2, userInfo: [
				NSURLErrorKey: url,
				NSLocalizedDescriptionKey: "No program present on this system is registered to open this non-browser URL.\n\n\(url)"
			])
			view.presentError(error, modalForWindow: window, delegate: nil, didPresentSelector: nil, contextInfo: nil)
		}
	}

	func scrapeIcon(webview: WKWebView) {
		// https://code.google.com/p/cocoalicious/source/browse/trunk/cocoalicious/Utilities/SFHFFaviconCache.m

		// check the cache first
		if let url = webview.URL {
			if let host = url.host {
				if let icon = NSImage(named: host) { 
					self.favicon = icon
					return
				}
			}
		}

		webview.evaluateJavaScript("if (icon = document.querySelector('link[rel$=icon]')) { icon.href };", completionHandler:{ [unowned self] (result: AnyObject!, exception: NSError!) -> Void in
			if let href = result as? String {
				if let url = NSURL(string: href) {
					if let icon = NSImage(contentsOfURL: url) {
						if let host = url.host { icon.setName(host) } // add cache name
						self.favicon = icon
					}
				}
			} else {
				// look for a root-domain-level icon file
				if let url = webview.URL {
					let iconurlp = NSURLComponents(URL: url, resolvingAgainstBaseURL: false)!
					iconurlp.path = "/favicon.ico"
					if let iconurl = iconurlp.URL, let host = iconurl.host {
						let request = NSURLRequest(URL: iconurl)
						NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue()) { [unowned self] (response, data, error) in
							if data != nil { 
								if let icon = NSImage(data: data) { 
									icon.setName(host) // add cache name - FIXME weakify host?
									self.favicon = icon
								}
							}
						}
					}
				}
			}
		})
	}

	func loadIcon(icon: String) -> Bool {
		if !icon.isEmpty { 
			favicon = NSImage(byReferencingURL: NSURL(string: icon)!)
			return true
		}
		return false
	}

	func preinject(script: String) { loadUserScriptFromBundle(script, webview.configuration.userContentController, .AtDocumentStart, onlyForTop: false) }
	func postinject(script: String) { loadUserScriptFromBundle(script, webview.configuration.userContentController, .AtDocumentEnd, onlyForTop: false) }
	func addHandler(handler: String) { webview.configuration.userContentController.addScriptMessageHandler(self, name: handler) }
	func subscribeTo(handler: String) { webview.configuration.userContentController.addScriptMessageHandler(self, name: handler) }

	func termiosREPL() {
		let backgroundQueue = dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0)
		dispatch_async(backgroundQueue, {
			let prompt = Prompt(argv0: Process.unsafeArgv[0])
			while (true) {
			    if let line = prompt.gets() {
					dispatch_async(dispatch_get_main_queue(), { () -> Void in
						self.webview.evaluateJavaScript(line, completionHandler:{ [unowned self] (result: AnyObject!, exception: NSError!) -> Void in
							// cross-locking main-UI thread and web-UI thread togeter, be speedy here!
							println(result)
							println(exception)
						})
					})
			    } else {
					dispatch_async(dispatch_get_main_queue(), { () -> Void in
						println("Got EOF from stdin, closing REPL!")
					})
					break
				}
			}
			NSApplication.sharedApplication().terminate(self)
		})
	}

}

extension WebViewController: NSSharingServicePickerDelegate { }
