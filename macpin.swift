/*
	Joey Korkames (c)2015
	Special thanks to Google for its horrible Hangouts App on Chrome for OSX :-)
*/

import WebKit
import Foundation
import ObjectiveC
import JavaScriptCore

func warn(msg:String) {
  	NSFileHandle.fileHandleWithStandardError().writeData((msg + "\n").dataUsingEncoding(NSUTF8StringEncoding)!)
}

func error(msg:String) {
	warn(msg)
	exit(1)
}

@objc protocol WebAppScriptExports : JSExport { // '$' in app.js
	var isTransparent: Bool { get }
	var isFullscreen: Bool { get }
	var lastLaunchedURL: String { get }
	var _jscore: JSContext! { get }
	var globalUserScripts: [String] { get set } // list of postinjects that any new webview will get
	func log(msg: String)
	func toggleTransparency()
	func toggleFullscreen()
	func closeCurrentTab()
	func stealAppFocus()
	func unhideApp()
	func newTabPrompt()
	func switchToNextTab()
	func switchToPreviousTab()
	func firstTabEvalJS(js: String)
	func currentTabEvalJS(js: String)
	func newAppTab(urlstr: String, withJS: [String: [String]], _ icon: String?, _ agent: String?) // $.newAppTabWithJS 
	func registerURLScheme(scheme: String)
	func postOSXNotification(title: String, _ subtitle: String?, _ msg: String)
	func sysOpenURL(urlstr: String, _ app: String?)
	//func getDefault()
	//func setDefault() // i think HTML5 app-cache/storage is available, may not be necessary
}

class MacPin: NSObject, WebAppScriptExports  {
	var app: NSApplication? = nil //the OSX app we are delegating methods for

	var windowController = NSWindowController(window: NSWindow(
		contentRect: NSMakeRect(0, 0, 600, 800),
		styleMask: NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask | NSUnifiedTitleAndToolbarWindowMask | NSFullSizeContentViewWindowMask,
		backing: .Buffered,
		defer: true
	))

	var viewController: NSTabViewController? //also available as windowController.contentViewController

	var isTransparent = false
	var isFullscreen: Bool {
		get { return (windowController.window?.contentView as NSView).inFullScreenMode }
	}

	var lastLaunchedURL = "" //deferment state for cold opening URLs

	var _webprefs: WKPreferences {
		get {
			var prefs = WKPreferences() // http://trac.webkit.org/browser/trunk/Source/WebKit2/UIProcess/API/Cocoa/WKPreferences.mm
			prefs.plugInsEnabled = true // NPAPI for Flash, Java, Hangouts
			//prefs.minimumFontSize = 14 //for blindies
			prefs.javaScriptCanOpenWindowsAutomatically = true;
			prefs._developerExtrasEnabled = true // http://trac.webkit.org/changeset/172406 will land in OSX 10.10.2?
			return prefs
		}
	}
	var _globalUserScripts: [String] = []
	var globalUserScripts: [String] {
		get { return self._globalUserScripts }
		set(newarr) { self._globalUserScripts = newarr }
	}

	var _jscore = JSContext(virtualMachine: JSVirtualMachine()) // https://github.com/WebKit/webkit/tree/master/Source/JavaScriptCore/API
		// http://stackoverflow.com/questions/24595692/swift-blocks-not-working
	var _jsapi: JSValue? //name of the callback object that app.js creates

    override init() { }

	func log(msg:String) {
#if APP2JSLOG
		if let tab = (firstTab()?.view as? WKWebView) {
			tab.evaluateJavaScript("console.log(\'\(reflect(self).summary): \(msg)\')", completionHandler: nil)
		}
#else
#endif
		warn(msg)
	}

	func loadJSCoreScriptFromBundle(basename: String) -> JSValue? {
		if let script_url = NSBundle.mainBundle().URLForResource(basename, withExtension: "js") {
			let script = NSString(contentsOfURL: script_url, encoding: NSUTF8StringEncoding, error: nil)!
			//if (JSCheckScriptSyntax(_jscore, script, script_url, 0, nil)) {
			//	log("loading core script: \(script_url)")
				return _jscore.evaluateScript(script, withSourceURL: script_url)
			//} else {
			//	log("\(script_url): failed syntax check!")
			//}
		}
		return nil
	}

	func loadUserScriptFromBundle(basename: String, webctl: WKUserContentController, inject: WKUserScriptInjectionTime, onlyForTop: Bool = true) -> Bool {
		if let script_url = NSBundle.mainBundle().URLForResource(basename, withExtension: "js") {
			log("loading userscript: \(script_url)")
			var script = WKUserScript(
				source: NSString(contentsOfURL: script_url, encoding: NSUTF8StringEncoding, error: nil)!,
			    injectionTime: inject,
			    forMainFrameOnly: onlyForTop
			)
			webctl.addUserScript(script)
		} else {
			return false //NSError?
		}
		return true
	}

