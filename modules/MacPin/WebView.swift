// MacPin WKWebView subclass
///
/// Add some porcelain to WKWebViews


import WebKit
import WebKitPrivates
import JavaScriptCore
import UTIKit

extension WKWebView {
	@objc(url) var urlstr: String {
		get { return url?.absoluteString ?? "" }
		set { /* not-impl*/  }
	}
}

enum WebViewInitProps: String, CustomStringConvertible, CaseIterable {
	var description: String { return "\(type(of: self)).\(self.rawValue)" }

	/* legacy MacPin event names */
	case url, agent, icon, // String
	transparent, isolated, privacy = "private", allowsMagnification, allowsRecording, // Bool
	preinject, postinject, style, subscribeTo, // [String]
	handlers // {} ~> [String: [JSValue]]
}

@objc protocol WebViewScriptExports: JSExport { // $.WebView & $.browser.tabs[WebView]
	init?(object: JSValue)
	// can only JSExport one init*() func!
	// https://github.com/WebKit/webkit/blob/master/Source/JavaScriptCore/API/tests/testapi.mm
	// https://github.com/WebKit/webkit/blob/master/Source/JavaScriptCore/API/JSWrapperMap.mm#L412

	var title: String? { get }
	@objc(url)var urlstr: String { get set }
	var description: String { get }
	func inspect() -> String
	// https://nodejs.org/api/util.html#util_custom_inspection_functions_on_objects

	var transparent: Bool { get set }
	var caching: Bool { get set }
	var userAgent: String { get set }
	var allowsMagnification: Bool { get set }
	var allowsRecording: Bool { get set }
	//var canGoBack: Bool { get }
	//var canGoForward: Bool { get }
	//var hasOnlySecureContent: Bool { get }
	// var userLabel // allow to be initiated with a trackable tag
	var injected: [String] { get }
	var styles: [String] { get }
	static var MatchedAddressOptions: [String:String] { get set }

	// methods are exported as non-enumerable (but configurable) JS props by JSC
	//   https://github.com/WebKit/webkit/blob/master/Source/JavaScriptCore/API/JSWrapperMap.mm#L258
	@objc(evalJS::) func evalJS(_ js: String, callback: JSValue?)
	@objc(asyncEvalJS:::) func asyncEvalJS(_ js: String, delay: Int, callback: JSValue?)
	func loadURL(_ urlstr: String) -> Bool
	func loadIcon(_ icon: String) -> Bool
	func popStyle(_ idx: Int)
	func style(_ css: String) -> Bool
	func mainStyle(_ css: String) -> Bool
	func preinject(_ script: String) -> Bool
	func postinject(_ script: String) -> Bool
	func addHandler(_ handler: String) // FIXME kill
	func subscribeTo(_ handler: String)
	func console()
	func scrapeIcon()
	var thumbnail: _WKThumbnailView? { get }
	//func goBack()
	//func goForward()
	//func reload()
	//func reloadFromOrigin()
	//func stopLoading() -> WKNavigation?
	//var snapshotURL: String { get } // gets a data:// of the WKThumbnailView
}


struct IconCallbacks {

	static let decidePolicyForGeolocationPermissionRequestCallBack: WKPageDecidePolicyForGeolocationPermissionRequestCallback = { page, frame, origin, permissionRequest, clientInfo in
		// FIXME: prompt?
		warn()
		WKGeolocationPermissionRequestAllow(permissionRequest)
	}
	static let decidePolicyForNotificationPermissionRequest: WKPageDecidePolicyForNotificationPermissionRequestCallback = { page, securityOrigin, permissionRequest, clientInfo in
		warn()
		WKNotificationPermissionRequestAllow(permissionRequest)
		//WKNotificationPermissionRequestDeny(permissionRequest)
	}

}

@objc class MPWebView: WKWebView, WebViewScriptExports {

	//@objc dynamic var isLoading: Bool
	//@objc dynamic var estimatedProgress: Double

	static var MatchedAddressOptions: [String:String] = [:] // cvar singleton

	static func WebProcessConfiguration() -> _WKProcessPoolConfiguration {
		let config = _WKProcessPoolConfiguration()
		//config.injectedBundleURL = NSbundle.mainBundle().URLForAuxillaryExecutable("contentfilter.wkbundle")
		// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/WebProcess/InjectedBundle/API/c/WKBundle.cpp

		// https://github.com/WebKit/webkit/commit/9d4359a1f767846db078e6ba669715d5ec4a7ba9
		// config.trackNetworkActivity = true

		return config
	}
	static var sharedWebProcessPool = WKProcessPool()._init(with: MPWebView.WebProcessConfiguration()) // cvar singleton

	var injected: [String] = [] //list of script-names already loaded
	var styles: [String] = [] //list of css-names already loaded
	// cachedUserScripts: [UserScript] // are pushed/popped from the contentController by navigation delegates depending on URL being visited

