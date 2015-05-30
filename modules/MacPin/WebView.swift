/// MacPin WKWebView subclass
///
/// Add some porcelain to WKWebViews


import WebKit
import WebKitPrivates
import JavaScriptCore

@objc protocol WebViewScriptExports: JSExport { // $.WebView & $.browser.tabs[WebView]
	init?(object: [String:AnyObject]) //> new WebView({url: 'http://example.com'});
	// can only JSExport one init*() func!
	// https://github.com/WebKit/webkit/blob/master/Source/JavaScriptCore/API/tests/testapi.mm
	// https://github.com/WebKit/webkit/blob/master/Source/JavaScriptCore/API/JSWrapperMap.mm#L412

	var title: String? { get }
	var url: String { get set }
	var transparent: Bool { get set }
	var userAgent: String { get set }
	//var canGoBack: Bool { get }
	//var canGoForward: Bool { get }
	//var hasOnlySecureContent: Bool { get }
	static var MatchedAddressOptions: [String:String] { get set }
	func close()
	func evalJS(js: String, _ withCallback: JSValue?)
	func asyncEvalJS(js: String, _ withDelay: Double, _ withCallback: JSValue?)
	func loadURL(urlstr: String) -> Bool
	func loadIcon(icon: String) -> Bool
	func preinject(script: String) -> Bool
	func postinject(script: String) -> Bool
	func addHandler(handler: String) // FIXME kill
	func subscribeTo(handler: String)
	//func goBack()
	//func goForward()
	//func reload()
	//func reloadFromOrigin()
	//func stopLoading() -> WKNavigation?
}

@objc class MPWebView: WKWebView, WebViewScriptExports {
	static var MatchedAddressOptions: [String:String] = [:] // cvar singleton

	var jsdelegate = AppScriptRuntime.shared.jsdelegate

	var url: String { // accessor for JSC, which doesn't support `new URL()`
		get { return URL?.absoluteString ?? "" }
		set { loadURL(newValue) }
	}

	var userAgent: String {
		get { return _customUserAgent ?? _userAgent ?? "" }
		// https://github.com/WebKit/webkit/blob/master/Source/WebCore/page/mac/UserAgentMac.mm#L48
		set(agent) { if !agent.isEmpty { _customUserAgent = agent } }
	}

#if os(OSX)
	var transparent: Bool {
		get { return _drawsTransparentBackground }
		set(transparent) {
			_drawsTransparentBackground = transparent
			//^ background-color:transparent sites immediately bleedthru to a black CALayer, which won't go clear until the content is reflowed or reloaded
 			// so frobble frame size to make content reflow & re-colorize
			setFrameSize(NSSize(width: frame.size.width, height: frame.size.height - 1)) //needed to fully redraw w/ dom-reflow or reload!
			evalJS("window.dispatchEvent(new window.CustomEvent('MacPinWebViewChanged',{'detail':{'transparent': \(transparent)}}));" +
				"document.head.appendChild(document.createElement('style')).remove();") //force redraw in case event didn't
				//"window.scrollTo();")
			setFrameSize(NSSize(width: frame.size.width, height: frame.size.height + 1))
			needsDisplay = true
		}
	}
#elseif os(iOS)
	// no overlaying MacPin apps upon other apps in iOS, so make it a no-op
	var transparent = false
#endif

	let favicon: FavIcon = FavIcon()

	convenience init(config: WKWebViewConfiguration? = nil, agent: String? = nil) {
		// init webview with custom config, needed for JS:window.open() which links new child Windows to parent Window
		let configuration = config ?? WKWebViewConfiguration()
		let prefs = WKPreferences() // http://trac.webkit.org/browser/trunk/Source/WebKit2/UIProcess/API/Cocoa/WKPreferences.mm
#if os(OSX)
		prefs.plugInsEnabled = true // NPAPI for Flash, Java, Hangouts
		prefs._developerExtrasEnabled = true // Enable "Inspect Element" in context menu
#endif
		//prefs._isStandalone = true // window.navigator.standalone = true to mimic MobileSafari's springboard-link shell mode
		//prefs.minimumFontSize = 14 //for blindies
		prefs.javaScriptCanOpenWindowsAutomatically = true;
#if WK2LOG
		//prefs._diagnosticLoggingEnabled = true // not in 10.10.3 yet
#endif
		configuration.preferences = prefs
		configuration.suppressesIncrementalRendering = false
		//configuration._websiteDataStore = _WKWebsiteDataStore.nonPersistentDataStore
		self.init(frame: CGRectZero, configuration: configuration)
#if SAFARIDBG
		_allowsRemoteInspection = true // start webinspectord child
		// enables Safari.app->Develop-><computer name> remote debugging of JSCore and all webviews' JS threads
		// http://stackoverflow.com/questions/11361822/debug-ios-67-mobile-safari-using-the-chrome-devtools
#endif
		//_editable = true // https://github.com/WebKit/webkit/tree/master/Tools/WebEditingTester

		allowsBackForwardNavigationGestures = true
#if os(OSX)
		allowsMagnification = true
		_applicationNameForUserAgent = "Version/8.0.5 Safari/600.5.17"
#elseif os(iOS)
		_applicationNameForUserAgent = "Version/8.0 Mobile/12F70 Safari/600.1.4"
#endif
		if let agent = agent { if !agent.isEmpty { _customUserAgent = agent } }
	}

