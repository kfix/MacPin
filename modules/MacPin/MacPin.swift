/*
	Joey Korkames (c)2015
	Special thanks to Google for its horrible Hangouts App on Chrome for OSX :-)
*/

import WebKit // https://github.com/WebKit/webkit/blob/master/Source/WebKit/mac/ChangeLog
import Foundation
import ObjectiveC
import JavaScriptCore //  https://github.com/WebKit/webkit/tree/master/Source/JavaScriptCore/API

@objc protocol WebAppScriptExports : JSExport { // '$' in app.js
	var isTransparent: Bool { get }
	var isFullscreen: Bool { get }
	var readyForClickedNotifications: Bool { get set }
	var lastLaunchedURL: String { get }
	var tabCount: Int { get }
	var tabSelected: AnyObject? { get set }
	var resourcePath: String { get }
	var globalUserScripts: [String] { get set } // list of postinjects that any new webview will get
	func conlog(msg: String)
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
	func newAppTab(urlstr: String, withJS: [String: [String]], _ icon: String?, _ agent: String?) -> String // $.newAppTabWithJS 
	func registerURLScheme(scheme: String)
	func postOSXNotification(title: String, _ subtitle: String?, _ msg: String)
	func sysOpenURL(urlstr: String, _ app: String?)
}


public class MacPin: NSObject, WebAppScriptExports  {
	var app: NSApplication? = nil //the OSX app we are delegating methods for

	var windowController = WindowController(window: NSWindow(
		contentRect: NSMakeRect(0, 0, 600, 800),
		styleMask: NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask | NSUnifiedTitleAndToolbarWindowMask | NSFullSizeContentViewWindowMask,
		backing: .Buffered,
		defer: true
	))

	var viewController = TabViewController() //also available as windowController.contentViewController

	var readyForClickedNotifications = true

	var isTransparent = false
	var isFullscreen: Bool { get { return (windowController.window?.contentView as NSView).inFullScreenMode } }

	var cornerRadius = CGFloat(0.0) // increment to put nice corners on the window

	var lastLaunchedURL = "" //deferment state for cold opening URLs

	var resourcePath: String { get { return ( NSBundle.mainBundle().resourcePath ?? String() ) } } // prepend file: ?

	var tabCount: Int { get { return viewController.tabViewItems.count } }

	var firstTab: NSTabViewItem? { get { return (viewController.tabViewItems.first as? NSTabViewItem) ?? nil }}

	var currentTab: NSTabViewItem? { get {
		if viewController.selectedTabViewItemIndex == -1 { return nil }
		return (self.viewController.tabViewItems[self.viewController.selectedTabViewItemIndex] as? NSTabViewItem) ?? nil
	}}

	func firstTabEvalJS(js: String) { firstTab?.webview?.evaluateJavaScript(js, completionHandler: nil) }
	func currentTabEvalJS(js: String) { currentTab?.webview?.evaluateJavaScript(js, completionHandler: nil) }

	/* var tabSelected: Int { // the number goes stale when tabs are removed and rearranged
		get { return viewController.selectedTabViewItemIndex }
		set(idx) { viewController.tabView.selectTabViewItemAtIndex(idx) }
	}*/

	var tabSelected: AnyObject? {
		get { return viewController.tabView.selectedTabViewItem?.identifier }
		set(id) { viewController.tabView.selectTabViewItemWithIdentifier(id!) }
	}

	var _webprefs: WKPreferences {
		get {
			var prefs = WKPreferences() // http://trac.webkit.org/browser/trunk/Source/WebKit2/UIProcess/API/Cocoa/WKPreferences.mm
			prefs.plugInsEnabled = true // NPAPI for Flash, Java, Hangouts
			//prefs.minimumFontSize = 14 //for blindies
			prefs.javaScriptCanOpenWindowsAutomatically = true;
			prefs._developerExtrasEnabled = true // http://trac.webkit.org/changeset/172406 will land in OSX 10.10.3?
#if WK2LOG
			//prefs._diagnosticLoggingEnabled = true //10.10.3?
#endif
			return prefs
		}
	}