	//let jsdelegate = AppScriptRuntime.shared.jsdelegate
	// race condition? seems to hit a phantom JSContext/JSValue that doesn't represent the delegate!?
	var jsdelegate: JSValue { get { return AppScriptRuntime.shared.jsdelegate } }

	override var urlstr: String { // accessor for JSC, which doesn't support `new URL()`
		get { return url?.absoluteString ?? "" }
		set { loadURL(newValue) }
	}

	var userAgent: String {
		get { return _customUserAgent ?? _userAgent ?? "" }
		// https://github.com/WebKit/webkit/blob/master/Source/WebCore/page/mac/UserAgentMac.mm#L48
		set(agent) { if !agent.isEmpty { _customUserAgent = agent } }
	}

	//let page = self.browsingContextController()._pageRef // https://github.com/WebKit/webkit/blob/e41847fbe7dd0bf191a8dafc2c3a5d965e96d277/Source/WebKit2/UIProcess/Cocoa/WebViewImpl.h#L368
	//let browsingContext = WKWebProcessPlugInBrowserContextController.lookUpBrowsingContextFromHandle(_handle)
	//let page = browsingContext._pageRef
	//let browsingContextController = WKBrowsingContextController._browsingContextControllerForPageRef(_pageForTesting())
		// register a custom protocol to handle X-Host: https://github.com/WebKit/webkit/blob/fa0c14782ed939dabdb52f7cffcb1fd0254d4ef0/Tools/TestWebKitAPI/cocoa/TestProtocol.mm
		// https://github.com/WebKit/webkit/blob/49cc03e4bf77a42908478cfbda938088cf1a8567/Source/WebKit2/NetworkProcess/CustomProtocols/CustomProtocolManager.h
		//   registerProtocolClass(NSURLSessionConfiguration) <- that could let you configure ad-hoc CFProxySupport dictionaries: http://stackoverflow.com/a/28101583/3878712
		// NSURLSessionConfiguration ? https://www.objc.io/issues/5-ios7/from-nsurlconnection-to-nsurlsession/

	var context: WKContextRef { get { return WKPageGetContext(_pageRefForTransitionToWKWebView) } }

#if STP
	// a long lived thumbnail viewer should construct and store thumbviews itself, this is for convenient dumping
	var thumbnail: _WKThumbnailView? {
		get {
			let snap = self._thumbnailView ?? _WKThumbnailView(frame: self.frame, from: self)
			snap?.requestSnapshot()
			return snap
		}
	}
#endif

#if os(OSX)

#if !STP // no inner WKView in STP, iOS10, & Sierra: https://bugs.webkit.org/show_bug.cgi?id=150174#c0
	// https://github.com/WebKit/webkit/blob/8c504b60d07b2a5c5f7c32b51730d3f6f6daa540/Source/WebKit2/UIProcess/mac/WebInspectorProxyMac.mm#L679
	override var _inspectorAttachmentView: NSView? {
		// when inspector is open, subviews.first is actually the inspector (WKWebInspectorWKWebView), not the WKView
		// tabitem.view.subviews = [ WKWebInspectorView, WKView, ... ]
		get {
			if let topFrame = subviews.first as? WKView {
				return topFrame._inspectorAttachmentView
			}
			return nil
		}
		set {
			if let topFrame = subviews.first as? WKView {
				topFrame._inspectorAttachmentView = newValue
			}
		}
	}
#endif

	var caching: Bool {
		get { return !WKPageGetResourceCachingDisabled(_pageRefForTransitionToWKWebView) }
		set { WKPageSetResourceCachingDisabled(_pageRefForTransitionToWKWebView, !newValue) }
	}

	var transparent: Bool {
		get {
#if STP
			return !_drawsBackground
#else
			return _drawsTransparentBackground
#endif
		}
		set(transparent) {
#if STP
			_drawsBackground = !transparent
#else
			_drawsTransparentBackground = transparent
#endif
			AppScriptRuntime.shared.emit(.tabTransparencyToggled, transparent as AnyObject, self)
			evalJS("window.dispatchEvent(new window.CustomEvent('MacPinWebViewChanged',{'detail':{'transparent': \(transparent)}}));")
			needsDisplay = true
			WKPageForceRepaint(_pageRefForTransitionToWKWebView, nil, {error, void in warn()} as WKPageForceRepaintFunction )
			//^ background-color:transparent sites immediately bleedthru to a black CALayer, which won't go clear until the content is reflowed or reloaded
		}
	}

#elseif os(iOS)
	var transparent = false // no overlaying MacPin apps upon other apps in iOS, so make it a no-op
	var allowsMagnification = true // not exposed on iOS WebKit, make it no-op
#endif
	var allowsRecording: Bool {
		get { return _mediaCaptureEnabled }
		set (recordable) { _mediaCaptureEnabled = recordable }
	}

	let favicon: FavIcon = FavIcon()

