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

	func wkclone() -> MPWebView {
		return (self as! MPWebView).clone()
	}

	func wkclone(_ options: MPWebViewConfigOptions...) -> MPWebView {
		return (self as! MPWebView).clone(options)
	}
}

enum MPWebViewConfigOptions {
	case
		url(String), agent(String), agentApp(String),
		icon(String), proxy(String), sproxy(String),

		transparent(Bool), isolated(Bool), privacy(Bool),
		allowsMagnification(Bool), allowsRecording(Bool),
		caching(Bool), useSystemAppearance(Bool),
		inspectorVisible(Bool),

		preinject([String]), postinject([String]),
		style([String]), subscribeTo([String]),
		authorizedOriginsForNotifications([String]),

		handlers([String:[JSValue]]), styles([String:Any]),

		configuration(WKWebViewConfiguration),
		URL(URL)
}

extension MPWebViewConfigOptions: RawRepresentable, Hashable {
	public typealias RawValue = String

	public var rawValue: RawValue {
		return Mirror(reflecting: self).children.first!.label!
	}

	init?(rawValue: RawValue) {
		return nil
	}

	init?(rawValue: RawValue, value: Any) {
		switch value {
			case let value as Bool:
				switch rawValue {
					case "caching":             self = .caching(value)
					case "transparent":         self = .transparent(value)
					case "inspectorVisible":    self = .inspectorVisible(value)
					case "isolated":            self = .isolated(value)
					case "private", "privacy":  self = .privacy(value)
					case "allowsMagnification": self = .allowsMagnification(value)
					case "allowsRecording":     self = .allowsRecording(value)
					case "useSystemAppearance": self = .useSystemAppearance(value)
					default:
						warn("unhandled boolean option: {\(rawValue): \(value)}")
						return nil
				}
			case let value as String:
				switch rawValue {
					case "url":         self = .url(value)
					case "agent":       self = .agent(value)
					case "agentApp":    self = .agentApp(value)
					case "icon":        self = .icon(value)
					case "proxy":       self = .proxy(value)
					case "sproxy":      self = .sproxy(value)
					default:
						warn("unhandled string option: {\(rawValue): \(value)}")
						return nil
				}
			case let value as [String]:
				switch rawValue {
					case "authorizedOriginsForNotifications":   self = .authorizedOriginsForNotifications(value)
					case "preinject":   self = .preinject(value)
					case "postinject":  self = .postinject(value)
					case "subscribeTo": self = .subscribeTo(value)
					case "style":       self = .style(value)
					default:
						warn("unhandled string-array option: {\(rawValue): \(value)}")
						return nil
				}
			case let value as [String:[JSValue]]:
				switch rawValue {
					case "handlers":    self = .handlers(value)
					default:
						warn("unhandled hash-of-arrays option: {\(rawValue): \(value)}")
						return nil
				}
			case let value as [String:Any]:
				switch rawValue {
					case "styles":      self = .styles(value)
					default:
						warn("unhandled hash option: {\(rawValue): \(value)}")
						return nil
				}
			default: return nil
		}
	}

	var caseName: String {
		return Mirror(reflecting: self).children.first!.label!
	}

	var caseValue: Any? {
		return Mirror(reflecting: self).children.first!.value
	}

	var description: String { return "<\(type(of: self)).\(self.rawValue)>(\(self.caseValue))" }
}

@objc class MPWebViewConfig: NSObject {
	var options: Set<MPWebViewConfigOptions>

	func set(_ propName: String, _ value: Any) -> MPWebViewConfigOptions? {
		if let option = MPWebViewConfigOptions(rawValue: propName, value: value) {
			options.insert(option)
			return option
		}
		warn("unaccepted option! \(propName) -> \(value)")
		return nil
	}

	func set(_ option: MPWebViewConfigOptions) -> Bool {
		return options.insert(option).inserted
	}

	func set(_ options: MPWebViewConfigOptions...) -> Bool {
		return options.allSatisfy({ self.options.insert($0).inserted })
	}

	func set(_ options: [MPWebViewConfigOptions]) -> Bool {
		return options.allSatisfy({ self.options.insert($0).inserted })
	}

	func reset(_ option: MPWebViewConfigOptions) {
		options.update(with: option)
	}

    func reset(_ options: MPWebViewConfigOptions...) {
		options.forEach({ self.options.update(with: $0) })
	}

    func reset(_ options: [MPWebViewConfigOptions]) {
		options.forEach({ self.options.update(with: $0) })
	}

	required init(_ options: Set<MPWebViewConfigOptions> = []) {
		self.options = options
	}

	required init(_ options: MPWebViewConfigOptions...) {
		self.options = Set<MPWebViewConfigOptions>(options)
	}