	func sysOpenURL(urlstr: String, _ app: String? = nil) {
		let url = NSURL(string: urlstr)!
		let sys = NSWorkspace.sharedWorkspace()
		sys.openURLs([url], withAppBundleIdentifier: app, options: .AndHideOthers, additionalEventParamDescriptor: nil, launchIdentifiers: nil)
			//options: .Default .NewInstance .AndHideOthers
		//open -a "Google Chrome.app" --args --kiosk @url ....  // --args only works if the process isn't already running
		// launchurl = LSLaunchURLSpec(appURL: nil, itemURLs: url, launchFlags: .kLSLaunchDefualts)
		// LSOpenFromURLSpec(inLaunchSpec: launchurl, outLaunchedURL: nil)
		// https://src.chromium.org/svn/trunk/src/chrome/browser/app_controller_mac.mm
	}

	func handleGetURLEvent(event: NSAppleEventDescriptor!, replyEvent: NSAppleEventDescriptor?) {
		let sys = NSWorkspace.sharedWorkspace()
		//FIXME: if url was used to start app, applicationDidFinishLaunching() hasn't happened yet and jsapi isn't available!
		var url = NSURLComponents(string: event.paramDescriptorForKeyword(AEKeyword(keyDirectObject))!.stringValue!)!
		log("OSX is asking me to launch \(url.URL!)")
		var addr = url.path? ?? ""
		switch url.scheme? ?? "" {
			case "macpin-http", "macpin-https":
				url.scheme = url.scheme!.hasSuffix("s") ? "https:" : "http:"
        		newAppTab(url.URL!.description)
			default:
				log("Dispatching OSX-app-launched URL to JSCore: launchURL(\(url.URL!))")
				lastLaunchedURL = url.URL!.description
				_jsapi?.invokeMethod("launchURL", withArguments: [url.URL!.description])
				//FIXME: defer if jsapi not available?
		}
		//replyEvent == ??
	}

	func newTab(withView: NSView, withIcon: String? = nil) {
		var tab = NSTabViewItem(viewController: NSViewController()) //FIXME: make subclass of this for controliing tab transitions
		//withView.translatesAutoresizingMaskIntoConstraints = false
		//withView.autoresizingMask = .ViewMinXMargin | .ViewWidthSizable | .ViewMaxXMargin | .ViewMinYMargin | .ViewHeightSizable | .ViewMaxYMargin
		//withView.autoresizingMask = .ViewWidthSizable | .ViewHeightSizable
		//withView.autoresizesSubviews = true
		tab.viewController!.view = withView //punt webview into tab

		if let icon = withIcon? {
			tab.image = NSImage(byReferencingURL: NSURL(string: icon)!)
		} else {
			tab.image = app?.applicationIconImage
		}
		//need 24 & 36px**2 representations for the NSImage
		// https://developer.apple.com/library/ios/documentation/AppleApplications/Reference/SafariWebContent/ConfiguringWebApplications/ConfiguringWebApplications.html
		tab.identifier = withView.identifier //NSUserInterfaceItemIdentification
		//tab.label = "webtab" //only shows in uncollapsed title & window bar windowstyle
		if let webview = (withView as? WKWebView)? { tab.toolTip = "loading: [\(webview.URL!)]" }
		viewController?.addTabViewItem(tab)
	}

	func newWebView(url: NSURL, withAgent: String? = nil, withConfiguration: WKWebViewConfiguration = WKWebViewConfiguration()) -> WKWebView {
		withConfiguration.preferences = _webprefs
		withConfiguration.suppressesIncrementalRendering = false

		var webview = WKWebView(frame: NSMakeRect(0, 0, 50, 50), configuration: withConfiguration) //works
		//var webview = WKWebView(frame: viewController!.tabView.contentRect, configuration: withConfiguration) //works
		//var webview = WKWebView(frame: windowController.window!.contentView.bounds, configuration: withConfiguration) //works
		//var webview = WKWebView(frame: windowController.window!.contentView.contentLayoutRect, configuration: withConfiguration)
		//webview.autoresizingMask = .ViewMinXMargin | .ViewWidthSizable | .ViewMaxXMargin | .ViewMinYMargin | .ViewHeightSizable | .ViewMaxYMargin
		//webview.autoresizingMask = .ViewWidthSizable | .ViewHeightSizable
		//webview.autoresizesSubviews = true
		webview.allowsBackForwardNavigationGestures = true
		webview.allowsMagnification = true
		webview._drawsTransparentBackground = isTransparent
		webview._allowsRemoteInspection = true //FIXME add debug flag
		if let agent = withAgent? {
			webview._customUserAgent = agent
		} else { 
			webview._applicationNameForUserAgent = "Version/8.0.2 Safari/600.2.5"
		}
		//webview._automaticallyAdjustsContentInsets = true // https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/mac/WKView.mm#L3680
		webview.navigationDelegate = self // allows/denies navigation actions
		webview.UIDelegate = self //alert(), window.open()		
		webview.loadRequest(NSURLRequest(URL: url))
		webview.identifier = "WKWebView" + NSUUID().UUIDString //set before installing into a view/window, then get ... else crash!
		return webview
    }