	convenience init(config: WKWebViewConfiguration? = nil, agent: String? = nil, isolated: Bool? = false, privacy: Bool? = false) {
		// init webview with custom config, needed for JS:window.open() which links new child Windows to parent Window
		let configuration = config ?? WKWebViewConfiguration()
		if config == nil {
#if STP
			configuration._allowUniversalAccessFromFileURLs = true
#if os(OSX)
			configuration._showsURLsInToolTips = true
			configuration._serviceControlsEnabled = true
			configuration._imageControlsEnabled = true
			//configuration._requiresUserActionForEditingControlsManager = true
#endif
#endif
			if #available(OSX 10.13, iOS 11, *) {
				// https://forums.developer.apple.com/thread/87474#267547
				configuration.setURLSchemeHandler(MPRetriever(), forURLScheme: "x-macpin")
				// has to be set before self.init
			}
		}
		let prefs = WKPreferences() // http://trac.webkit.org/browser/trunk/Source/WebKit2/UIProcess/API/Cocoa/WKPreferences.mm
#if os(OSX)
		prefs.plugInsEnabled = true // NPAPI for Flash, Java, Hangouts
		prefs._developerExtrasEnabled = true // Enable "Inspect Element" in context menu
		prefs._fullScreenEnabled = true

		// https://webkit.org/blog/7763/a-closer-look-into-webrtc/
		if #available(OSX 10.13, iOS 11, *) {
			prefs._mediaCaptureRequiresSecureConnection = false
			prefs._mediaDevicesEnabled = true
			prefs._mockCaptureDevicesEnabled = false
		}
#endif
		if let privacy = privacy, privacy {
			//prevent HTML5 application cache and asset/page caching by WebKit, MacPin never saves any history itself
			prefs._storageBlockingPolicy = .blockAll
		}
		prefs._allowFileAccessFromFileURLs = true // file://s can xHr other file://s
		//prefs._allowUniversalAccessFromFileURLs = true
		//prefs._isStandalone = true // `window.navigator.standalone == true` mimicing MobileSafari's springboard-link shell mode
		//prefs.minimumFontSize = 14 //for blindies
		prefs.javaScriptCanOpenWindowsAutomatically = true;
#if WK2LOG
		prefs._diagnosticLoggingEnabled = true
		prefs._logsPageMessagesToSystemConsoleEnabled = true // dumps to ASL
		//prefs._javaScriptRuntimeFlags = 0 // ??
#endif
		//prefs._loadsImagesAutomatically = true // STP v20: https://github.com/WebKit/webkit/commit/326fc529da43b4a028a3a1644edb2198d23ecb68
		configuration.preferences = prefs
		configuration.suppressesIncrementalRendering = false
		if let privacy = privacy, privacy {
			if #available(OSX 10.11, iOS 9, *) {
				configuration.websiteDataStore = WKWebsiteDataStore.nonPersistent()
			}
		}
		if let isolated = isolated, isolated {
			configuration.processPool = WKProcessPool() // not "private" but usually gets new session variables from server-side webapps
		} else {
			configuration.processPool = config?.processPool ?? (MPWebView.self.sharedWebProcessPool)!
		}

		self.init(frame: CGRect.zero, configuration: configuration)
#if SAFARIDBG
		_allowsRemoteInspection = true // start webinspectord child
		// enables Safari.app->Develop-><computer name> remote debugging of JSCore and all webviews' JS threads
		// http://stackoverflow.com/questions/11361822/debug-ios-67-mobile-safari-using-the-chrome-devtools
#endif
		//_editable = true // https://github.com/WebKit/webkit/tree/master/Tools/WebEditingTester
		// 	add a toggle: https://github.com/WebKit/webkit/commit/d3a81d4cdbdf947d484987578b21fc0d1f42be5e

		allowsBackForwardNavigationGestures = true
		allowsLinkPreview = true // enable Force Touch peeking (when not captured by JS/DOM)
#if os(OSX)
		allowsMagnification = true
		//_mediaCaptureEnabled = false
#if STP
		_applicationNameForUserAgent = "Version/11.1 Safari/605.1.33"
#else
		_applicationNameForUserAgent = "Version/10.0 Safari/603.5.17"
#endif
		"http".withCString { http in
			WKContextRegisterURLSchemeAsBypassingContentSecurityPolicy(context, WKStringCreateWithUTF8CString(http)) // FIXME: makeInsecure() toggle!
		}
		"https".withCString { https in
			WKContextRegisterURLSchemeAsBypassingContentSecurityPolicy(context, WKStringCreateWithUTF8CString(https))
		}

		var uiClient = WKPageUIClientV2()
		uiClient.base.version = 2
		uiClient.decidePolicyForGeolocationPermissionRequest = IconCallbacks.decidePolicyForGeolocationPermissionRequestCallBack
		uiClient.decidePolicyForNotificationPermissionRequest = IconCallbacks.decidePolicyForNotificationPermissionRequest
		//uiClient.showPage: WKPageUIClientCallback!
		//uiClient.close: WKPageUIClientCallback!
		//uiClient.takeFocus: WKPageTakeFocusCallback!
		//uiClient.focus: WKPageFocusCallback!
		//uiClient.unfocus: WKPageUnfocusCallback!

		// https://developer.mozilla.org/en-US/docs/Web/API/Window/status
		// https://developer.mozilla.org/en-US/docs/Web/API/Window/statusbar
		//uiClient.setStatusText: WKPageSetStatusTextCallback!
		//statusBarIsVisible: WKPageGetStatusBarIsVisibleCallback!
		//setStatusBarIsVisible: WKPageSetStatusBarIsVisibleCallback!
		WKPageSetPageUIClient(_pageRefForTransitionToWKWebView, &uiClient.base)