	static func fromJS(object: JSValue) -> Self {
		var config = Self()
		let objKeys = object.toDictionary().keys.flatMap({$0 as? String})
		for key in objKeys {
			guard let jsvalue = object.objectForKeyedSubscript(key) else { continue }
			if let value = jsvalue.toString(), jsvalue.isString {
				warn("\(key) => \(value)")
				warn(config.set(key, value))
			} else if jsvalue.isBoolean {
				config.set(key, jsvalue.toBool())
			} else if let value = jsvalue.toArray(), jsvalue.isArray {
				config.set(key, value.flatMap { $0 as? String })
			} else if jsvalue.isObject {
				// [prop] takes a Obj of Arrays (of Objs or Strings)
				var newObjs: [String: [JSValue]] = [:]
				//   we will double check all keys and filter valid ones into newObjs
				let objNames = jsvalue.toDictionary().keys.flatMap({$0 as? String})
				warn(objNames.description)
				for name in objNames {
					guard let obj = jsvalue.objectForKeyedSubscript(name) else {
						warn("no object given for config-option \(key)['\(name)']!")
						// FIXME? if .style, could treat unvalued-key-name as a request for a plain .css injection
						continue
					}
					if obj.isArray { // array of handler funcs (hopefully) was passed
						guard let arr = obj.invokeMethod("slice", withArguments: [0]) else { continue }// dup the array so pop() won't mutate the original
						// for handler in hval.toArray() { // -> Any .. not useful
						guard let arrLen = arr.forProperty("length").toNumber() as? Int, arrLen > 0 else { continue }
						for num in 1...arrLen { // C-Loop ftw
							//guard let arrVal = obj.atIndex(num) else { warn("cannot acquire \(num)th JSValue for \(name)"); continue }
							//guard let arrVal = obj.objectAtIndexedSubscript(num) else { warn("cannot acquire \(num)th JSValue for \(name)"); continue }
							// JSC BUG: dict-of-array contained functions are `undefined` when pulled with atIndex/objAtIndexSub
							guard let arrVal = obj.invokeMethod("pop", withArguments: []) else {
								warn("cannot acquire \(num)th JSValue for config-option \(key)['\(name)'")
								continue
							}
							if key == "handlers" && !arrVal.isNull && !arrVal.isUndefined && arrVal.hasProperty("call") { // got a func
								newObjs[name, default: []].append(arrVal)
								// should use arrVal.toObjectOf(SomeMPClass)
							}
						}
					} else if key == "handlers" && !obj.isNull && !obj.isUndefined && obj.hasProperty("call") { // a single handler func was passed
						newObjs[name, default: []].append(obj)
					}
				}
				config.set(key, newObjs)
			} else {
				warn("BUG: did not handle config-option: \(key)")
			}
		}
		return config
	}

	static func fromDict(_ dict: [String: Any]) -> Self {
		var config = Self()
		for (key, value) in dict {
			guard let option = config.set(key, value) else { continue }
		}
		return config
	}
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
	func toString() -> String

	var hash: Int { get }
	var transparent: Bool { get set }
	var caching: Bool { get set }
	var userAgent: String { get set }
	var userAgentAppName: String { get set }
	var allowsMagnification: Bool { get set }
	var allowsRecording: Bool { get set }
	//var canGoBack: Bool { get }
	//var canGoForward: Bool { get }
	//var hasOnlySecureContent: Bool { get }
	// var userLabel // allow to be initiated with a trackable tag
	var useSystemAppearance: Bool { get set }
	var inspectorVisible: Bool { get set }
	var injected: [String] { get }
	var styles: [String] { get }
	var blockLists: [String] { get }
		//WKContentRuleListStore.default().getAvailableContentRuleListIdentifiers(_ completionHandler: (([String]?)
		// https://trac.webkit.org/changeset/213696/webkit
		// https://developer.apple.com/library/archive/documentation/Extensions/Conceptual/ContentBlockingRules/CreatingRules/CreatingRules.html

	var isLoading: Bool { get }

	//static var MatchedAddressOptions: [String:String] { get set }

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
	func subscribeTo(_ handler: String)
	func console()
	func repaint()
	func scrapeIcon()
	//func goBack()
	//func goForward()
	func reload() -> WKNavigation?
	//func reloadFromOrigin()
	//func stopLoading() -> WKNavigation?
	//var snapshotURL: String { get } // gets a data:// of the WKThumbnailView
}
// USETHESE:
// https://github.com/apple/swift-evolution/blob/master/proposals/0195-dynamic-member-lookup.md
// https://github.com/apple/swift-evolution/blob/master/proposals/0216-dynamic-callable.md

@objcMembers
class MPWebView: WKWebView, WebViewScriptExports {

	//@objc dynamic var isLoading: Bool
	//@objc dynamic var estimatedProgress: Double

	var isIsolated = false
	var isPrivate = false
	var usesProxy = ""
	var usesSproxy = ""

	var notifier: WebNotifier? = nil

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
	var blockLists: [String] = []