	func getTabContainingView(view: NSView) -> NSTabViewItem? {
		if let tabView = viewController?.tabView {
			let tabIdx = tabView.indexOfTabViewItemWithIdentifier(view.identifier)
			if tabIdx == NSNotFound { return nil }
				else if let tabItem = (tabView.tabViewItems[tabIdx] as? NSTabViewItem) { return tabItem }
		}
		return nil
	}

	//func newAppTab(urlstr: String, _ postinject: [String] = [], _ preinject: [String] = [], _ handlers: [String] = [], _ icon: String? = nil, _ agent: String? = nil) {
	func newAppTab(urlstr: String, withJS: [String: [String]] = [:], _ icon: String? = nil, _ agent: String? = nil)  {
		var webctl = WKUserContentController()
		for (type, hooks) in withJS {
			switch type {
				case "preinject":
					for script in hooks { loadUserScriptFromBundle(script, webctl: webctl, inject: .AtDocumentStart, onlyForTop: false) }
				case "postinject":
					for script in hooks { loadUserScriptFromBundle(script, webctl: webctl, inject: .AtDocumentEnd, onlyForTop: false) }
				case "handlers":
					for hook in hooks { webctl.addScriptMessageHandler(self, name: hook) }
				default:
					true
			}
		}
		for script in _globalUserScripts { loadUserScriptFromBundle(script, webctl: webctl, inject: .AtDocumentEnd, onlyForTop: false) }

		var webcfg = WKWebViewConfiguration()
		webcfg.userContentController = webctl
		var webview = newWebView(NSURL(string: urlstr)!, withAgent: agent, withConfiguration: webcfg)
		newTab(webview, withIcon: icon)
		//return webctl
	}

	func registerURLScheme(scheme: String) {
		LSSetDefaultHandlerForURLScheme(scheme, NSBundle.mainBundle().bundleIdentifier);
		log("registered URL handler in OSX: \(scheme)")
	}

	func postOSXNotification(title: String, _ subtitle: String?, _ msg: String) {
		var note = NSUserNotification()
		note.title = title
		note.subtitle = subtitle ?? "" //empty strings wont be displayed
		note.informativeText = msg
		//note.contentImage = ?bubble pic?
		note.soundName = NSUserNotificationDefaultSoundName // something exotic?
		NSUserNotificationCenter.defaultUserNotificationCenter().deliverNotification(note)
		// these can be listened for by all: http://pagesofinterest.net/blog/2012/09/observing-all-nsnotifications-within-an-nsapp/
	}

	func newTabPrompt() {
		var alert = NSAlert()
		alert.messageText = "Open URL"
		alert.addButtonWithTitle("Go")
		alert.informativeText = "Type the address you wish to open a new tab to:"
		alert.icon = app?.applicationIconImage
		var input = NSTextField(frame: NSMakeRect(0, 0, 350, 24))
		input.stringValue = "http://"
		input.editable = true
 		alert.accessoryView = input
		
		alert.beginSheetModalForWindow(windowController.window!, completionHandler:{(response:NSModalResponse) -> Void in
			self.newAppTab(input.stringValue)
		})
	}

	func firstTab() -> NSTabViewItem? {
		if let tab = (viewController?.tabViewItems.first as? NSTabViewItem) { return tab }
		return nil
	}

	func firstTabEvalJS(js: String) { (firstTab()?.view as? WKWebView)?.evaluateJavaScript(js, completionHandler: nil) }

	func currentTab() -> NSTabViewItem? {
		if viewController!.selectedTabViewItemIndex != -1 {
			if let tab = (self.viewController?.tabViewItems[self.viewController!.selectedTabViewItemIndex] as? NSTabViewItem) { return tab }
		}
		return nil
	}

	func currentTabEvalJS(js: String) { (firstTab()?.view as? WKWebView)?.evaluateJavaScript(js, completionHandler: nil) }

	func closeCurrentTab() {
		if let tab = currentTab() { viewController?.removeTabViewItem(tab) }
		if viewController?.tabView.numberOfTabViewItems == 0 { windowController.window?.performClose(self) }
	}

	func switchToPreviousTab() { viewController?.tabView.selectPreviousTabViewItem(self) }
	func switchToNextTab() { viewController?.tabView.selectNextTabViewItem(self) }
	func switchToTab(idx: Int) { viewController?.tabView.selectTabViewItemAtIndex(idx) }