#elseif os(iOS)
		_applicationNameForUserAgent = "Version/8.0 Mobile/12F70 Safari/600.1.4"
#endif
		if let agent = agent { if !agent.isEmpty { _customUserAgent = agent } }
	}

	/*
	 func reloadPlugins() {
		WKContextRefreshPlugIns(self.context) // STP v20: https://github.com/WebKit/webkit/commit/334a90ae91c0358385c2a971ac8ee7a5b1577fa6
	}
	*/

	convenience required init?(object: JSValue) {
		// consuming JSValue so we can perform custom/recursive conversion instead of JSExport's stock WrapperMap
		// https://stackoverflow.com/a/36120929/3878712
		//guard let object = jsobject else { warn("no config object given!"); return nil} // JS can dump a nil on us

		if object.isString { // new WebView("http://webkit.org");
			if let urlstr = object.toString(), let url = URL(string: urlstr) {
				self.init(url: url)
			} else {
				self.init(url: URL(string: "about:blank")!)
			}
		} else if object.isObject { // new WebView({url: "http://webkit.org", transparent: true, ... });
			var props: [WebViewInitProps: Any] = [:]

			for prop in WebViewInitProps.allCases {
				if object.hasProperty(prop.rawValue) {
					guard let jsval = object.forProperty(prop.rawValue) else { warn("no value for \(prop)!"); continue }
					switch prop {
						case .url, .agent, .icon where jsval.isString:
							props[prop] = jsval.toString()
						case .transparent, .isolated, .privacy, .allowsMagnification, .allowsRecording where jsval.isBoolean:
							props[prop] = jsval.toBool()
						case .preinject, .postinject, .style, .subscribeTo where jsval.isArray:
							props[prop] = jsval.toArray().flatMap { $0 as? String }
						case .handlers where jsval.isObject:
							var handlers: [String: [JSValue]] = [:]
							let handlerNames = jsval.toDictionary().keys.flatMap({$0 as? String})
							warn(handlerNames.description)
							for name in handlerNames {
								guard let hval = jsval.objectForKeyedSubscript(name) else { warn("no handler for \(name)!"); continue }
								if hval.isArray { // array of handler funcs (hopefully) was passed
									guard let hval = hval.invokeMethod("slice", withArguments: [0]) else { continue }// dup the array so pop() won't mutate the original
									// for handler in hval.toArray() { // -> Any .. not useful
									guard let numHandlers = hval.forProperty("length").toNumber() as? Int, numHandlers > 0 else { continue }
									for num in 1...numHandlers { // C-Loop ftw
										//guard let handler = hvals.atIndex(num) else { warn("cannot acquire \(num)th JSValue for \(name)"); continue }
										//guard let handler = hval.objectAtIndexedSubscript(num) else { warn("cannot acquire \(num)th JSValue for \(name)"); continue }
										// JSC BUG: dict-of-array contained functions are `undefined` when pulled with atIndex/objAtIndexSub
										guard let handler = hval.invokeMethod("pop", withArguments: []) else { warn("cannot acquire \(num)th JSValue for \(name)"); continue }

										if !handler.isNull && !handler.isUndefined && handler.hasProperty("call") {
											handlers[name, default: []].append(handler)
										}
									}
								} else if !hval.isNull && !hval.isUndefined && hval.hasProperty("call") { // a single handler func was passed
									handlers[name, default: []].append(hval)
								}
							}
							props[prop] = handlers
						default:
							warn("unhandled init prop: \(prop.rawValue)")
					}
				}
			}

			self.init(props: props)
		} else { // isUndefined, isNull
			// returning nil will actually SIGSEGV
			//warn(obj: object)
			self.init(url: URL(string: "about:blank")!)
		}
	}

	convenience required init?(object: [String:AnyObject]?) {
		guard let object = object else { warn("no config object given!"); return nil} // JS can dump a nil on us
		// this is just for addShortcut() & gotoShortcut(), I think ...
		var props: [WebViewInitProps: Any] = [:]
		for (key, value) in object {
			// convert all stringish keys for enum conformance
			guard let prop = WebViewInitProps(rawValue: key) else { warn(key); continue }
			props[prop] = value
		}
		self.init(props: props)
	}

	convenience required init?(props: [WebViewInitProps: Any]) {
		// check for isolated pre-init
		if let isolated = props[.isolated] as? Bool {
			self.init(config: nil, isolated: isolated)
		} else if let privacy = props[.privacy] as? Bool {
			// a private tab would imply isolation, not sweating lack of isolated+private corner case
			self.init(config: nil, privacy: privacy)
		} else {
			self.init(config: nil)
		}
		var url = NSURL(string: "about:blank")
		for (key, value) in props {
			switch value {
				case let urlstr as String where key == .url: url = NSURL(string: urlstr)
				case let agent as String where key == .agent: _customUserAgent = agent
				case let icon as String where key == .icon: loadIcon(icon)
				case let magnification as Bool where key == .allowsMagnification: allowsMagnification = magnification
				case let recordable as Bool where key == .allowsRecording: _mediaCaptureEnabled = recordable
				case let transparent as Bool where key == .transparent:
#if os(OSX)
#if STP
					_drawsBackground = !transparent
#else
					_drawsTransparentBackground = transparent
#endif
#endif
				case let value as [String] where key == .preinject: for script in value { preinject(script) }
				case let value as [String] where key == .postinject: for script in value { postinject(script) }
				case let value as [String] where key == .style: for css in value { style(css) }
				case let value as [String] where key == .handlers: for handler in value { addHandler(handler) } //FIXME kill delegate.`handlerStr` indirect-str-refs
				case let value as [String: [JSValue]] where key == .handlers: addHandlers(value)
				case let value as [String] where key == .subscribeTo: for handler in value { subscribeTo(handler) }
				default: warn("unhandled param: `<\(type(of: key))>\(key): <\(type(of: value))>\(value)`")
			}
		}

		if let url = url { gotoURL(url) } else { return nil }
	}

	convenience required init(url: NSURL, agent: String? = nil, isolated: Bool? = false, privacy: Bool? = false) {
		self.init(url: url as URL, agent: agent, isolated: isolated, privacy: privacy)
	}

	convenience required init(url: URL, agent: String? = nil, isolated: Bool? = false, privacy: Bool? = false) {
		self.init(config: nil, agent: agent, isolated: isolated, privacy: privacy)
		gotoURL(url)
	}

	//convenience required init(){ warn("no props init!"); self.init() }

	override var description: String { return "<\(type(of: self))> `\(title ?? String())` [\(urlstr)]" }
	func inspect() -> String { return "`\(title ?? String())` [\(urlstr)]" }

	deinit {
		warn(description)
	}

	func flushProcessPool() {
		// reinit the NetworkProcess to change HTTP(s) proxies or write cookies to disk
		UserDefaults.standard.synchronize()
		if configuration.processPool == MPWebView.self.sharedWebProcessPool {
			// replace the global pool if that's what we were using
			MPWebView.self.sharedWebProcessPool = WKProcessPool()._init(with: MPWebView.WebProcessConfiguration())
			configuration.processPool = MPWebView.self.sharedWebProcessPool!
		} else { // regenerate a personal pool
			configuration.processPool = WKProcessPool()
		}
	}

	@objc(evalJS::) func evalJS(_ js: String, callback: JSValue? = nil) {
		if let callback = callback, callback.isObject { //is a function or a {}
			warn("callback: \(callback)")
			evaluateJavaScript(js, completionHandler:{ (result: Any?, exception: Error?) -> Void in
				// (result: WebKit::WebSerializedScriptValue*, exception: WebKit::CallbackBase::Error)
				//withCallback.callWithArguments([result, exception]) // crashes, need to translate exception into something javascripty
				warn("callback() ~> \(result),\(exception)")
				// FIXME: check if exception is WKErrorCode.JavaScriptExceptionOccurred,.JavaScriptResultTypeIsUnsupported
				if let result = result {
					callback.call(withArguments: [result, true]) // unowning withCallback causes a crash and weaking it muffs the call
				} else {
					// passing nil crashes
					callback.call(withArguments: [JSValue(nullIn: callback.context), true])
				}
				return
			})
			return
		}
		evaluateJavaScript(js, completionHandler: nil)
	}

	// cuz JSC doesn't come with setTimeout()
	@objc(asyncEvalJS:::) func asyncEvalJS(_ js: String, delay: Int, callback: JSValue?) {
		let delayTime = DispatchTime.now() + DispatchTimeInterval.seconds(delay)
		DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: delayTime) {
			if let callback = callback, callback.isObject { //is a function or a {}
				warn("callback: \(callback)")
				self.evaluateJavaScript(js, completionHandler:{ (result: Any?, exception: Error?) -> Void in
					// (result: WebKit::WebSerializedScriptValue*, exception: WebKit::CallbackBase::Error)
					//withCallback.callWithArguments([result, exception]) // crashes, need to translate exception into something javascripty
					warn("callback() ~> \(result),\(exception)")
					if let result = result {
						callback.call(withArguments: [result, true]) // unowning withCallback causes a crash and weaking it muffs the call
					} else {
						// passing nil crashes
						callback.call(withArguments: [JSValue(nullIn: callback.context), true])
					}
				})
			} else {
				self.evaluateJavaScript(js, completionHandler: nil)
			}
		}
	}

	func gotoURL(_ url: NSURL) { gotoURL(url as URL) }
	func gotoURL(_ url: URL) {
		let act = ProcessInfo.processInfo.beginActivity(options: [ProcessInfo.ActivityOptions.userInitiated, ProcessInfo.ActivityOptions.idleSystemSleepDisabled], reason: "browsing begun")
		if url.scheme == "file", #available(OSX 10.11, iOS 9.1, *) {
			let readURL = url.deletingLastPathComponent()
			warn("Bypassing CORS: \(readURL)")
			loadFileURL(url as URL, allowingReadAccessTo: readURL)
		} else {
			load(URLRequest(url: url))
		}
		ProcessInfo.processInfo.endActivity(act)
	}

	@discardableResult
	func loadURL(_ urlstr: String) -> Bool {
		if let url = URL(string: urlstr) {
			gotoURL(url)
			return true
		}
		warn("ILLEGAL URL! \(url)") // getting SIGILLd by incomplete URLs:
		// $.browser.tabs[0].loadURL("www.example.com")
		return false // tell JS we were given a malformed URL
	}

	func scrapeIcon() { // extract icon location from current webpage and initiate retrieval
			evaluateJavaScript("if (icon = document.head.querySelector('link[rel$=icon]')) { icon.href };", completionHandler:{ [unowned self] (result: Any?, exception: Error?) -> Void in
				if let href = result as? String { // got link for icon or apple-touch-icon from DOM
					// FIXME: very rarely this crashes if a page closes/reloads itself during the update closure
					self.loadIcon(href)
				} else if let url = self.url, let iconurlp = NSURLComponents(url: url, resolvingAgainstBaseURL: false), !((iconurlp.host ?? "").isEmpty) {
					iconurlp.path = "/favicon.ico" // request a root-of-domain favicon
					self.loadIcon(iconurlp.string!)
				}
			})
	}

	@discardableResult
	func loadIcon(_ icon: String) -> Bool {
		if let url = NSURL(string: icon), !icon.isEmpty {
			favicon.url = url
			return true
		}
		return false
	}