	var authorizedOriginsForNotifications: [String] = []

	//let jsdelegate = AppScriptRuntime.shared.jsdelegate
	// race condition? seems to hit a phantom JSContext/JSValue that doesn't represent the delegate!?
	var jsdelegate: JSValue { get { return AppScriptRuntime.shared.jsdelegate } }

	override var urlstr: String { // accessor for JSC, which doesn't support `new URL()`
		get { return url?.absoluteString ?? "" }
		set { loadURL(newValue) }
	}

	var userAgent: String {
		get { return _customUserAgent.isEmpty ? _userAgent : _customUserAgent }
		// @abstract The custom user agent string or nil if no custom user agent string has been set.
		set(agent) {
			_customUserAgent =
				// lolwut JSExport<String?> will toString() whatever is received...	so we get String("null") for JSNull
				( agent == "null" || agent == "undefined" || agent == "false" || agent.isEmpty ) ?
					"" : agent // so treat all falsies as empty-string
				// webkit treats empty-string _customUserAgent as equivalent to default user agent
		}
	}

	var userAgentAppName: String { // is suffixed to an automatic webkit useragent if not blank:
		// https://github.com/WebKit/webkit/blob/master/Source/WebCore/platform/cocoa/UserAgentCocoa.mm
		// https://github.com/WebKit/webkit/blob/master/Source/WebCore/platform/mac/UserAgentMac.mm#L48
		get { return _applicationNameForUserAgent ?? "" }
		//set(app) { if !app.isEmpty { _applicationNameForUserAgent = app } }
		set(app) {
			_applicationNameForUserAgent =
				( app == "null" || app == "undefined" || app == "false" || app.isEmpty ) ?
					"" : app
		}
	}

	//let page = self.browsingContextController()._pageRef // https://github.com/WebKit/webkit/blob/e41847fbe7dd0bf191a8dafc2c3a5d965e96d277/Source/WebKit2/UIProcess/Cocoa/WebViewImpl.h#L368
	//let browsingContext = WKWebProcessPlugInBrowserContextController.lookUpBrowsingContextFromHandle(_handle)
	//let page = browsingContext._pageRef
	//let browsingContextController = WKBrowsingContextController._browsingContextControllerForPageRef(_pageForTesting())
		// register a custom protocol to handle X-Host: https://github.com/WebKit/webkit/blob/fa0c14782ed939dabdb52f7cffcb1fd0254d4ef0/Tools/TestWebKitAPI/cocoa/TestProtocol.mm
		// https://github.com/WebKit/webkit/blob/49cc03e4bf77a42908478cfbda938088cf1a8567/Source/WebKit2/NetworkProcess/CustomProtocols/CustomProtocolManager.h
		//   registerProtocolClass(NSURLSessionConfiguration) <- that could let you configure ad-hoc CFProxySupport dictionaries: http://stackoverflow.com/a/28101583/3878712
		// NSURLSessionConfiguration ? https://www.objc.io/issues/5-ios7/from-nsurlconnection-to-nsurlsession/

	var context: WKContextRef? {
		get {
			guard let page = _page else { return nil }
			return WKPageGetContext(page)
		}
	}

#if os(OSX)
	var caching: Bool {
		get {
			if #available(macOS 10.13.4, *) {
				return configuration.preferences._usesPageCache
			} else {
				return true
			}
		}
		set {
			if #available(macOS 10.13.4, *) {
				configuration.preferences._usesPageCache = newValue
				// is a reload() is required to take effect for subsequent naviagtions?
			}
		}

	}

	var _page: WKPageRef? {
		get {
			if WebKit_version >= (605, 1, 7) {
				// _pageRefForTransition is very new, pageRefForTesting is older
				return _pageRefForTransitionToWKWebView
			} else {
				return _pageForTesting()
			}
		}

	}

	var inspector: _WKInspector? {
		get {
			if WebKit_version >= (607, 1, 3) {
				// https://github.com/WebKit/webkit/commit/1f7d382aa1e6fc67476787ce6a7b9a791b32f434
				return _inspector
			} else {
				return nil
			}
		}
	}

	var inspectorVisible: Bool {
		get { return inspector?.isVisible ?? false }
		set {
			guard let inspector = inspector else { return }
			if (newValue && !inspector.isVisible) {
				inspector.show()
			} else if (!newValue && inspector.isVisible) {
				inspector.hide()
			}
		}
	}


	var inspectorAttachmentView: NSView? {
		// when inspector is open, subviews.first is actually the inspector (WKWebInspectorWKWebView), not the WKView
		// tabitem.view.subviews = [ WKWebInspectorView, WKView, ... ]
		get {
			if WebKit_version >= (605, 1, 7) {
				// no inner WKView in STP, iOS10, & Sierra: https://bugs.webkit.org/show_bug.cgi?id=150174#c0 landed ~ 602.1.9.1, 602.1.11 (in ChLog)
				return self._inspectorAttachmentView
			} else {
				// https://github.com/WebKit/webkit/blob/8c504b60d07b2a5c5f7c32b51730d3f6f6daa540/Source/WebKit2/UIProcess/mac/WebInspectorProxyMac.mm#L679
				if let topFrame = subviews.first as? WKView {
					return topFrame._inspectorAttachmentView
				}
				return nil
			}
		}
		set {
			if WebKit_version >= (605, 1, 7) {
				self._inspectorAttachmentView = newValue
			} else {
				if let topFrame = subviews.first as? WKView {
					topFrame._inspectorAttachmentView = newValue
				}
			}
		}
	}

	var transparent: Bool {
		get {
			if WebKit_version >= (602, 1, 11) {
				return !_drawsBackground
			} else {
				return _drawsTransparentBackground
			}
		}
		set(transparent) {
			if WebKit_version >= (602, 11, 11) {
				_drawsBackground = !transparent
			} else {
				_drawsTransparentBackground = transparent
			}

			AppScriptRuntime.shared.emit(.tabTransparencyToggled, transparent as AnyObject, self)
			evalJS("window.dispatchEvent(new window.CustomEvent('MacPinWebViewChanged',{'detail':{'transparent': \(transparent)}}));")
			// ^ JS->DOM may not finish up fast enough for the repaints to cleanly update the view
			WKPageForceRepaint(_pageRefForTransitionToWKWebView, nil, {error, void in warn()} as WKPageForceRepaintFunction )
			//^ background-color:transparent sites immediately bleedthru to a black CALayer, which won't go clear until the content is reflowed or reloaded
			needsDisplay = true // queue the whole frame for rerendering
		}
	}

	var useSystemAppearance: Bool {
		get { return _useSystemAppearance }
		set(val) { _useSystemAppearance = val }
	}