	var _globalUserScripts: [String] = []
	var globalUserScripts: [String] { // protect the app from bad JS settings?
		get { return self._globalUserScripts }
		set(newarr) { self._globalUserScripts = newarr }
	}

	//var defaultUserAgent: String {
	//	get { }
	//	set(ua) { NSUserDefaults.standardUserDefaults().setString(ua, forKey: "UserAgent") } //only works on IOS
	//} // https://github.com/WebKit/webkit/blob/master/Source/WebCore/page/NavigatorBase.cpp
	// https://github.com/WebKit/webkit/blob/master/Source/WebCore/page/mac/UserAgentMac.mm

	var _jsctx: JSContext?
	var _jsapi = JSContext().evaluateScript("{};")! //default property-less delegate obj

    override public init() { }

	func conlog(msg: String) {
#if APP2JSLOG
		firstTabEvalJS("console.log(\'\(reflect(self).summary): \(msg)\')")
#endif
		warn(msg)
	}

	func loadJSCoreScriptFromBundle(basename: String) -> JSValue? {
		if let script_url = NSBundle.mainBundle().URLForResource(basename, withExtension: "js") {
			let script = NSString(contentsOfURL: script_url, encoding: NSUTF8StringEncoding, error: nil)!
			return _jsctx?.evaluateScript(script, withSourceURL: script_url)
		}
		return nil
	}