	func constrainViewsTogether(superview: NSView, _ subview: NSView) {
		subview.translatesAutoresizingMaskIntoConstraints = false
 		superview.addSubview(subview)
		superview.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|-0-[subview]-0-|", options:
			NSLayoutFormatOptions.DirectionLeadingToTrailing, metrics: nil, views: ["subview":subview]))
		superview.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|-0-[subview]-0-|", options:
			NSLayoutFormatOptions.DirectionLeadingToTrailing, metrics: nil, views: ["subview":subview]))
	}

    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<()>) {
		switch keyPath {
			case "title":
 				if let title = (object as NSTabViewController).title {
					windowController.window!.title = title
				}
			default:
				super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
		}
    }

	func showApplication(sender : AnyObject?) {

		windowController.shouldCascadeWindows = false // messes with Autosave
		if let window = windowController.window {
			window.cascadeTopLeftFromPoint(NSZeroPoint) // if window is not being restored from an Autosave, make sure it placed fully inside a screen
			window.collectionBehavior = .FullScreenPrimary | .ParticipatesInCycle | .Managed //.FullScreenAuxiliary | .MoveToActiveSpace 
			window.movableByWindowBackground = true
			window.backgroundColor = NSColor.whiteColor()
			window.opaque = true
			window.hasShadow = true

			window.toolbar = NSToolbar(identifier: "toolbar") //placeholder, will be re-init'd by NSTabViewController

			window.titleVisibility = .Hidden
			window.appearance = NSAppearance(named: NSAppearanceNameVibrantDark)

			//window.delegate = (windowController as NSWindowDelegate) //only if windowController is multiclassed to winDelegate
			//window.delegate = self

			window.title = NSProcessInfo.processInfo().processName
			app?.windowsMenu = NSMenu() 
			app?.addWindowsItem(window, title: window.title!, filename: false)
			
			window.identifier = "browser"
			//window.restorationClass = MacPin.self //NSWindowRestoration Protocol - not a multi-window app, so not needed yet
			window.setFrameAutosaveName(window.identifier) 
		}

		if viewController? == nil {
			viewController = NSTabViewController()
			viewController?.tabView = NSTabView()
			viewController?.tabView.identifier = "NSTabView"
			viewController?.tabView.tabViewType = .NoTabsNoBorder
			viewController?.tabView.drawsBackground = false // let the window be the background
			viewController?.tabView.wantsLayer = true //use CALayer to coalesce views
			viewController?.tabStyle = .Toolbar // this will reinit window.toolbar to mirror the tabview itembar
			viewController?.transitionOptions = .None //.Crossfade .SlideUp/Down/Left/Right/Forward/Backward

			viewController!.canPropagateSelectedChildViewControllerTitle = true
			viewController!.title = nil //will autofill/compute to selected tabView's title
			viewController!.addObserver(self, forKeyPath: "title", options: .Initial | .New, context: nil) //use KVO to copy updates to window.title

			viewController?.view.autoresizesSubviews = true
 			//viewController?.view.autoresizingMask = .ViewMinXMargin | .ViewWidthSizable | .ViewMaxXMargin | .ViewMinYMargin | .ViewHeightSizable | .ViewMaxYMargin
 			viewController?.view.autoresizingMask = .ViewWidthSizable | .ViewHeightSizable
		}

		//windowController.window!.contentView = viewController!.tabView; windowController.showWindow(sender); return
		//windowController.window!.contentView = viewController!.view; windowController.showWindow(sender); return

		let window = windowController.window!
		let tabview = viewController!.view		
		let cView = (window.contentView as NSView)
	
		tabview.frame = window.contentLayoutRect //make it fit the entire window +/- toolbar movement

		var blurView = NSVisualEffectView(frame: window.contentLayoutRect)
		blurView.blendingMode = .BehindWindow
		blurView.material = NSVisualEffectMaterial.AppearanceBased //.Dark .Light .Titlebar
		blurView.state = NSVisualEffectState.Active // set it to always be blurry regardless of window state
		//blurView.autoresizingMask = .ViewMinXMargin | .ViewWidthSizable | .ViewMaxXMargin | .ViewMinYMargin | .ViewHeightSizable | .ViewMaxYMargin
 		blurView.autoresizingMask = .ViewWidthSizable | .ViewHeightSizable

		//constrainViewsTogether(cView, blurView)
		//cView = blurView
		cView.autoresizesSubviews = true 
		cView.addSubview(blurView)
		cView.addSubview(viewController!.view)

		window.toolbar!.allowsUserCustomization = true
		window.showsToolbarButton = true //noop?
		//windowController.window!.toolbar!.insertItemWithItemIdentifier(, index: 0) //NSToolbarFlexibleSpaceItemIdentifier

		NSUserDefaults.standardUserDefaults().setBool(true, forKey: "NSQuitAlwaysKeepsWindows") // insist on Window-to-Space/fullscreen persistence between launches
		NSUserDefaults.standardUserDefaults().setInteger(0, forKey: "__WebInspectorPageGroupLevel1__.WebKit2InspectorStartsAttached") // FIXME: inline web inspectors get flickery

		windowController.showWindow(sender)
	}

	func toggleFullscreen() { windowController.window!.toggleFullScreen(nil) }
		//FIXME: super toggleFullScreen so that we can notify the webviews

	func toggleTransparency() {
		log("toggling transparency")
		isTransparent = !isTransparent
		let window: NSWindow = windowController.window!
		window.backgroundColor = window.backgroundColor.colorWithAlphaComponent(abs(window.backgroundColor.alphaComponent - 1)) // 0|1 flip-flop
		window.opaque = !window.opaque
		window.hasShadow = !window.hasShadow
		
		//if let webview = (currentTab()?.view as? WKWebView) { }
		for i in 0..<viewController!.tabView.numberOfTabViewItems {
			if let webview = (viewController!.tabViewItems[i].view as? WKWebView) {
				webview._drawsTransparentBackground = !webview._drawsTransparentBackground
				//^ background-color:transparent sites immediately bleedthru to a black CALayer, which won't go clear until the content is reflowed or reloaded
				webview.needsDisplay = true
				webview.setFrameSize(NSSize(width: webview.frame.size.width, height: webview.frame.size.height - 1)) //needed to fully redraw w/ dom-reflow or reload! 
				webview.evaluateJavaScript("window.dispatchEvent(new window.CustomEvent('macpinTransparencyChanged',{'detail':{'isTransparent': \(isTransparent)}}));", completionHandler: nil)
				webview.evaluateJavaScript("document.head.appendChild(document.createElement('style')).remove();", completionHandler: nil) //force redraw in case event didn't
			}
		}
		//window.titlebarAppearsTransparent = !window.titlebarAppearsTransparent //this also shifts the contentView to/from the top of the window @ the titlebar(+tools)
	}
	func stealAppFocus() { app?.activateIgnoringOtherApps(true) }
	func unhideApp() {
		stealAppFocus()
		app?.unhide(self)
		app?.arrangeInFront(self)
		windowController.window!.makeKeyAndOrderFront(nil)
	}
}