	convenience required init?(object: [String:AnyObject]) {
		self.init(config: nil)
		var url = NSURL(string: "about:blank")
		for (key, value) in object {
			switch value {
				case let urlstr as String where key == "url": url = NSURL(string: urlstr)
				case let agent as String where key == "agent": _customUserAgent = agent
				case let icon as String where key == "icon": loadIcon(icon)
				case let transparent as Bool where key == "transparent":
#if os(OSX)
					_drawsTransparentBackground = transparent
#endif
				case let value as [String] where key == "preinject": for script in value { preinject(script) }
				case let value as [String] where key == "postinject": for script in value { postinject(script) }
				case let value as [String] where key == "handlers": for handler in value { addHandler(handler) } //FIXME kill
				case let value as [String] where key == "subscribeTo": for handler in value { subscribeTo(handler) }
				default: warn("unhandled param: `\(key): \(value)`")
			}
		}

		if let url = url { gotoURL(url) } else { return nil }
	}

	convenience required init(url: NSURL, agent: String? = nil) {
		self.init(config: nil, agent: agent)
		gotoURL(url)
	}

	override var description: String { return "\(reflect(self).summary) `\(title ?? String())` [\(URL ?? String())]" }
	deinit { warn(description) }

	func evalJS(js: String, _ withCallback: JSValue? = nil) {
		if let callback = withCallback where callback.isObject() { //is a function or a {}
			warn("callback: \(withCallback)")
			evaluateJavaScript(js, completionHandler:{ (result: AnyObject!, exception: NSError!) -> Void in
				// (result: WebKit::WebSerializedScriptValue*, exception: WebKit::CallbackBase::Error)
				//withCallback.callWithArguments([result, exception]) // crashes, need to translate exception into something javascripty
				warn("callback() ~> \(result),\(exception)")
				if result != nil {
					callback.callWithArguments([result, true]) // unowning withCallback causes a crash and weaking it muffs the call
				} else {
					// passing nil crashes
					callback.callWithArguments([JSValue(nullInContext: callback.context), true])
				}
				return
			})
			return
		}
		evaluateJavaScript(js, completionHandler: nil)
	}