	func loadUserScriptFromBundle(basename: String, webctl: WKUserContentController, inject: WKUserScriptInjectionTime, onlyForTop: Bool = true) -> Bool {
		if let script_url = NSBundle.mainBundle().URLForResource(basename, withExtension: "js") {
			conlog("loading userscript: \(script_url)")
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

	func sysOpenURL(urlstr: String, _ appid: String? = nil) {
		if let url = NSURL(string: urlstr) {
			NSWorkspace.sharedWorkspace().openURLs([url], withAppBundleIdentifier: appid, options: .AndHideOthers, additionalEventParamDescriptor: nil, launchIdentifiers: nil)
			//options: .Default .NewInstance .AndHideOthers
		//open -a "Google Chrome.app" --args --kiosk @url ....  // --args only works if the process isn't already running
		// launchurl = LSLaunchURLSpec(appURL: nil, itemURLs: url, launchFlags: .kLSLaunchDefualts)
		// LSOpenFromURLSpec(inLaunchSpec: launchurl, outLaunchedURL: nil)
		// https://src.chromium.org/svn/trunk/src/chrome/browser/app_controller_mac.mm
		}
	}

	func askToOpenURL(url: NSURL) {
		conlog("prompting to Open URL: [\(url)]")
		var alert = NSAlert()
		alert.messageText = "Open URL with App?"
		alert.addButtonWithTitle("OK")
		alert.addButtonWithTitle("Cancel")
		alert.informativeText = url.description
		alert.icon = app?.applicationIconImage
		alert.beginSheetModalForWindow(windowController.window!, completionHandler:{(response:NSModalResponse) -> Void in
			if response == NSAlertFirstButtonReturn { NSWorkspace.sharedWorkspace().openURL(url) }
 		})
	}

/*
	func handleGetURLEvent(event: NSAppleEventDescriptor!, replyEvent: NSAppleEventDescriptor?) {
		var url = NSURLComponents(string: event.paramDescriptorForKeyword(AEKeyword(keyDirectObject))!.stringValue!)!
		conlog("OSX is asking me to launch \(url.URL!)")
		var addr = url.path? ?? ""
		switch url.scheme? ?? "" {
			case "macpin-http", "macpin-https":
				url.scheme = url.scheme!.hasSuffix("s") ? "https:" : "http:"
        		newAppTab(url.URL!.description)
			default:
				lastLaunchedURL = url.URL!.description // in case jsapi or site's remote JS isn't finished loading yet, like `open uri://blah` when app is closed
				conlog("Dispatching OSX-app-launched URL to JSCore: launchURL(\(url.URL!))")
				_jsapi.tryFunc("launchURL", url.URL!.description)
		}
		//replyEvent == ??
	}
*/

	func handleGetURLEvent(event: NSAppleEventDescriptor!, replyEvent: NSAppleEventDescriptor?) {
		if let url = event.paramDescriptorForKeyword(AEKeyword(keyDirectObject))!.stringValue {
			conlog("OSX is asking me to launch \(url)")
			lastLaunchedURL = url // in case jsapi or site's remote JS isn't finished loading yet, like `open uri://blah` when app is closed
			conlog("Dispatching OSX-app-launched URL to JSCore: launchURL(\(url))")
			_jsapi.tryFunc("launchURL", url)
			//replyEvent == ??
		}
		//replyEvent == ??
	}

	func newTab(withView: NSView, withIcon: String? = nil) -> String {
		var tab = NSTabViewItem(viewController: NSViewController())
		tab.viewController!.view = withView 
		//withView.translatesAutoresizingMaskIntoConstraints = false
		//withView.autoresizingMask = .ViewMinXMargin | .ViewMaxXMargin | .ViewMinYMargin | .ViewMaxYMargin
		//withView.autoresizingMask |= .ViewWidthSizable | .ViewHeightSizable
		//withView.autoresizingMask = .ViewMinYMargin | .ViewMaxYMargin
		withView.wantsLayer = true
		withView.layer?.cornerRadius = cornerRadius
		withView.layer?.masksToBounds = true

		tab.image = app?.applicationIconImage
		if let icon = withIcon? {
			if !icon.isEmpty { tab.image = NSImage(byReferencingURL: NSURL(string: icon)!) }
			//need 24 & 36px**2 representations for the NSImage
			// https://developer.apple.com/library/ios/documentation/AppleApplications/Reference/SafariWebContent/ConfiguringWebApplications/ConfiguringWebApplications.html
			// just C, no Cocoa API yet: WKIconDatabaseCopyIconURLForPageURL(icodb, url) WKIconDatabaseCopyIconDataForPageURL(icodb, url)
		}

		tab.identifier = withView.identifier //NSUserInterfaceItemIdentification

		tab.watchWebview()
		viewController.addTabViewItem(tab)
		return (tab.identifier as? String) ?? "worthless non-unique identifer" // Cocoa serializer?
	}

	func newWebView(url: NSURL, withAgent: String? = nil, withConfiguration: WKWebViewConfiguration = WKWebViewConfiguration()) -> WKWebView {
		withConfiguration.preferences = _webprefs
		withConfiguration.suppressesIncrementalRendering = false
		//withConfiguration._websiteDataStore = _WKWebsiteDataStore.nonPersistentDataStore

		var webview = WKWebView(frame: CGRectZero, configuration: withConfiguration)
		webview.allowsBackForwardNavigationGestures = true
		webview.allowsMagnification = true
		webview._drawsTransparentBackground = isTransparent
#if SAFARIDBG
		webview._allowsRemoteInspection = true
		// enables Safari.app->Develop-><computer name> remote debugging of JSCore and all webviews' JS threads
#endif

		// https://github.com/WebKit/webkit/blob/master/Source/WebCore/page/mac/UserAgentMac.mm#L48
		webview._applicationNameForUserAgent = "Version/8.0.2 Safari/600.2.5"
		if let agent = withAgent? { if !agent.isEmpty { webview._customUserAgent = agent } }

		webview.navigationDelegate = self // allows/denies navigation actions
		webview.UIDelegate = self //alert(), window.open()	

		var wkview = (webview.subviews.first as WKView) // 1 per frame?
		//wkview.shouldExpandToViewHeightForAutoLayout = false
		//wkview.setValue(false, forKey: "shouldExpandToViewHeightForAutoLayout") //KVO

		if url.scheme == "file" {
			//webview.loadFileURL(url, allowingReadAccessToURL: url.URLByDeletingLastPathComponent!) //load file and allow link access to its parent dir
			//		waiting on http://trac.webkit.org/changeset/174029/trunk to land
			//webview._addOriginAccessWhitelistEntry(WithSourceOrigin:destinationProtocol:destinationHost:allowDestinationSubdomains:)
			// need to allow loads from file:// to inject NSBundle's CSS
		}

		webview.loadRequest(NSURLRequest(URL: url))
		webview.identifier = "WKWebView" + NSUUID().UUIDString //set before installing into a view/window, then get ... else crash!
		return webview
    }

	func newAppTab(urlstr: String, withJS: [String: [String]] = [:], _ icon: String? = nil, _ agent: String? = nil) -> String {
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
		if let cell = viewController.urlbox.cell() as? NSSearchFieldCell { cell.recentSearches.append(urlstr) } //FIXME until WKNavigation is fixed
		var webview = newWebView(NSURL(string: urlstr)!, withAgent: agent, withConfiguration: webcfg)
		return newTab(webview, withIcon: icon)
	}

	func registerURLScheme(scheme: String) {
		LSSetDefaultHandlerForURLScheme(scheme, NSBundle.mainBundle().bundleIdentifier);
		conlog("registered URL handler in OSX: \(scheme)")

		//NSApp.registerServicesMenuSendTypes(sendTypes:[.kUTTypeFileURL], returnTypes:nil)
		// http://stackoverflow.com/questions/20461351/how-do-i-enable-services-which-operate-on-selected-files-and-folders
	}

	func postOSXNotification(title: String, _ subtitle: String?, _ msg: String) {
		var note = NSUserNotification()
		note.title = title
		note.subtitle = subtitle ?? "" //empty strings wont be displayed
		note.informativeText = msg
		//note.contentImage = ?bubble pic?

		//note.hasReplyButton = true
		//note.hasActionButton = true
		//note.responsePlaceholder = "say something stupid"

		note.soundName = NSUserNotificationDefaultSoundName // something exotic?
		NSUserNotificationCenter.defaultUserNotificationCenter().deliverNotification(note)
		// these can be listened for by all: http://pagesofinterest.net/blog/2012/09/observing-all-nsnotifications-within-an-nsapp/
	}

	func newTabPrompt() {
		tabSelected = newAppTab("about:blank")
		focusOnURLBox()
	}

	func validateURL(urlstr: String) -> NSURL? {
		// https://github.com/WebKit/webkit/blob/master/Source/WebKit/ios/Misc/WebNSStringExtrasIOS.m
		if urlstr.isEmpty { return nil }
		if let urlp = NSURLComponents(string: urlstr) {
			if !((urlp.path ?? "").isEmpty) && (urlp.scheme ?? "").isEmpty && (urlp.host ?? "").isEmpty { // 'example.com' & 'example.com/foobar'
				// starts with '/' or '~/': scheme = "file"
				urlp.scheme = "http"
				urlp.host = urlp.path
				urlp.path = nil
			}
			if let url = urlp.URL { return url }
		}

		if _jsapi.tryFunc("handleUserInputtedInvalidURL", urlstr) { return nil } // the delegate function will open url directly

		// maybe its a search query? check if blank and reformat it
		if !urlstr.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()).isEmpty {
			if let query = urlstr.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding) {
				if let search = NSURL(string: "https://duckduckgo.com/?q=\(query)") { return search }
			}
		}

		return nil 
	}
	