extension MacPin: NSWindowRestoration {
	class func restoreWindowWithIdentifier(identifier: String, state: NSCoder, completionHandler: ((NSWindow!,NSError!) -> Void)) {
		warn("restoreWindowWithIdentifier: \(identifier)") // state: \(state)")
		switch identifier {
			case "browser":
				var appdel = (NSApplication.sharedApplication().delegate as MacPin)
				completionHandler(appdel.windowController.window!, nil)
			default:
				//have app remake window from scratch
				completionHandler(nil, nil) //FIXME: should ret an NSError
		}
	}
}

extension MacPin: NSApplicationDelegate {

	//optional func applicationDockMenu(_ sender: NSApplication) -> NSMenu?

	func applicationShouldOpenUntitledFile(app: NSApplication) -> Bool { return false }

	func applicationWillFinishLaunching(notification: NSNotification) { // dock icon bounces, also before self.openFile(foo.bar) is called
		//var appleEventManager:NSAppleEventManager = NSAppleEventManager.sharedAppleEventManager()
		//appleEventManager.setEventHandler(self, andSelector: "handleGetURLEvent:replyEvent:", forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL))
		//FIXME: ^ defer the GetURL event until jsapi is ready?

		NSUserNotificationCenter.defaultUserNotificationCenter().delegate = self;
		app = notification.object as? NSApplication
		
		//NSApp.registerServicesMenuSendTypes(sendTypes:[.kUTTypeFileURL], returnTypes:nil) //needed for URL drag-n-drop?
		// http://stackoverflow.com/questions/20461351/how-do-i-enable-services-which-operate-on-selected-files-and-folders

		var menuBar = NSMenu()
		app!.mainMenu = menuBar
		var appMenu = NSMenuItem()
		menuBar.addItem(appMenu) // shows up as CFPrintableName
		var appSubmenu = NSMenu()
		appMenu.submenu = appSubmenu

		appSubmenu.addItem( NSMenuItem(
			title: "Quit \(NSProcessInfo.processInfo().processName)",
		    action: Selector("terminate:"), //NSApp scope
		    keyEquivalent: "q"
		))
		appSubmenu.addItem( NSMenuItem(
			title: "About",
		    action: Selector("orderFrontStandardAboutPanel:"),
		    keyEquivalent: ""
		))
		appSubmenu.addItem( NSMenuItem(
			title: "",
		    action: Selector("toggleFullScreen:"),
		    keyEquivalent: ""
		))
		appSubmenu.addItem( NSMenuItem(
			title: "Toggle Translucency",
		    action: Selector("toggleTransparency"),
		    keyEquivalent: ""
		))
		appSubmenu.addItem( NSMenuItem(
			title: "",
		    action: Selector("toggleToolbarShown:"),
		    keyEquivalent: ""
		))

		appSubmenu.addItem( NSMenuItem(
			title: "Print",
		    action: Selector("print:"),
		    keyEquivalent: ""
		))

		/*
		appSubmenu.addItem( NSMenuItem(
			title: "Open Web Inspector",
		    action: Selector("showConsole:"),
		    keyEquivalent: ""
		))
		*/
	
		var cmd_menus = [
			NSMenuItem(
				title: "Reload",
			    action: Selector("reloadFromOrigin:"),
		    keyEquivalent: "R"
			),
			NSMenuItem(
				title: "Close Tab",
			    action: Selector("closeCurrentTab"),
			    keyEquivalent: "w"
			),
			NSMenuItem(
				title: "New Tab to URL...",
			    action: Selector("newTabPrompt"),
			    keyEquivalent: "t"
			),
			NSMenuItem(
				title: "Next Tab",
			    action: Selector("selectNextTabViewItem:"),
			    keyEquivalent: ""
				// NSTabCharacter //ctrl 
			),
			NSMenuItem(
				title: "Previous Tab",
			    action: Selector("selectPreviousTabViewItem:"),
			    keyEquivalent: ""
				// NSTabCharacter //ctrl-shift
			)
		]
		for mi in cmd_menus {
			mi.keyEquivalentModifierMask = Int(NSEventModifierFlags.CommandKeyMask.rawValue)
			appSubmenu.addItem(mi)
		}

		showApplication(self) //configure window and view controllers
	}