/*
	func addUserScript(name: String) -> UserScript? {
		let script = UserScript.load(basename: name, inject: .AtDocumentStart, onlyForTop: false)
		let webctl = configuration.userContentController
		guard webctl.userScripts.filter({$0 == script}).count < 1 else { warn("\(script) already loaded!"); return nil }
		//if (find(webctl.userScripts, script) ?? -1) < 0 { // don't re-add identical userscripts
		webctl.addUserScript(script)
		return script
	}
*/

	func popStyle(_ idx: Int) {
		guard idx >= 0 && idx <= configuration.userContentController._userStyleSheets.count else { return }
		let style = configuration.userContentController._userStyleSheets[idx]
		configuration.userContentController._remove(style)
		styles.remove(at: idx)
	}

	@discardableResult
	func style(_ css: String) -> Bool {
		if !styles.contains(css) && loadUserStyleSheetFromBundle(css, webctl: configuration.userContentController, onlyForTop: false) { styles.append(css); return true }
		return false
	}

	@discardableResult
	func mainStyle(_ css: String) -> Bool {
		if !styles.contains(css) && loadUserStyleSheetFromBundle(css, webctl: configuration.userContentController, onlyForTop: true) { styles.append(css); return true }
		return false
	}

	@discardableResult
	func preinject(_ script: String) -> Bool {
		if !injected.contains(script) && loadUserScriptFromBundle(script, webctl: configuration.userContentController, inject: .atDocumentStart, onlyForTop: false) { injected.append(script); return true }
		return false
	}

	@discardableResult
	func postinject(_ script: String) -> Bool {
		if !injected.contains(script) && loadUserScriptFromBundle(script, webctl: configuration.userContentController, inject: .atDocumentEnd, onlyForTop: false) { injected.append(script); return true }
		return false
		// forcefully install a userscript fror post-page-loads
		//guard unless !injected.contains(script) else {return false}
		//guard let script = loadUserScript(script, inject: .AtDocumentEnd, onlyForTop: false) else { return false }
		//addUserScript(script)
		//injected.append(script)
		//return true
	}

	func addHandler(_ handler: String) { configuration.userContentController.add(AppScriptRuntime.shared, name: handler) } //FIXME kill

	func addHandlers(_ handlerMap: [String: [JSValue]]) {
		for (eventName, handlers) in handlerMap {
			//warn("\(eventName) => \(type(of: handlers))\(handlers)")
			var cbs = AppScriptRuntime.shared.messageHandlers[eventName, default: []]

			for hd in handlers {
				if !hd.isNull && !hd.isUndefined && !cbs.contains(hd) && hd.hasProperty("call") {
					warn("\(eventName) += \(type(of: hd)) \(hd)")
					cbs.append(hd)
				} else { warn("handler for \(eventName) not a callable! <= \(hd)") }
			}

			guard !cbs.isEmpty else { continue }
			AppScriptRuntime.shared.messageHandlers[eventName] = cbs
			// BUG? cross-tab event broadcasting done thru .shared[eventName] ...
			configuration.userContentController.add(AppScriptRuntime.shared, name: eventName)
		}
	}

	func subscribeTo(_ handler: String) {
		configuration.userContentController.removeScriptMessageHandler(forName: handler)
		configuration.userContentController.add(AppScriptRuntime.shared, name: handler)
	}

	func REPL() {
		termiosREPL({ (line: String) -> Void in
			self.evaluateJavaScript(line, completionHandler:{ (result: Any?, exception: Error?) -> Void in
				// FIXME: the JS execs async so these print()s don't consistently precede the REPL thread's prompt line
				if let result = result { Swift.print(result) }
				guard let exception = exception else { return }
				switch (exception._domain, exception._code) { // codes: https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/Cocoa/WKError.h
					// case(WKErrorDomain, Int(WKErrorCode.JavaScriptExceptionOccurred.rawValue)): fallthrough
					// case(WKErrorDomain, Int(WKErrorCode.JavaScriptResultTypeIsUnsupported.rawValue)): fallthrough
						// info keys: https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/Cocoa/WKErrorPrivate.h
						// _WKJavaScriptExceptionMessageErrorKey
						// _WKJavaScriptExceptionLineNumberErrorKey
						// _WKJavaScriptExceptionColumnNumberErrorKey
						// _WKJavaScriptExceptionSourceURLErrorKey
					default: Swift.print("Error: \(exception)")
				}
			})
		},
		ps1: #file,
		ps2: #function,
		abort: { () -> Void in
			// EOF'd by Ctrl-D
			// self.close() // FIXME: self is still retained (by the browser?)
		})
	}

	//webview._getMainResourceDataWithCompletionHandler() { (data: Data?, err: Error?) -> Void in }
	//webview._getContentsAsStringWithCompletionHandler() { (str: String?, err: Error?) -> Void in }
	//webview._getApplicationManifestWithCompletionHandler() { (manifest: _WKApplicationManifest?) -> Void in }