#elseif os(iOS)
	var useSystemAppearance: Bool {
		get { return true }
		set(val) { }
	}
	func console() { }
	func repaint() { }

	var caching: Bool {
		get { return true }
		set(val) { }
	}

	var inspectorVisible: Bool {
		get { return false }
		set(val) { }
	}

	var _page: WKPageRef? {
		get {
			return _pageForTesting()
			// not linking...
			// guard let topFrame = subviews.first as? WKView else { return nil }
			// return topFrame.pageRef
		}
	}

	var transparent = false // no overlaying MacPin apps upon other apps in iOS, so make it a no-op
	var allowsMagnification = true // not exposed on iOS WebKit, make it no-op
#endif
	var allowsRecording: Bool {
		get { return _mediaCaptureEnabled }
		set (recordable) { _mediaCaptureEnabled = recordable }
	}

	let favicon: FavIcon = FavIcon()

	@objc convenience required init(config: MPWebViewConfig) {
		var caching = true
		var configuration = WKWebViewConfiguration()
		var needs_reconfiguration = true
		var isolated = false
		var privacy = false
		var proxy = ""
		var sproxy = ""

		// some props must be set during init before all other props
		for option in config.options {
			switch option {
				case .caching(let value): caching = value
				case .configuration(let value):
					configuration = value
					needs_reconfiguration = false
				case .isolated(let value): isolated = value
				case .privacy(let value): privacy = value
				case .proxy(let value) where !value.isEmpty: proxy = value
				case .sproxy(let value) where !value.isEmpty: sproxy = value
				default: break
			}
		}

		// init webview with custom config, needed for JS:window.open() which links new child Windows to parent Window
		if needs_reconfiguration {
#if os(OSX)
			if WebKit_version.major >= 602 { // Safari 10
				//configuration._showsURLsInToolTips = true
				configuration._serviceControlsEnabled = true
				configuration._imageControlsEnabled = true
				//configuration._requiresUserActionForEditingControlsManager = true
			}
#endif
			if WebKit_version >= (604, 1, 28) { // Version/11.0 Safari/604.1.28 sierra
				configuration._allowUniversalAccessFromFileURLs = true
				if #available(macOS 10.13, iOS 11, *) {
					// https://forums.developer.apple.com/thread/87474#267547
					configuration.setURLSchemeHandler(MPRetriever(), forURLScheme: "x-macpin")
					// has to be set before self.init
				}
			}
		}
		let prefs = WKPreferences() // http://trac.webkit.org/browser/trunk/Source/WebKit2/UIProcess/API/Cocoa/WKPreferences.mm