    func applicationDidFinishLaunching(notification: NSNotification?) { //dock icon stops bouncing
		//if !application?.currentTab //no tabs loaded yet, this was a cold app opening
		_jscore.setObject(self, forKeyedSubscript: "$") //export the application as $
		//_jscore.setObject(WebApp.self, forKeyedSubscript: "WebApp")
		_jscore.exceptionHandler = { context, exception in
			warn("JSCore Error: \(exception)")
		}


		if countElements(Process.arguments) > 1 { // got argv
			var url = Process.arguments[1] ?? "about:blank"
			log("loading initial page from argv[1]: \(url)")
			newAppTab(url)
		} else if let app_js = NSBundle.mainBundle().URLForResource("app", withExtension: "js") {
			log("loading setup script from app bundle: \(app_js)")
			_jsapi = loadJSCoreScriptFromBundle("app")
			// syntax similar to: https://developer.apple.com/library/mac/releasenotes/InterapplicationCommunication/RN-JavaScriptForAutomation/index.html
		} else if let default_html = NSBundle.mainBundle().URLForResource("default", withExtension: "html") {
			log("loading initial page from app bundle: \(default_html)")
			var webview = newWebView(default_html)
			//webview.loadFileURL(default_html, allowingReadAccessToURL: default_html.URLByDeletingLastPathComponent!) //http://trac.webkit.org/changeset/174029/trunk
			//webview._addOriginAccessWhitelistEntry(WithSourceOrigin:destinationProtocol:destinationHost:allowDestinationSubdomains:) // need to allow loads from file:// to inject NSBundle's CSS
			newTab(webview)
		} else { //test mode
			//_jscore.evaluateScript("$.toggleTransparency(); $.newAppTab('about:blank', [], [], []);")
			//newAppTab("about:blank")
			newTabPrompt()
		}
    }

	func applicationDidBecomeActive(notification: NSNotification) {
		//if application?.orderedDocuments?.count < 1 { showApplication(self) }
	}

	func applicationWillTerminate(notification: NSNotification) {
		//windowController.window?.saveFrameUsingName(windowController.window!.identifier)
		NSUserDefaults.standardUserDefaults().synchronize()
	}
    
	func applicationShouldTerminateAfterLastWindowClosed(app: NSApplication) -> Bool { return true }

}

extension MacPin: NSUserNotificationCenterDelegate {
	func userNotificationCenter(center: NSUserNotificationCenter, didActivateNotification notification: NSUserNotification) {
		let url = notification.subtitle ?? ""
		log("got notify callback for: \(url)")
		NSWorkspace.sharedWorkspace().openURL(NSURL(string: url)!)
		//_jsapi?.invokeMethod("handleClickedNotification", withArguments: [notification.title, notification.subtitle, notification.informativeText])
	}

	func userNotificationCenter(center: NSUserNotificationCenter, shouldPresentNotification notification: NSUserNotification) -> Bool { return true }
}

extension MacPin: WKUIDelegate {

	func webView(webView: WKWebView!, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: () -> Void) {
		log("JS window.alert() -> \(message)")
		var alert = NSAlert()
		alert.messageText = webView.title
		alert.addButtonWithTitle("Dismiss")
		alert.informativeText = message
		alert.icon = app?.applicationIconImage
		alert.alertStyle = .InformationalAlertStyle // .Warning .Critical
		alert.beginSheetModalForWindow(windowController.window!, completionHandler:{(response:NSModalResponse) -> Void in
			completionHandler()
 		})
	}

	func webView(webView: WKWebView!, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: (Bool) -> Void) {
		log("JS window.confirm() -> \(message)")
		var alert = NSAlert()
		alert.messageText = webView.title
		alert.addButtonWithTitle("OK")
		alert.addButtonWithTitle("Cancel")
		alert.informativeText = message
		alert.icon = app?.applicationIconImage
		alert.beginSheetModalForWindow(windowController.window!, completionHandler:{(response:NSModalResponse) -> Void in
			completionHandler(response == NSAlertFirstButtonReturn ? true : false)
 		})
	}