#if os(OSX)
	@objc func reloadWithoutContentBlockers() {
		WKPageReloadWithoutContentBlockers(_pageRefForTransitionToWKWebView)
	}

	// FIXME: unified save*()s like Safari does with a drop-down for "Page Source" & Web Archive, or auto-mime for single non-HTML asset
	@objc func saveWebArchive() {
		_getWebArchiveData() { [unowned self] (data: Data?, err: Error?) -> Void in
			//pop open a save Panel to dump data into file
			let saveDialog = NSSavePanel();
			saveDialog.canCreateDirectories = true
			saveDialog.allowedFileTypes = [kUTTypeWebArchive as String]
			if let window = self.window {
				saveDialog.beginSheetModal(for: window) { (result: NSApplication.ModalResponse) -> Void in
					if let url = saveDialog.url, result == .OK {
						FileManager.default.createFile(atPath: url.path, contents: data, attributes: nil)
						}
				}
			}
		}
	}

	@objc func savePage() {
		_getMainResourceData() { [unowned self] (data: Data?, err: Error?) -> Void in
			//pop open a save Panel to dump data into file
			let saveDialog = NSSavePanel();
			saveDialog.canCreateDirectories = true
			if let mime = self._MIMEType, let uti = UTI(mimeType: mime) {
				saveDialog.allowedFileTypes = [uti.utiString]
			}
			if let window = self.window {
				saveDialog.beginSheetModal(for: window) { (result: NSApplication.ModalResponse) -> Void in
					if let url = saveDialog.url, result == .OK {
						FileManager.default.createFile(atPath: url.path, contents: data, attributes: nil)
						}
				}
			}
		}
	}

	override func validateUserInterfaceItem(_ anItem: NSValidatedUserInterfaceItem) -> Bool {
		switch (anItem.action!.description) {
			//case "askToOpenCurrentURL": return true
			case "copyAsPDF": fallthrough
			case "console": fallthrough
			case "saveWebArchive": fallthrough
			case "close": fallthrough
			case "savePage": return true
			case "printWebView:": return true
			default:
				warn("not capturing selector but passing to super: \(anItem.action)")
				return super.validateUserInterfaceItem(anItem)
		}

	}

	/* overide func _registerForDraggedTypes() {
		// https://github.com/WebKit/webkit/blob/f72e25e3ba9d3d25d1c3a4276e8dffffa4fec4ae/Source/WebKit2/UIProcess/API/mac/WKView.mm#L3653
		self.registerForDraggedTypes([ // https://github.com/WebKit/webkit/blob/master/Source/WebKit2/Shared/mac/PasteboardTypes.mm [types]
			// < forEditing
			WebArchivePboardType, NSHTMLPboardType, NSFilenamesPboardType, NSTIFFPboardType, NSPDFPboardType,
		    NSURLPboardType, NSRTFDPboardType, NSRTFPboardType, NSStringPboardType, NSColorPboardType, kUTTypePNG,
			// < forURL
			WebURLsWithTitlesPboardType, //webkit proprietary
			NSURLPboardType, // single url from older apps and Chromium -> text/uri-list
			WebURLPboardType (kUTTypeURL), //webkit proprietary: public.url
			WebURLNamePboardType (kUTTypeURLName), //webkit proprietary: public.url-name
			NSStringPboardType, // public.utf8-plain-text -> WKJS: text/plain
			NSFilenamesPboardType, // Finder -> text/uri-list & Files
		])
	} */

	// TODO: give some feedback when a url is being dragged in to indicate what will happen
	//  (-[WKWebView draggingEntered:]):
	//  (-[WKWebView draggingUpdated:]):
	//  (-[WKWebView draggingExited:]):
	//  (-[WKWebView prepareForDragOperation:]):

	// try to accept DnD'd links from other browsers more gracefully than default WebKit behavior
	// this mess ain't funny: https://hsivonen.fi/kesakoodi/clipboard/
	override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
		if sender.draggingSource() == nil { //dragged from external application
			let pboard = sender.draggingPasteboard()

			if let file = pboard.string(forType: NSPasteboard.PasteboardType(kUTTypeFileURL as String)) { //drops from Finder
				warn("DnD: file from Finder: \(file)")
			} else {
				pboard.dump()
				pboard.normalizeURLDrag() // *cough* Trello! *cough*
				//^^ no longer needed? https://webkit.org/blog/8170/clipboard-api-improvements/
				pboard.dump()
			}

			if let urls = pboard.readObjects(forClasses: [NSURL.self], options: nil) {
				if AppScriptRuntime.shared.anyHandled(.handleDragAndDroppedURLs, urls.map({($0 as! NSURL).description})) {
			 		return true  // app.js indicated it handled drag itself
				}
			}
		} // -from external app

		return super.performDragOperation(sender)
		// if current page doesn't have HTML5 DnD event observers, webview will just navigate to URL dropped in
		//  hmm, 10.13 does not open drags by default ...
	}