#if os(OSX)
		prefs._developerExtrasEnabled = true // Enable "Inspect Element" in context menu
		prefs._fullScreenEnabled = true

		prefs._colorFilterEnabled = true // enables -apple-color-filter prop in css
		prefs._punchOutWhiteBackgroundsInDarkMode = true
		// allows white backgrounds (in all element types) to selectively be made transparent

		// gate?
		prefs._javaScriptCanAccessClipboard = true
		prefs._domPasteAllowed = true

		// https://webkit.org/blog/7763/a-closer-look-into-webrtc/
		//if #available(OSX 10.13, iOS 11, *) {
		if WebKit_version >= (604, 1, 8) { // Safari-604.1.8 = Safari 11, STP_32
			// https://trac.webkit.org/changeset/213294/webkit
			prefs._mediaCaptureRequiresSecureConnection = false
			prefs._mediaDevicesEnabled = true // audio device acquisiton always fails :-(
			//prefs._mockCaptureDevicesEnabled = true // works perfectly but uses internal bip-bop streams

			// gate?
			prefs._peerConnectionEnabled = true
			prefs._screenCaptureEnabled = true

		} else {
			warn("WebRTC not available for WebKit: \(WebKit_version)")
		}

		if !caching, #available(macOS 10.13.4, *) {
			prefs._usesPageCache = false
		}
#endif

		if privacy {
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

		var dataStore = privacy ? WKWebsiteDataStore.nonPersistent() : WKWebsiteDataStore.default()

		if #available(macOS 10.14.4, iOS 12.2, *) {
			let dataStoreConf = privacy ? _WKWebsiteDataStoreConfiguration(nonPersistentConfiguration: ()) : _WKWebsiteDataStoreConfiguration()

			if let proxyURL = URL(string: proxy), !proxy.isEmpty {
				dataStoreConf.httpProxy = proxyURL
				warn("HTTP proxy: \(dataStoreConf.httpProxy?.absoluteString)")
			}
			if let sproxyURL = URL(string: sproxy), !sproxy.isEmpty {
				dataStoreConf.httpsProxy = sproxyURL
				warn("HTTPS proxy: \(dataStoreConf.httpsProxy?.absoluteString)")
			}
			dataStore = dataStore._init(with: dataStoreConf)
		}

		//if #available(OSX 10.11, iOS 9, *) {
		if WebKit_version >= (601, 1, 30) {
			configuration.websiteDataStore = dataStore
		}

		if isolated {
			configuration.processPool = WKProcessPool() // not "private" but usually gets new session variables from server-side webapps
		} else {
			configuration.processPool = configuration.processPool ?? (MPWebView.self.sharedWebProcessPool)!
		}

		self.init(frame: CGRect.zero, configuration: configuration) // This is the real init()
		// its an ObjC++ ctor which is why we couldn't override its impl to do these defaultings

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
		_applicationNameForUserAgent = "Version/\(Safari_version) Safari/\(WebKit_version.major).\(WebKit_version.minor).\(WebKit_version.tiny)"

		if let context = context {
			"http".withCString { http in
				WKContextRegisterURLSchemeAsBypassingContentSecurityPolicy(context, WKStringCreateWithUTF8CString(http)) // FIXME: makeInsecure() toggle!
			}
			"https".withCString { https in
				WKContextRegisterURLSchemeAsBypassingContentSecurityPolicy(context, WKStringCreateWithUTF8CString(https))
			}
		}

#elseif os(iOS)
		_applicationNameForUserAgent = "Version/10 Mobile/12F70 Safari/\(WebKit_version.major).\(WebKit_version.minor).\(WebKit_version.tiny)"