	func webView(webView: WKWebView!, runJavaScriptTextInputPanelWithPrompt prompt: String, defaultText: String?, initiatedByFrame frame: WKFrameInfo, completionHandler: (String!) -> Void) {
		log("JS window.prompt() -> \(prompt)")
		var alert = NSAlert()
		alert.messageText = webView.title
		alert.addButtonWithTitle("Submit")
		alert.informativeText = prompt
		alert.icon = app?.applicationIconImage
		var input = NSTextField(frame: NSMakeRect(0, 0, 200, 24))
		input.stringValue = ""
		input.editable = true
 		alert.accessoryView = input
		alert.beginSheetModalForWindow(windowController.window!, completionHandler:{(response:NSModalResponse) -> Void in
			completionHandler(input.stringValue)
 		})
	}
}

extension MacPin: WKScriptMessageHandler {
	func userContentController(userContentController: WKUserContentController, didReceiveScriptMessage message: WKScriptMessage) {
		// FIXME: check message.webView.location to make sure we have not been led to a malicious URL thats calling into this app
		//message.frameInfo //message.webView

		//called from JS: webkit.messageHandlers.<messsage.name>.postMessage(<message.body>);
		switch message.name {
			default:
				log("JS \(message.name)() -> \(message.body)")
				if let delegate = _jsapi?.hasProperty(message.name) {
					if (delegate) {
						warn("sending webkit.messageHandlers.\(message.name) to JSCore: postMessage(\(message.body))")
						_jsapi?.invokeMethod(message.name, withArguments: [message.body])
					 }
				}
		}//-message.name
	}
}

extension MacPin: WKNavigationDelegate {

	func webView(webView: WKWebView!, decidePolicyForNavigationAction navigationAction: WKNavigationAction, decisionHandler: (WKNavigationActionPolicy) -> Void) {
		let sys = NSWorkspace.sharedWorkspace()
		let url = navigationAction.request.URL

		// not registering this scheme globally for inter-app deep-linking, but maybe use it with buttons added to DOM
		if url.scheme! == "macpin" {
			switch url.resourceSpecifier! {
				case "resizeTo": fallthrough
				default:
    	        	decisionHandler(.Cancel)
			}
		}

		if let allow = (_jsapi?.invokeMethod("decideNavigationForURL", withArguments: [url.description]).toObject() as? Bool) {
			if !allow { decisionHandler(.Cancel); return }
		}

		//log("WebView decidePolicy() navType:\(navigationAction.navigationType.rawValue) sourceFrame:(\(navigationAction.sourceFrame?.request.URL)) -> \(url)")
		switch navigationAction.navigationType {
			case .LinkActivated:
				let mousebtn = navigationAction.buttonNumber
				let modkeys = navigationAction.modifierFlags
				if (modkeys & NSEventModifierFlags.AlternateKeyMask).rawValue != 0 { sys.openURL(url) } //alt-click
				else if (modkeys & NSEventModifierFlags.CommandKeyMask).rawValue != 0 { newTab(newWebView(url)) } //cmd-click
				else if navigationAction.targetFrame != nil && mousebtn == 1 { fallthrough } // left-click on in_frame target link
				//else if let allow = _jsapi?.invokeMethod("navaction_for_clicked_link", withArguments: [url,mousebtn,modkeys]) { (allow.toObject() as? String) == 'newtab' } 
				else { newTab(newWebView(url)) } // middle-click to open new tab, or out of frame target link
				log("webView.decidePolicy() -> .Cancel -- user clicked <a href=\(url) target=_blank> or middle-clicked: opening externally")
    	        decisionHandler(.Cancel)
			case .FormSubmitted: fallthrough
			case .BackForward: fallthrough
			case .Reload:
				//log("webView.decidePolicy() -> .Reload \(url) -- reloding all userscripts!")
 				fallthrough
			case .FormResubmitted: fallthrough
			case .Other: fallthrough
			default:
				log("webView.decidePolicy() -> .Allow \(url)")
	        	decisionHandler(.Allow) // -> self._webview.loadRequest(navigationAction.request)
		}
	}

/*
- (void)webView:(WebView *)sender printFrameView:(WebFrameView *)frameView {
  NSPrintOperation *printOperation = [frameView printOperationWithPrintInfo:[NSPrintInfo sharedPrintInfo]];
  [printOperation runOperation];
}
*/

	func webView(webView: WKWebView!, decidePolicyForNavigationResponse navigationResponse: WKNavigationResponse, decisionHandler: (WKNavigationResponsePolicy) -> Void) {
		let mime = navigationResponse.response.MIMEType!
		let url = navigationResponse.response.URL!
		let fn = navigationResponse.response.suggestedFilename!
		//log("webView.decidePolicyForNavigationResponse() MIME-type:\(mime) @ \(url)")

		if let allow = (_jsapi?.invokeMethod("decideNavigationForMIME", withArguments: [mime, url.description]).toObject() as? Bool) {
			if !allow { decisionHandler(.Cancel); return }
		} //FIXME perf hit?

		if navigationResponse.canShowMIMEType { decisionHandler(.Allow) } else { log("webView cannot render requested MIME-type:\(mime) @ \(url)") }
	}