	func asyncEvalJS(js: String, _ withDelay: Double, _ withCallback: JSValue? = nil) {
		let backgroundQueue = dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0)
		let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(Double(NSEC_PER_SEC) * withDelay))
		dispatch_after(delayTime, backgroundQueue) {
			if let callback = withCallback where callback.isObject() { //is a function or a {}
				warn("callback: \(withCallback)")
				self.evaluateJavaScript(js, completionHandler:{ (result: AnyObject!, exception: NSError!) -> Void in
					// (result: WebKit::WebSerializedScriptValue*, exception: WebKit::CallbackBase::Error)
					//withCallback.callWithArguments([result, exception]) // crashes, need to translate exception into something javascripty
					warn("callback() ~> \(result),\(exception)")
					if result != nil {
						callback.callWithArguments([result, true]) // unowning withCallback causes a crash and weaking it muffs the call
					} else {
						// passing nil crashes
						callback.callWithArguments([JSValue(nullInContext: callback.context), true])
					}
				})
			} else {
				self.evaluateJavaScript(js, completionHandler: nil)
			}
		}
	}

	func close() { removeFromSuperview() } // signal VC too?

	func gotoURL(url: NSURL) {
		if url.scheme == "file" {
			//webview.loadFileURL(url, allowingReadAccessToURL: url.URLByDeletingLastPathComponent!) //load file and allow link access to its parent dir
			//		waiting on http://trac.webkit.org/changeset/174029/trunk to land
			//webview._addOriginAccessWhitelistEntry(WithSourceOrigin:destinationProtocol:destinationHost:allowDestinationSubdomains:)
			// need to allow loads from file:// to inject NSBundle's CSS
		}
		loadRequest(NSURLRequest(URL: url))
	}

	func loadURL(urlstr: String) -> Bool {
		if let url = NSURL(string: urlstr) {
			gotoURL(url as NSURL)
			return true
		}
		return false // tell JS we were given a malformed URL
	}

	func scrapeIcon() { // extract icon location from current webpage and initiate retrieval
		evaluateJavaScript("if (icon = document.head.querySelector('link[rel$=icon]')) { icon.href };", completionHandler:{ [unowned self] (result: AnyObject!, exception: NSError!) -> Void in
			if let href = result as? String { // got link for icon or apple-touch-icon from DOM
				self.loadIcon(href)
			} else if let url = self.URL, iconurlp = NSURLComponents(URL: url, resolvingAgainstBaseURL: false) where !((iconurlp.host ?? "").isEmpty) {
				iconurlp.path = "/favicon.ico" // request a root-of-domain favicon
				self.loadIcon(iconurlp.string!)
			}
		})
	}

	func loadIcon(icon: String) -> Bool {
		if let url = NSURL(string: icon) where !icon.isEmpty {
			favicon.url = url
			return true
		}
		return false
	}

	func preinject(script: String) -> Bool { return loadUserScriptFromBundle(script, configuration.userContentController, .AtDocumentStart, onlyForTop: false) }
	func postinject(script: String) -> Bool { return loadUserScriptFromBundle(script, configuration.userContentController, .AtDocumentEnd, onlyForTop: false) }
	func addHandler(handler: String) { configuration.userContentController.addScriptMessageHandler(AppScriptRuntime.shared, name: handler) } //FIXME kill
	func subscribeTo(handler: String) { configuration.userContentController.addScriptMessageHandler(AppScriptRuntime.shared, name: handler) }

	func REPL() {
		termiosREPL({ (line: String) -> Void in
			self.evaluateJavaScript(line, completionHandler:{ [unowned self] (result: AnyObject!, exception: NSError!) -> Void in
				println(result)
				println(exception)
			})
		})
	}

#if os(OSX)

	func saveWebArchive() {
		_getWebArchiveDataWithCompletionHandler() { [unowned self] (data: NSData!, err: NSError!) -> Void in
			//pop open a save Panel to dump data into file
			let saveDialog = NSSavePanel();
			saveDialog.canCreateDirectories = true
			saveDialog.allowedFileTypes = [kUTTypeWebArchive]
			if let window = self.window {
				saveDialog.beginSheetModalForWindow(window) { (result: Int) -> Void in
					if let url = saveDialog.URL, path = url.path where result == NSFileHandlingPanelOKButton {
						NSFileManager.defaultManager().createFileAtPath(path, contents: data, attributes: nil)
						}
				}
			}
		}
	}

	override func validateUserInterfaceItem(anItem: NSValidatedUserInterfaceItem) -> Bool {
		switch (anItem.action().description) {
			//case "askToOpenCurrentURL": return true
			case "saveWebArchive": return true
			default:
				return super.validateUserInterfaceItem(anItem)
		}

	}

	override func beginDraggingSessionWithItems(items: [AnyObject], event: NSEvent, source: NSDraggingSource) -> NSDraggingSession {
		warn()
		return super.beginDraggingSessionWithItems(items, event: event, source: source)
		// allow controlling drags out of a MacPin window
		//  API didn't land in 10.10.3? https://bugs.webkit.org/show_bug.cgi?id=143618
		//  (-[WKWebView _setDragImage:at:linkDrag:]):
		//  (-[WKWebView draggingEntered:]):
		//  (-[WKWebView draggingUpdated:]):
		//  (-[WKWebView draggingExited:]):
		//  (-[WKWebView prepareForDragOperation:]):
		//  (-[WKWebView performDragOperation:]):
		// https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/DragandDrop/Concepts/dragsource.html#//apple_ref/doc/uid/20000976-CJBFBADF
		// https://developer.apple.com/library/mac/documentation/Cocoa/Reference/ApplicationKit/Classes/NSView_Class/index.html#//apple_ref/occ/instm/NSView/beginDraggingSessionWithItems:event:source:
	}

#endif
}