#endif

		var url: URL? = nil

		for option in config.options {
			switch option {
				case .caching:
					break // already captured pre-init
				case .configuration:
					break // already captured pre-init
				case .inspectorVisible:
					break // handled after navigation
				case .isolated:
					self.isIsolated = isolated
				case .privacy:
					self.isPrivate = privacy
				case .proxy:
					self.usesProxy = proxy
				case .sproxy:
					self.usesSproxy = sproxy
				case .URL(let urlObj):
					url = urlObj
				case .url(let urlstr) where !urlstr.isEmpty:
					url = URL(string: urlstr)
				case .agent(let agent) where !agent.isEmpty:
					_customUserAgent = agent
				case .agent: break // isEmpty
				case .agentApp(let appName) where !appName.isEmpty:
					_applicationNameForUserAgent = appName
				//TODO: if v.startsWith('+='), then append to whatever self.userAgent & self.userAgentAppName return
				// lots of JS libs pick from many expressions in the UA, but we may not always want to be hardcoding platform version numbers
				// so a dynamic append feature on init is desirable
				case .agentApp: break // isEmpty
				case .icon(let icon) where !icon.isEmpty:
					loadIcon(icon)
				case .icon: break // isEmpty
				case .allowsMagnification(let magnification):
					allowsMagnification = magnification
				case .allowsRecording(let recordable):
					_mediaCaptureEnabled = recordable
				case .transparent(let transparent):
#if os(OSX)
					if WebKit_version >= (602, 1, 11) {
						_drawsBackground = !transparent
					} else {
						_drawsTransparentBackground = transparent
					}
#endif
				case .preinject(let value):
					for script in value { preinject(script) }
				case .postinject(let value):
					for script in value { postinject(script) }
				case .style(let value):
					for css in value { style(css) }
				case .handlers(let value):
					// for handler in value { addHandler(handler) } //FIXME kill delegate.`handlerStr` indirect-str-refs
					addHandlers(value)
				case .subscribeTo(let value):
					for handler in value { subscribeTo(handler) }
				case .authorizedOriginsForNotifications(let value):
					authorizedOriginsForNotifications = value
				case .useSystemAppearance(let value):
					self.useSystemAppearance = value
				default:
					warn("unhandled config-option: \(option)")
			}
		}

		self.notifier = WebNotifier(self)

		for originStr in authorizedOriginsForNotifications {
			self.notifier?.authorizeNotifications(fromOrigin: URL(string: originStr))
		}

		if let url = url {
			gotoURL(url)

			// some options require a page to be loading (even a lowly about:blank)
			for option in config.options {
				switch option {
#if os(OSX)
					case .inspectorVisible(let value):
						self.inspectorVisible = value
#endif
					default: break
				}
			}
		}
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
			//let confObj = JSManagedValue(value: object)
			let config = MPWebViewConfig.fromJS(object: object)
			self.init(config: config) // BUG: using any nonobjc inits in the chain (from a JSContext instanciation) will cause SIGSEGV
			//object.context.virtualMachine.addManagedReference(confObj, withOwner: self)
		} else { // isUndefined, isNull
			// returning nil will actually SIGSEGV
			//warn(obj: object)
			self.init(url: URL(string: "about:blank")!)
		}
	}

	@objc convenience required init(configuration: WKWebViewConfiguration) {
		self.init(config: MPWebViewConfig([.configuration(configuration)]))
	}

	@objc convenience required init(url: URL) {
		self.init(config: MPWebViewConfig([.URL(url)]))
	}

	@objc convenience required init(configuration: WKWebViewConfiguration, url: URL) {
		self.init(config: MPWebViewConfig([.URL(url), .configuration(configuration)]))
	}

	@objc convenience required init() {
		self.init(config: MPWebViewConfig())
		// FIXME: deinit's need to be consistent! seems to be deferring onto JSC's GC schedule..
		// `var wv = new WebView(); wv = null;` - defers
		// `var wv = new WebView("http://google.com"); console.log(wv.title); wv = null;` - defers
	}

	convenience init(_ options: MPWebViewConfigOptions...) {
		self.init(config: MPWebViewConfig(Set<MPWebViewConfigOptions>(options)))
	}

	var config: MPWebViewConfig {
		return MPWebViewConfig(
			.agent(self._customUserAgent),
			.agentApp(self._applicationNameForUserAgent),
			.allowsMagnification(self.allowsMagnification),
			.allowsRecording(self._mediaCaptureEnabled),
			.caching(self.caching),
			.configuration(self.configuration),
			.icon(self.favicon.url?.absoluteString ?? ""),
			.proxy(self.usesProxy),
			.sproxy(self.usesSproxy),
			.inspectorVisible(self.inspectorVisible),
			.isolated(self.isIsolated),
			.privacy(self.isPrivate),
			.transparent(self.transparent),
			.useSystemAppearance(self.useSystemAppearance),
			.url(self.url?.absoluteString ?? "")
		)
	}

	override var description: String { return "<\(type(of: self))> `\(title ?? String())` [\(urlstr)]" }
	func inspect() -> String { return "`\(title ?? String())` [\(urlstr)]" }
	func toString() -> String { return "`\(title ?? String())` [\(urlstr)]" }

	deinit {
		self.notifier = nil
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
		} else {
			warn("no-callback")
			evaluateJavaScript(js, completionHandler: nil)
		}
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

	@nonobjc func gotoURL(_ url: NSURL) { gotoURL(url as URL) }
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

	@discardableResult
	func blockList(_ json: String) -> Bool {
		if #available(OSX 10.13, iOS 11, *) {
			if !blockLists.contains(json) && loadUserBlockListFromBundle(json, webctl: configuration.userContentController, onlyForTop: false) { blockLists.append(json); return true }
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
		return false // ambiguous ... does this mean no script was injected because its already loaded or its not loaded cuz its broken?
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

	func addHandlers(_ handlerMap: [String: [JSValue]]) {
		for (eventName, handlers) in handlerMap {
			//warn("\(eventName) => \(type(of: handlers))\(handlers)")
			var cbs = AppScriptRuntime.shared.messageHandlers[eventName, default: []]

			for hd in handlers {
				if !hd.isNull && !hd.isUndefined && !cbs.contains(hd) && hd.hasProperty("call") {
					warn("\(eventName)") // += \(type(of: hd)) \(hd)")
					cbs.append(hd)
				} else { warn("handler for \(eventName) not a callable! <= \(hd)") }
			}

			guard !cbs.isEmpty else { continue }
			AppScriptRuntime.shared.messageHandlers[eventName] = cbs
			// BUG? cross-tab event broadcasting done thru .shared[eventName] ...
			configuration.userContentController.add(AppScriptRuntime.shared, name: eventName)
		}
	}

	// TODO: addStyles(_ stylesMap: [String: [JSValue]])

	func subscribeTo(_ handler: String) {
		configuration.userContentController.removeScriptMessageHandler(forName: handler)
		configuration.userContentController.add(AppScriptRuntime.shared, name: handler)
	}

	func REPL() -> Prompter? {
		var stderr = FileHandle.standardError
		return Prompter.termiosREPL({ (line: String) -> Void in
			self.evaluateJavaScript(line, completionHandler:{ (result: Any?, exception: Error?) -> Void in
				// FIXME: the JS execs async so these print()s don't consistently precede the REPL thread's prompt line
				if let result = result { Swift.print(result, to: &stderr) }
				guard let exception = exception else { return }
				switch (exception._domain, exception._code) { // codes: https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/Cocoa/WKError.h
					// case(WKErrorDomain, Int(WKErrorCode.JavaScriptExceptionOccurred.rawValue)): fallthrough
					// case(WKErrorDomain, Int(WKErrorCode.JavaScriptResultTypeIsUnsupported.rawValue)): fallthrough
						// info keys: https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/Cocoa/WKErrorPrivate.h
						// _WKJavaScriptExceptionMessageErrorKey
						// _WKJavaScriptExceptionLineNumberErrorKey
						// _WKJavaScriptExceptionColumnNumberErrorKey
						// _WKJavaScriptExceptionSourceURLErrorKey
					default: Swift.print("Error: \(exception)", to: &stderr)
				}
			})
		},
		ps1: #file,
		ps2: #function,
		abort: { () -> (()->Void)? in
			// EOF'd by Ctrl-D
			// self.close() // FIXME: self is still retained (by the browser?)
#if os(OSX)
			return {
				warn("got EOF from stdin, stopping console")
				ProcessInfo.processInfo.enableSuddenTermination()
				NSApp.reply(toApplicationShouldTerminate: true) // now close App if this was deferring a terminate()
			}
#endif
			return nil
		})
	}

	//webview._getMainResourceDataWithCompletionHandler() { (data: Data?, err: Error?) -> Void in }
	//webview._getContentsAsStringWithCompletionHandler() { (str: String?, err: Error?) -> Void in }
	//webview._getApplicationManifestWithCompletionHandler() { (manifest: _WKApplicationManifest?) -> Void in }
	// 605.2.8 == safari 11.1 for PWA manifest support
	//    no Service Worker API for wkwebviews yet: https://webkit.org/blog/8090/workers-at-your-service/

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
				warn("not capturing selector but passing to super: \(anItem.action ?? "no-name")")
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
		if sender.draggingSource == nil { //dragged from external application
			let pboard = sender.draggingPasteboard

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
		//if #available(OSX 10.12, iOS 10, *) {
			// _printOperation not avail in 10.11.4's WebKit
			//   but what about Safari 11 back-releases to 10.11/ElCap?
		if WebKit_version >= (602, 1, 12) { // 11/2015 602.1.11.1 probably works too
			guard let printer = _printOperation(with: NSPrintInfo.shared) else {
				warn("failed to get NSPrintOperation! (perhaps encrypted/secured content present)")
				// nil is returned if page contains encrypted/secured PDF, and maybe other qualms
				return
			}

			printer.showsPrintPanel = true
			printer.showsProgressPanel = true
			printer.canSpawnSeparateThread = true
			printer.printPanel.jobStyleHint = .allPresets
			printer.printPanel.options = [.showsPreview, .showsPageRange, .showsPageSetupAccessory, .showsCopies]

			if let window = self.window {
				// will get a pop-over
				printer.runModal(for: window, delegate: nil, didRun: nil, contextInfo: nil)
			} else {
				// non-selected tab/popup requested window.print(), will be a floating dialog
				printer.run()
			}
		}
	}

	func console() {
		guard let inspector = _inspector else { return }
		inspector.showConsole() // ShowConsole, Hide, Close, IsAttatched, Attach, Detach
	}

	func repaint() {
		guard let page = _page else { return }
		WKPageForceRepaint(page, nil, {error, void in warn()} as WKPageForceRepaintFunction )
		needsDisplay = true // queue the whole frame for rerendering
	}

#endif

	func showDesktopNotification(title: String, tag: String, body: String, iconurl: String, id: Int, type: Int, origin: String, lang: String, dir: String) {
		warn("\(title) - \(body) - \(iconurl) - \(origin)")

		// https://electronjs.org/docs/tutorial/notifications
		// https://developers.google.com/web/updates/2017/04/native-mac-os-notifications

		// if !AppScriptRuntime.shared.anyHandled(.receivedHTML5Notification, webview, title, tag, body, id ..)
		//    postNotification(title ...)

		// will need to create a rich userInfo[:] to enable tab-selection
		// need W3C props: origin type
		//  https://github.com/chromium/chromium/blob/f18e79d901f56154f80eea1e2218544285e62623/chrome/browser/ui/cocoa/notifications/notification_builder_mac.mm
		// https://www.w3.org/TR/notifications/#activating-a-notification
		//   https://notifications.spec.whatwg.org/#activating-a-notification

		if AppScriptRuntime.shared.anyHandled(.postedDesktopNotification, ["title":title, "tag":tag, "body":body, "id":id], self) { return }

#if os(OSX)
		let note = NSUserNotification()
		note.title = title ?? ""
		note.subtitle =  "" //empty strings wont be displayed
		note.informativeText = body ?? ""
		//note.contentImage = ?bubble pic? //iconurl
		note.identifier = String(id) // TODO: make moar unique? would need to be stripped back to original before passing back to WK()

		//note.hasReplyButton = true
		//note.hasActionButton = true
		//note.responsePlaceholder = "say something stupid"

		note.userInfo = ["origin": origin, "type": type, "tabHash": hash]
		note.userInfo?["tag"] = tag // https://developer.mozilla.org/en-US/docs/Web/API/Notification/tag

		note.soundName = NSUserNotificationDefaultSoundName // something exotic?
		NSUserNotificationCenter.default.deliver(note)
		// these can be listened for by all: http://pagesofinterest.net/blog/2012/09/observing-all-nsnotifications-within-an-nsapp/
#endif
	}

#if DEBUG && os(OSX)
	@objc override func _gestureEventWasNotHandled(byWebCore event: NSEvent!) {
		// https://github.com/WebKit/webkit/commit/10f11d2d8227a7665c410c642ebb6cb9d482bfa8 r191299 10/19/2015
		warn(event.debugDescription)
		super._gestureEventWasNotHandled(byWebCore: event)
	}
#endif

	func proxied_clone(_ proxy: String? = nil, _ sproxy: String? = nil) -> MPWebView {
		// create a new proxied MPWebView sharing the same URL, cookie/sesssion data, useragent
		let config = self.config
		warn(proxy)
		config.reset(.proxy(proxy ?? ""))
		warn(sproxy)
		config.reset(.sproxy(sproxy ?? ""))
		return Self(config: config)
	}

	func clone() -> MPWebView {
		warn(self.config) // FIXME needs rich description()
		return Self(config: self.config)
	}

	func clone(_ options: MPWebViewConfigOptions...) -> MPWebView {
		warn(self.config) // FIXME needs rich description()
		let newConfig = self.config
		newConfig.reset(options)
		warn(newConfig) // FIXME needs rich description()
		return Self(config: newConfig)
	}

	func clone(_ options: [MPWebViewConfigOptions]) -> MPWebView {
		warn(self.config) // FIXME needs rich description()
		let newConfig = self.config
		newConfig.reset(options)
		warn(newConfig) // FIXME needs rich description()
		return Self(config: newConfig)
	}
}