	func webView(webView: WKWebView, didFailNavigation navigation: WKNavigation!, withError error: NSError) {
		log("webView.didFailNavigation() \(webView.URL ?? String()) ->! \(error.localizedDescription)!")
    }

	func webView(webView: WKWebView!, didCommitNavigation navigation: WKNavigation!) { } //FIXME, nail down timing of this func

	func webView(webView: WKWebView!, didFinishNavigation navigation: WKNavigation!) {
		log("webView.didFinishNavigation() \"\(webView.title ?? NSString())\" [\(webView.URL ?? String())]")

		if let tab = getTabContainingView(webView) {
			tab.label = webView.title!
			tab.viewController!.title = webView.title! //should map to viewController.title when tab is selected
					//RDAR? setting title of active tab will not KVO-propagate it. have to swap out-and-back into tab to push the change
			tab.toolTip = "\(webView.title!) [\(webView.URL!)]"
			if let curTab = currentTab() { 
				if webView.identifier == (curTab.identifier as NSString) { //this is the currently selected tab
					windowController.window!.title = webView.title! //Workaround for KVO non-propagation
				}
			}
		}

	
		webView.evaluateJavaScript("window.dispatchEvent(new window.CustomEvent('macpinTransparencyChanged',{'detail':{'isTransparent': \(isTransparent)}})); ", completionHandler: nil)
	}
	
	func webView(webView: WKWebView!, createWebViewWithConfiguration configuration: WKWebViewConfiguration, forNavigationAction navigationAction: WKNavigationAction,
                windowFeatures: WKWindowFeatures) -> WKWebView? {
		// called via JS:window.open()
		// https://developer.mozilla.org/en-US/docs/Web/API/window.open
		// https://developer.apple.com/library/prerelease/ios/documentation/WebKit/Reference/WKWindowFeatures_Ref/index.html

		let window = windowController.window!
		var url = navigationAction.request.URL ?? NSURL(string:String())!
		var tgt = (navigationAction.targetFrame == nil) ? NSURL(string:String())! : navigationAction.targetFrame!.request.URL
		//^tgt is given as a string in JS and WKWebView synthesizes a WKFrameInfo from it _IF_ it matches an iframe title in the DOM
		// otherwise == nil
		var newframe = CGRect(
			x: CGFloat(windowFeatures.x ?? window.frame.origin.x as NSNumber),
			y: CGFloat(windowFeatures.y ?? window.frame.origin.y as NSNumber),
			width: CGFloat(windowFeatures.width ?? window.frame.size.width as NSNumber),
			height: CGFloat(windowFeatures.height ?? window.frame.size.height as NSNumber)
		)

		log("JS@\(navigationAction.sourceFrame?.request.URL ?? String()) window.open(\(url), \(tgt))")

		if let allow = (_jsapi?.invokeMethod("decideWindowOpenForURL", withArguments: [url.description]).toObject() as? Bool) { if !allow { return nil } }

		if url.description.isEmpty { // hey Apple, why isn't this an optional ?!
			log("url-less JS popup request!")
		} else if url.scheme!.hasPrefix("chrome-http") { //reroute iOS-style chrome-http and chrome-https schemes to Chrome.app
			log("redirecting JS popup to Chrome")
			self.sysOpenURL(((url.scheme!.hasSuffix("s") ? "https:" : "http:") + url.resourceSpecifier!), "com.google.Chrome")	
			//perhaps firing a Cocoa Share Extension would be more appropriate? deep-linking is spotty at best
		} else if url.description == "macpin:resizeTo" {
			 // WKWebView doesn't natively support window.resizeTo, use this target to simply resize existing NSWindow
			window.setFrame(newframe, display: true)
		} else if (windowFeatures.allowsResizing ?? 0) == 1 { 
			log("JS popup request with size settings, origin,size[\(newframe)]")
			windowController.window!.setFrame(newframe, display: true)
			var webview = newWebView(url, withAgent: webView._customUserAgent, withConfiguration: configuration)
			newTab(webview)
			log("window.open() completed for url[\(url)] origin,size[\(newframe)]")
			return webview // window.open() -> Window()
		} else if tgt.description.isEmpty { //target-less request, assuming == 'top' 
			webView.loadRequest(navigationAction.request)
		} else {
			log("redirecting JS popup to system browser")
			NSWorkspace.sharedWorkspace().openURL(url) //send to default browser
		}

		return nil //window.open() -> undefined
	}
}	

func main() {
	let app = NSApplication.sharedApplication() //connect to CG WindowServer, always accessible as var:NSApp
	app.setActivationPolicy(.Regular) //lets bundle-less binaries (`make test`) get app menu and fullscreen button
	let applicationDelegate = MacPin()
	app.delegate = applicationDelegate
	NSAppleEventManager.sharedAppleEventManager().setEventHandler(applicationDelegate, andSelector: "handleGetURLEvent:replyEvent:", forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL)) //handle `open url`
	app.run()
}

main()