	func gotoURL(sender: AnyObject?) {
		if let sf = sender as? NSTextField {
			if let url = validateURL(sf.stringValue) {
				if let cell = sf.cell() as? NSSearchFieldCell { cell.recentSearches.append(url.description) }
				if tabCount < 1 {
					newAppTab(url.description)
				} else if let webview = (currentTab?.view as? WKWebView) {
					webview.loadRequest(NSURLRequest(URL: url))
				}
			}
		}
	}

	func closeCurrentTab() {
		if let tab = currentTab { 
			tab.unwatchWebview()
			viewController.removeTabViewItem(tab)
		 }
		if viewController.tabView.numberOfTabViewItems == 0 { windowController.window?.performClose(self) }
	}

	func switchToPreviousTab() { viewController.tabView.selectPreviousTabViewItem(self) }
	func switchToNextTab() { viewController.tabView.selectNextTabViewItem(self) }

	func zoomIn() { if let webview = currentTab?.webview { webview.magnification += 0.2 } }
	func zoomOut() { if let webview = currentTab?.webview { webview.magnification -= 0.2 } }

	func toggleFullscreen() { windowController.window!.toggleFullScreen(nil) } //FIXME: super toggleFullScreen so that we can notify the webviews

	func toggleTransparency() {
		conlog("toggling transparency")
		isTransparent = !isTransparent
		if let window = windowController.window {
			window.backgroundColor = window.backgroundColor.colorWithAlphaComponent(abs(window.backgroundColor.alphaComponent - 1)) // 0|1 flip-flop
			window.opaque = !window.opaque
			window.hasShadow = !window.hasShadow
			window.toolbar!.showsBaselineSeparator = !window.toolbar!.showsBaselineSeparator //super flat
		}

		/*
		if let webview = (currentTab?.view as? WKWebView) {
			webview.retain()
			webview.removeFromSuperView()
			currentTab!.view = webview // .addSubview(webview)
 		}
		*/

		for i in 0..<viewController.tabView.numberOfTabViewItems {
			if let webview = (viewController.tabViewItems[i].view as? WKWebView) {
				webview._drawsTransparentBackground = !webview._drawsTransparentBackground
				//^ background-color:transparent sites immediately bleedthru to a black CALayer, which won't go clear until the content is reflowed or reloaded
				webview.needsDisplay = true
				webview.setFrameSize(NSSize(width: webview.frame.size.width, height: webview.frame.size.height - 1)) //needed to fully redraw w/ dom-reflow or reload! 
				webview.evaluateJavaScript("window.dispatchEvent(new window.CustomEvent('macpinTransparencyChanged',{'detail':{'isTransparent': \(isTransparent)}}));", completionHandler: nil)
				webview.evaluateJavaScript("document.head.appendChild(document.createElement('style')).remove();", completionHandler: nil) //force redraw in case event didn't
			}
		}
		//window.titlebarAppearsTransparent = !window.titlebarAppearsTransparent //this shifts the contentView between the top and bottom edges of the title(+tool)bar
	}