#if os(OSX)
extension MPWebView { // NSTextFinderClient

	// https://github.com/WebKit/webkit/blob/master/Source/WebKit/UIProcess/mac/WKTextFinderClient.mm#L39
	@objc func scrollFindMatchToVisible(_ findMatch: WKTextFinderMatch) {
		//warn(obj: findMatch.containingView) // segs!
			// https://github.com/WebKit/webkit/blob/master/Source/WebCore/PAL/pal/spi/mac/NSTextFinderSPI.h
		//warn(obj: findMatch.textRects) // NSRect: {{230, 392}, {32, 20}}  {x, y}, {width, height}

		guard let rect = findMatch.textRects.first as? NSRect else { return }
		let scrollBox = CGSize(width: 0, height: rect.origin.y)
		warn(obj: scrollBox)
		//_setFrame(frame, andScrollBy: scrollBox) // WebKit availability?
		//scrollRangeToVisible(range)
    }

	// https://developer.apple.com/documentation/appkit/nstextfinderclient/1526989-scrollrangetovisible
	@available(macOS 10.15, *)
	@objc override func scrollRangeToVisible(_ range: NSRange) {
		warn(obj: range)

		guard let frects = self.rects(forCharacterRange: range),
			let firstRect = frects.first?.rectValue
				else { return }

		warn(obj: firstRect)
		super.scrollRangeToVisible(range)
	/*
		let clipView = scrollView.contentView // only on io-freaking-s
		// check for sure that NSSCrollView has NSClipView
		if( [clipView isKindOfClass:[NSClipView class]] ) {
			firstRect = [clipView convertRect:firstRect fromView:clipView.documentView];
			[clipView scrollRectToVisible:firstRect];
		}
	*/
	}

}
#endif