/*
	// allow controlling drags out of a MacPin window
	override func beginDraggingSessionWithItems(items: [AnyObject], event: NSEvent, source: NSDraggingSource) -> NSDraggingSession {
		// API didn't land in 10.11.4 or STP v7... https://bugs.webkit.org/show_bug.cgi?id=143618
		warn()
		return super.beginDraggingSessionWithItems(items, event: event, source: source)
		//  (-[WKWebView _setDragImage:at:linkDrag:]):
		// https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/DragandDrop/Concepts/dragsource.html#//apple_ref/doc/uid/20000976-CJBFBADF
		// https://developer.apple.com/library/mac/documentation/Cocoa/Reference/ApplicationKit/Classes/NSView_Class/index.html#//apple_ref/occ/instm/NSView/beginDraggingSessionWithItems:event:source:
	}
*/

	//func dumpImage() -> NSImage { return NSImage(data: view.dataWithPDFInsideRect(view.bounds)) }
	//var snapshotURL: String { get { NSImage(data: thumbnail.dataWithPDFInsideRect(thumbnail.bounds)) } } //data::
	// http://gauravstomar.blogspot.com/2012/08/convert-uiimage-to-base64-and-vice-versa.html
	// http://www.cocoabuilder.com/archive/cocoa/318060-base64-encoding-of-nsimage.html#318071
	// http://stackoverflow.com/questions/392464/how-do-i-do-base64-encoding-on-iphone-sdk

	func copyAsPDF() {
		let pb = NSPasteboard.general
		pb.clearContents()
		writePDF(inside: bounds, to: pb)
	}

	@objc func printWebView(_ sender: AnyObject?) {
#if STP
		// _printOperation not avail in 10.11.4's WebKit
		//let printer = _printOperation(with: NSPrintInfo.shared, forFrame: WKFrame)
		guard let printer = _printOperation(with: NSPrintInfo.shared) else { return }
		// nil is returned if page contains encrypted/secured PDF, and maybe other qualms

		printer.showsPrintPanel = true
		if let window = self.window {
			printer.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
		} else {
			printer.run()
		}
#endif
	}

	func console() {
		let inspector = WKPageGetInspector(_pageRefForTransitionToWKWebView)
		DispatchQueue.main.async() {
			WKInspectorShowConsole(inspector) // ShowConsole, Hide, Close, IsAttatched, Attach, Detach
		}
	}

#endif
}