	func stealAppFocus() { app?.activateIgnoringOtherApps(true) }
	func unhideApp() {
		stealAppFocus()
		app?.unhide(self)
		app?.arrangeInFront(self)
		windowController.window!.makeKeyAndOrderFront(nil)
	}

	func focusOnURLBox() { windowController.window!.makeFirstResponder(viewController.urlbox) }

	func shareButton(sender: AnyObject) {
		if let btn = sender as? NSView {
			if let url = currentTab?.URL {
				var sharer = NSSharingServicePicker(items: [url] )
				sharer.delegate = self
				sharer.showRelativeToRect(sender.bounds, ofView: btn, preferredEdge: NSMinYEdge)
			}
		}
	}

	func loadSiteApp() {
		if let app_js = NSBundle.mainBundle().URLForResource("app", withExtension: "js") {
			// re-init jsapi with a referenced VM context so we can load files into it
			_jsctx = JSContext(virtualMachine: JSVirtualMachine())
			_jsctx!.setObject(self, forKeyedSubscript: "$") //export this class as $
			_jsapi = _jsctx!.evaluateScript("{};") //default property-less delegate obj

			// https://bugs.webkit.org/show_bug.cgi?id=122763 -- allow evaluteScript to specify source URL
			_jsctx!.exceptionHandler = { context, exception in
				//warn("\(context.name) <\(app_js)> (\(context.currentCallee)) \(context.currentThis): \(exception)")
				self.conlog("\(app_js):Ln: \(exception)") // FIXME need a line number!
				context.exception = exception //default in JSContext.mm
				return // gets returned to evaluateScript()?
			} 
			conlog("loading setup script from app bundle: \(app_js)")
			_jsapi = loadJSCoreScriptFromBundle("app")! // FIXME: check that we received a delegate object at end of script
			_jsapi.tryFunc("AppFinishedLaunching")
		}

		if let default_html = NSBundle.mainBundle().URLForResource("default", withExtension: "html") {
			conlog("loading initial page from app bundle: \(default_html)")
			newTab(newWebView(default_html))
		}

		if countElements(Process.arguments) > 1 { // got argv
			//windowController.window.toolbar!.insertItemWithItemIdentifier(URLBox, atIndex: 0)
			var url = Process.arguments[1] ?? "about:blank"
			conlog("loading initial page from argv[1]: \(url)")
			newAppTab(url)
		}

		if tabCount < 1 { focusOnURLBox() }
	}
	
	func editSiteApp() { NSWorkspace.sharedWorkspace().openFile(resourcePath) }
}

