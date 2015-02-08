/*
	Joey Korkames (c)2015
	Special thanks to Google for its horrible Hangouts App on Chrome for OSX :-)
*/

import WebKit // https://github.com/WebKit/webkit/blob/master/Source/WebKit/mac/ChangeLog
import Foundation
import ObjectiveC
import JavaScriptCore //  https://github.com/WebKit/webkit/tree/master/Source/JavaScriptCore/API

func warn(msg:String) { NSFileHandle.fileHandleWithStandardError().writeData((msg + "\n").dataUsingEncoding(NSUTF8StringEncoding)!) }

let URLBoxId = "urlbox"
let ShareButton = "sharing"

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

extension NSPasteboard {
	func dump() {
		if let items = self.pasteboardItems {
			for item in items {
				warn("\n")
				if let types = item.types? {
					warn(types.description)
					for uti in types { // https://developer.apple.com/library/mac/documentation/MobileCoreServices/Reference/UTTypeRef/
						if !uti.description.isEmpty {
							if let value = item.stringForType(uti.description) {
								if var cftype = UTTypeCopyDescription(uti as CFString) {
									var type = cftype.takeUnretainedValue() 
									warn("DnD: uti(\(uti)) [\(type)] = '\(value)'")
								} else if var cftag = UTTypeCopyPreferredTagWithClass(uti as CFString, kUTTagClassNSPboardType) {
									var tag = cftag.takeUnretainedValue()
									warn("DnD: uti(\(uti)) <\(tag)> = '\(value)'")
								} else if var cftag = UTTypeCopyPreferredTagWithClass(uti as CFString, kUTTagClassMIMEType) {
									var tag = cftag.takeUnretainedValue()
									warn("DnD: uti(\(uti)) {\(tag)} = '\(value)'")
								} else {
									warn("DnD: uti(\(uti)) = '\(value)'")
								} //O
							} //M
						} //G
					} //W
				} //T
			} //F
		} // PewPewDIE!@#$!$#!@
	}
}

extension WKView {
	//override public func draggingEntered(sender: NSDraggingInfo) -> NSDragOperation { return NSDragOperation.Every }

	/* overide func _registerForDraggedTypes() {
		// https://github.com/WebKit/webkit/blob/f72e25e3ba9d3d25d1c3a4276e8dffffa4fec4ae/Source/WebKit2/UIProcess/API/mac/WKView.mm#L3653
		self.registerForDraggedTypes([ // https://github.com/WebKit/webkit/blob/master/Source/WebKit2/Shared/mac/PasteboardTypes.mm [types]
			// < forEditing 
			WebArchivePboardType, NSHTMLPboardType, NSFilenamesPboardType, NSTIFFPboardType, NSPDFPboardType,
		    NSURLPboardType, NSRTFDPboardType, NSRTFPboardType, NSStringPboardType, NSColorPboardType, kUTTypePNG,
			// < forURL
			WebURLsWithTitlesPboardType, //webkit proprietary 
			NSURLPboardType, // single url from older apps and Chromium -> text/uri-list
			WebURLPboardType, //webkit proprietary: public.url
			WebURLNamePboardType, //webkit proprietary: public.url-name
			NSStringPboardType, // public.utf8-plain-text -> WKJS: text/plain
			NSFilenamesPboardType, // Finder -> text/uri-list & Files
		])
	} */

	// http://stackoverflow.com/a/25114813/3878712
	func shimmedPerformDragOperation(sender: NSDraggingInfo) -> Bool {
		//if sender.dragginginSource() == nil //dragged from external application
		var pboard = sender.draggingPasteboard()
		pboard.dump()

		if var urls = WebURLsWithTitles.URLsFromPasteboard(pboard) { //drops from Safari
			warn("DnD: WK URL array: \(urls)")
		} else if var file = pboard.dataForType("public.file-url") { //drops from Finder
			warn("DnD: files from finder")
		} else if var zip = pboard.dataForType("org.chromium.drag-dummy-type") { //Chromium
		//} else if "public.url" != (pboard.availableTypeFromArray(["public.url"]) ?? "") { //Chromium missing public-url

			// Chromium pastes need some massage for WebView to seamlessly open them, so imitate a Safari drag
			// https://github.com/WebKit/webkit/blob/master/Source/WebKit/mac/Misc/WebNSPasteboardExtras.mm#L118 conform to _web_bestURL()

			var apsfctype = pboard.dataForType("com.apple.pasteboard.promised-file-content-type")
			var apsfurl = pboard.dataForType("com.apple.pasteboard.promised-file-url")

			if let url = NSURL(fromPasteboard: pboard) { // NSURLPBoardType
				// https://github.com/WebKit/webkit/blob/53e0a1506a7b2408e86caa9f510477b5ee283487/Source/WebKit2/UIProcess/API/mac/WKView.mm#L3330 drag out
				// https://github.com/WebKit/webkit/search?q=datatransfer

				pboard.clearContents() // have to wipe it clean in order to modify

				pboard.addTypes(["WebURLsWithTitlesPboardType"], owner: nil)
				WebURLsWithTitles.writeURLs([url], andTitles: nil, toPasteboard: pboard)
				// https://github.com/WebKit/webkit/blob/master/Source/WebKit/mac/History/WebURLsWithTitles.h

				//pboard.addTypes([NSURLPboardType], owner: nil) // Apple URL pasteboard type -> text/url-list
				//url.writeToPasteboard(pboard) //deprecated from 10.6+
				// https://github.com/WebKit/webkit/blob/fb77811f2b8164ce4c34fc63b496519be15f55ca/Source/WebCore/platform/mac/PasteboardMac.mm#L543

				pboard.addTypes(["public.url"], owner: nil) // *WebURLPboardType http://uti.schwa.io/identifier/public.url
				pboard.setString(url.description, forType:"public.url") // -> public.url

				pboard.setString(url.description, forType:NSStringPboardType) // -> text/plain
				// https://github.com/WebKit/webkit/blob/fb77811f2b8164ce4c34fc63b496519be15f55ca/Source/WebCore/platform/mac/PasteboardMac.mm#L539

				if let ctype = apsfctype {
					pboard.addTypes(["com.apple.pasteboard.promised-file-content-type"], owner: nil)
					pboard.setData(ctype, forType:"com.apple.pasteboard.promised-file-content-type")
				}
				if let url = apsfurl {
					pboard.addTypes(["com.apple.pasteboard.promised-file-url"], owner: nil)
					pboard.setData(url, forType:"com.apple.pasteboard.promised-file-url")
				}

				//pboard.writeObjects([url])

				pboard.dump()
			}
		}

		return self.shimmedPerformDragOperation(sender) //return pre-swizzled method		
	}
}

extension JSValue {
	func tryFunc (method: String, _ args: AnyObject...) -> Bool {
		if self.hasProperty(method) {
			var ret = self.invokeMethod(method, withArguments: args)
			if let bool = ret.toObject() as? Bool { return bool }
			// exec passed closure here?
		}
		return false
	}
}

class URLBox: NSSearchField { //NSTextField
	var tab: NSTabViewItem? {
		didSet { //KVO to copy updates to webviews url & title (user navigations, history.pushState(), window.title=)
			if let newtab = tab { 
				newtab.webview?.addObserver(self, forKeyPath: "title", options: .Initial | .New, context: nil)
				newtab.webview?.addObserver(self, forKeyPath: "URL", options: .Initial | .New, context: nil)
			 }
		}
		willSet(newtab) { 
			if let oldtab = tab { 
				oldtab.webview?.removeObserver(self, forKeyPath: "title")
				oldtab.webview?.removeObserver(self, forKeyPath: "URL")
			 }
		}
	}

    override func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<()>) {
		switch keyPath {
			case "title": if let title = tab?.title { 
				toolTip = title
				if let window = window { window.title = title.isEmpty ? NSProcessInfo.processInfo().processName : title }
			};
			case "URL": if let URL = tab?.URL { stringValue = URL.description }
			default: super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context);
		}
    }

	deinit { tab = nil } // prevent crashing from left-behind KVO observers
}

extension NSTabViewItem {
	// convenience props to get webview pertinents
	var webview: WKWebView? { get {
		if let webview = viewController?.view as? WKWebView { return webview }
		return nil
	}}

	var URL: NSURL? { get { 
		if let webview = webview { return webview.URL }
		return nil
	}}

	var title: String? { get { 
		if let webview = webview { return webview.title }
		return nil
	}}

	func watchWebview() { //KVO to copy updates to webviews url & title (user navigations, history.pushState(), window.title=)
		if let webview = webview { 
			webview.addObserver(self, forKeyPath: "title", options: .Initial | .New, context: nil)
			webview.addObserver(self, forKeyPath: "URL", options: .Initial | .New, context: nil)
		 }
	}

	func unwatchWebview() { 
		if let webview = webview { 
			webview.removeObserver(self, forKeyPath: "title")
			webview.removeObserver(self, forKeyPath: "URL")
		 }
	}

    override public func observeValueForKeyPath(keyPath: String, ofObject object: AnyObject, change: [NSObject : AnyObject], context: UnsafeMutablePointer<()>) {
		switch keyPath {
			case "title": fallthrough
			case "URL":
				 if let URL = URL { 
				 	if let title = title { toolTip = "\(title) [\(URL)]"; break }
					toolTip = URL.description
				 }
			default: super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context);
		}
    }
}

class WebTabViewController: NSTabViewController { // & NSViewController

	let urlbox = URLBox() // retains some state and serves as a history go-between for WKNavigation / WKBackForwardList

/*
	convenience override init() { // crashes, even with no instructions
		self.init()
		tabView = NSTabView()
		tabView.identifier = "NSTabView"
		tabView.tabViewType = .NoTabsNoBorder
		tabView.drawsBackground = false // let the window be the background
		view.wantsLayer = true //use CALayer to coalesce views
 		view.autoresizingMask = .ViewWidthSizable | .ViewHeightSizable //resize tabview's subviews to match its size
		tabStyle = .Toolbar // this will reinit window.toolbar to mirror the tabview itembar
		transitionOptions = .None //.Crossfade .SlideUp/Down/Left/Right/Forward/Backward
	}
*/

	var currentTab: NSTabViewItem? { get {
		if selectedTabViewItemIndex == -1 { return nil }
		return (tabViewItems[selectedTabViewItemIndex] as? NSTabViewItem) ?? nil
	}}

	//shouldSelect didSelect
	override func tabView(tabView: NSTabView, willSelectTabViewItem tabViewItem: NSTabViewItem) { 
		super.tabView(tabView, willSelectTabViewItem: tabViewItem)
		urlbox.tab = tabViewItem // make the urlbox monitor the newly-selected tab's webview (if any)
	}

	func tabForView(view: NSView) -> NSTabViewItem? {
		let tabIdx = tabView.indexOfTabViewItemWithIdentifier(view.identifier)
		if tabIdx == NSNotFound { return nil }
		else if let tabItem = (tabView.tabViewItems[tabIdx] as? NSTabViewItem) { return tabItem }
		else { return nil }
	}	//toolbarButtonForView? toolbarButtonForTab?

	override func toolbarAllowedItemIdentifiers(toolbar: NSToolbar) -> [AnyObject] { 
		let tabs = super.toolbarAllowedItemIdentifiers(toolbar)
		return (tabs ?? []) + [
			NSToolbarSeparatorItemIdentifier,
			NSToolbarSpaceItemIdentifier,
			NSToolbarFlexibleSpaceItemIdentifier,
			NSToolbarShowColorsItemIdentifier,
			NSToolbarShowFontsItemIdentifier,
			NSToolbarCustomizeToolbarItemIdentifier,
			NSToolbarPrintItemIdentifier, URLBoxId, ShareButton
		]
	}

	override func toolbarDefaultItemIdentifiers(toolbar: NSToolbar) -> [AnyObject] { 
		let tabs = super.toolbarDefaultItemIdentifiers(toolbar)
		//return ["urlbox", NSToolbarFlexibleSpaceItemIdentifier] + tabs! // + [NSToolbarFlexibleSpaceItemIdentifier]
		//return [NSToolbarFlexibleSpaceItemIdentifier] + tabs! + [NSToolbarFlexibleSpaceItemIdentifier]
		return [ShareButton, URLBoxId] + tabs! + [NSToolbarFlexibleSpaceItemIdentifier]
		//tabviewcontroller somehow remembers where tabs! was and keeps putting new tabs in that position
	}

	override func toolbar(toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: String, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
		let ti = NSToolbarItem(itemIdentifier: itemIdentifier)
		switch (itemIdentifier) {
			case ShareButton:
				let btn = NSButton()
				btn.image = NSImage(named: NSImageNameShareTemplate) // https://hetima.github.io/fucking_nsimage_syntax/
				btn.bezelStyle = .RecessedBezelStyle // RoundRectBezelStyle ShadowlessSquareBezelStyle
				btn.setButtonType(.MomentaryLightButton) //MomentaryChangeButton MomentaryPushInButton
				btn.target = nil // walk the Responder Chain
				btn.action = Selector("shareButton:")
				btn.sendActionOn(Int(NSEventMask.LeftMouseDownMask.rawValue))

				ti.minSize = CGSize(width: 24, height: 24)
				ti.maxSize = CGSize(width: 36, height: 36)
				ti.paletteLabel = "Share URL"
				ti.view = btn
				ti.visibilityPriority = NSToolbarItemVisibilityPriorityLow
				return ti
			case URLBoxId:
				ti.paletteLabel = "Current URL"
				ti.enabled = true

				urlbox.bezelStyle = .RoundedBezel
				urlbox.drawsBackground = false
				//urlbox.textColor = NSColor.whiteColor() 
				//urlbox.backgroundColor =
				urlbox.toolTip = ""
 
				if let cell = urlbox.cell() as? NSSearchFieldCell {
					cell.maximumRecents = 5
					cell.searchButtonCell = nil // blank out left side button -- history menu?
					cell.searchMenuTemplate = nil // NSMenu("Search")
					cell.cancelButtonCell = nil // blank out right side button -- stopLoading?
					cell.placeholderString = "Navigate to URL"
					cell.sendsWholeSearchString = true
					cell.sendsSearchStringImmediately = false
					cell.action = Selector("gotoURL:")
					cell.target = nil // walk the Responder chain
				}

				ti.view = urlbox
				ti.visibilityPriority = NSToolbarItemVisibilityPriorityLow
				ti.minSize = CGSize(width: 70, height: 24)
				ti.maxSize = CGSize(width: 600, height: 24)
				return ti
			default:
				// let NSTabViewController map a TabViewItem to this ToolbarItem
				return super.toolbar(toolbar, itemForItemIdentifier: itemIdentifier, willBeInsertedIntoToolbar: flag)
		}

	}
	
	//override func toolbarSelectableItemIdentifiers(toolbar: NSToolbar) -> [AnyObject] { return super.toolbarSelectableItemIdentifiers(toolbar) }

	/*
	override func toolbarWillAddItem(notification: NSNotification) {
		if let item = notification.userInfo?["item"] as? NSToolbarItem {
			warn("new toolbar item")
			// .target? .action?
		}
	}
	override func toolbarDidRemoveItem(notification: NSNotification) {}
	*/

	//deinit { }
}

public class MacPin2: NSObject, WebAppScriptExports  {
	var app: NSApplication? = nil //the OSX app we are delegating methods for

	var windowController = NSWindowController(window: NSWindow(
		contentRect: NSMakeRect(0, 0, 600, 800),
		styleMask: NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask | NSUnifiedTitleAndToolbarWindowMask | NSFullSizeContentViewWindowMask,
		backing: .Buffered,
		defer: true
	))

	var viewController = WebTabViewController() //also available as windowController.contentViewController

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
			prefs._developerExtrasEnabled = true // http://trac.webkit.org/changeset/172406 will land in OSX 10.10.2?
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
		if urlstr.isEmpty { return nil }
		if let urlp = NSURLComponents(string: urlstr) {
			if !((urlp.path ?? "").isEmpty) && (urlp.scheme ?? "").isEmpty && (urlp.host ?? "").isEmpty { // 'example.com' & 'example.com/foobar'
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

	func showApplication(sender: AnyObject?) {

		if let window = windowController.window {
			window.collectionBehavior = .FullScreenPrimary | .ParticipatesInCycle | .Managed | .CanJoinAllSpaces //.FullScreenAuxiliary | .MoveToActiveSpace 
			window.movableByWindowBackground = true
			window.backgroundColor = NSColor.whiteColor()
			window.opaque = true
			window.hasShadow = true
			window.titleVisibility = .Hidden
			window.appearance = NSAppearance(named: NSAppearanceNameVibrantDark) // Aqua LightContent VibrantDark VibrantLight //FIXME add a setter?

			window.toolbar = NSToolbar(identifier: "toolbar") //placeholder, will be re-init'd by NSTabViewController

			window.title = NSProcessInfo.processInfo().processName
			app?.windowsMenu = NSMenu() 
			app?.addWindowsItem(window, title: window.title!, filename: false)
			
			window.identifier = "browser"
			//window.restorationClass = MacPin.self //NSWindowRestoration Protocol - not a multi-window app, so not needed yet

			// build a tabview to hold all the webviews
			//viewController.identifier = "NSTabViewController"
			
			viewController.tabView = NSTabView()
			viewController.tabView.identifier = "NSTabView"
			viewController.tabView.tabViewType = .NoTabsNoBorder
			viewController.tabView.drawsBackground = false // let the window be the background
			viewController.view.wantsLayer = true //use CALayer to coalesce views
			viewController.view.frame = window.contentLayoutRect //make it fit the entire window +/- toolbar movement
 			viewController.view.autoresizingMask = .ViewWidthSizable | .ViewHeightSizable //resize tabview's subviews to match its size
			viewController.tabStyle = .Toolbar // this will reinit window.toolbar to mirror the tabview itembar
			viewController.transitionOptions = .None //.Crossfade .SlideUp/Down/Left/Right/Forward/Backward
			//viewController.canPropagateSelectedChildViewControllerTitle = true
			//viewController.title = nil //will autofill with selected tabView's title on tab switch
			//viewController.addObserver(self, forKeyPath: "title", options: .Initial | .New, context: nil) //use KVO to copy updates to window.title

			// lay down a blurry view underneath, only seen when transparency is toggled
			var blurView = NSVisualEffectView(frame: window.contentLayoutRect)
			blurView.blendingMode = .BehindWindow
			blurView.material = .AppearanceBased //.Dark .Light .Titlebar
			blurView.state = NSVisualEffectState.Active // set it to always be blurry regardless of window state
 			blurView.autoresizingMask = .ViewWidthSizable | .ViewHeightSizable
			blurView.wantsLayer = true
			blurView.layer?.cornerRadius = cornerRadius
			blurView.layer?.masksToBounds = true

			let cView = (window.contentView as NSView)
			cView.wantsLayer = true
			cView.layer?.cornerRadius = cornerRadius
			cView.layer?.masksToBounds = true
			//cView.autoresizesSubviews = false //ignore resizemasks
			cView.addSubview(blurView)
			cView.addSubview(viewController.view)

			window.toolbar!.allowsUserCustomization = true
			//window.toolbar!.identifier = "toolbar" // yikes, private setter hax to fix autosave, but it needs to happen before subview bind
			//window.toolbar!.autosavesConfiguration = true
			window.showsToolbarButton = true

			//window.delegate = self // default is windowController
			//window.registerForDraggedTypes([NSPasteboardTypeString,NSURLPboardType,NSFilenamesPboardType]) // DnD http://stackoverflow.com/a/26733085/3878712

			window.cascadeTopLeftFromPoint(NSMakePoint(20,20))
		}
		windowController.shouldCascadeWindows = false // messes with Autosave
		windowController.windowFrameAutosaveName = "browser"
		windowController.showWindow(sender)
	}

	func toggleFullscreen() { windowController.window!.toggleFullScreen(nil) } //FIXME: super toggleFullScreen so that we can notify the webviews

	func toggleTransparency() {
		conlog("toggling transparency")
		isTransparent = !isTransparent
		let window: NSWindow = windowController.window!
		window.backgroundColor = window.backgroundColor.colorWithAlphaComponent(abs(window.backgroundColor.alphaComponent - 1)) // 0|1 flip-flop
		window.opaque = !window.opaque
		window.hasShadow = !window.hasShadow
		window.toolbar!.showsBaselineSeparator = !window.toolbar!.showsBaselineSeparator //super flat
		
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

extension MacPin2: NSSharingServicePickerDelegate { }

extension MacPin2: NSWindowDelegate {
	// these just handle tabless-background drags
	func draggingEntered(sender: NSDraggingInfo) -> NSDragOperation { return NSDragOperation.Every }
	func performDragOperation(sender: NSDraggingInfo) -> Bool { return true }
	//func cancelOperation(sender: AnyObject?) { NSApplication.sharedApplication().sendAction(Selector("stopLoading"), to: nil, from: sender) }
}

extension MacPin2: NSWindowRestoration {
	class public func restoreWindowWithIdentifier(identifier: String, state: NSCoder, completionHandler: ((NSWindow!,NSError!) -> Void)) {
		warn("restoreWindowWithIdentifier: \(identifier)") // state: \(state)")
		switch identifier {
			case "browser":
				var appdel = (NSApplication.sharedApplication().delegate as MacPin2)
				completionHandler(appdel.windowController.window!, nil)
			default:
				//have app remake window from scratch
				completionHandler(nil, nil) //FIXME: should ret an NSError
		}
	}
}

extension NSMenu {
	func easyAddItem(title: String , _ action: String , _ key: String? = nil, _ keyflags: [NSEventModifierFlags] = []) {
		var mi = NSMenuItem(
			title: title,
	    	action: Selector(action),
		    keyEquivalent: (key ?? "")
		)	
		for keyflag in keyflags {
			mi.keyEquivalentModifierMask |= Int(keyflag.rawValue)
			 // .[AlphaShift|Shift|Control|Alternate|Command|Numeric|Function|Help]KeyMask
		}
		addItem(mi)
		//return mi? or apply closure to it before add?
	}
}

extension MacPin2: NSApplicationDelegate {
	//optional func applicationDockMenu(_ sender: NSApplication) -> NSMenu?

	public func applicationShouldOpenUntitledFile(app: NSApplication) -> Bool { return false }

	public func applicationWillFinishLaunching(notification: NSNotification) { // dock icon bounces, also before self.openFile(foo.bar) is called
		NSUserNotificationCenter.defaultUserNotificationCenter().delegate = self
		app = notification.object as? NSApplication
		
		app!.mainMenu = NSMenu()

		var appMenu = NSMenuItem()
		appMenu.submenu = NSMenu()
		appMenu.submenu?.easyAddItem("Quit \(NSProcessInfo.processInfo().processName)", "terminate:", "q")
		appMenu.submenu?.easyAddItem("About", "orderFrontStandardAboutPanel:")
		appMenu.submenu?.easyAddItem("", "toggleFullScreen:")
		appMenu.submenu?.easyAddItem("Toggle Translucency", "toggleTransparency")
		appMenu.submenu?.easyAddItem("", "toggleToolbarShown:")
		appMenu.submenu?.easyAddItem("Load Site App", "loadSiteApp")
		appMenu.submenu?.easyAddItem("Edit Site App...", "editSiteApp")
		app!.mainMenu?.addItem(appMenu) // 1st item shows up as CFPrintableName

		var editMenu = NSMenuItem()
		editMenu.submenu = NSMenu()
		editMenu.submenu?.title = "Edit"
		editMenu.submenu?.easyAddItem("Cut", "cut:", "x", [.CommandKeyMask]) 
		editMenu.submenu?.easyAddItem("Copy", "copy:", "c", [.CommandKeyMask]) 
		editMenu.submenu?.easyAddItem("Paste", "paste:", "p", [.CommandKeyMask])
		editMenu.submenu?.easyAddItem("Select All", "selectAll:", "a", [.CommandKeyMask])
		app!.mainMenu?.addItem(editMenu) 

		var tabMenu = NSMenuItem()
		tabMenu.submenu = NSMenu()
		tabMenu.submenu?.title = "Tab"
		tabMenu.submenu?.easyAddItem("Enter URL", "focusOnURLBox", "l", [.CommandKeyMask])
		tabMenu.submenu?.easyAddItem("Zoom In", "zoomIn", "+", [.CommandKeyMask])
		tabMenu.submenu?.easyAddItem("Zoom Out", "zoomOut", "-", [.CommandKeyMask])
		// title: "Open Web Inspector", action: Selector("showConsole:"),
		tabMenu.submenu?.easyAddItem("Reload", "reloadFromOrigin:", "R", [.CommandKeyMask])
		tabMenu.submenu?.easyAddItem("Close Tab", "closeCurrentTab", "w", [.CommandKeyMask])
		tabMenu.submenu?.easyAddItem("Go Back", "goBack", "[", [.CommandKeyMask])
		tabMenu.submenu?.easyAddItem("Go Forward", "goForward", "]", [.CommandKeyMask])	
		tabMenu.submenu?.easyAddItem("Print", "print:")
		tabMenu.submenu?.easyAddItem("Stop Loading", "stopLoading:", String(format:"%c", 27))  //ESC
		app!.mainMenu?.addItem(tabMenu) 

		var winMenu = NSMenuItem()
		winMenu.submenu = NSMenu()
		winMenu.submenu?.title = "Window"
		winMenu.submenu?.easyAddItem("Open New Tab", "newTabPrompt", "t", [.CommandKeyMask])
		winMenu.submenu?.easyAddItem("Show Next Tab", "selectNextTabViewItem:", String(format:"%c", NSTabCharacter), [.ControlKeyMask]) // \t
		winMenu.submenu?.easyAddItem("Show Previous Tab", "selectPreviousTabViewItem:", String(format:"%c", NSTabCharacter), [.ControlKeyMask, .ShiftKeyMask])
		app!.mainMenu?.addItem(winMenu) 

		var origDnD = class_getInstanceMethod(WKView.self, "performDragOperation:")
		var newDnD = class_getInstanceMethod(WKView.self, "shimmedPerformDragOperation:")
		method_exchangeImplementations(origDnD, newDnD) //swizzle that shizzlee to enable logging of DnD's

		showApplication(self) //configure window and view controllers
	}

    public func applicationDidFinishLaunching(notification: NSNotification?) { //dock icon stops bouncing
		loadSiteApp()

		if let notification = notification {
			if let userNotification = notification.userInfo?["NSApplicationLaunchUserNotificationKey"] as? NSUserNotification {
				userNotificationCenter(NSUserNotificationCenter.defaultUserNotificationCenter(), didActivateNotification: userNotification)
			}
		}
    }

	public func applicationDidBecomeActive(notification: NSNotification) {
		//if application?.orderedDocuments?.count < 1 { showApplication(self) }
	}

	public func applicationWillTerminate(notification: NSNotification) { NSUserDefaults.standardUserDefaults().synchronize() }
    
	public func applicationShouldTerminateAfterLastWindowClosed(app: NSApplication) -> Bool { return true }
}

extension MacPin2: NSUserNotificationCenterDelegate {
	//didDeliverNotification
	public func userNotificationCenter(center: NSUserNotificationCenter, didActivateNotification notification: NSUserNotification) {
		conlog("user clicked notification")

		if _jsapi.tryFunc("handleClickedNotification", notification.title ?? "", notification.subtitle ?? "", notification.informativeText ?? "") {
			conlog("handleClickedNotification fired!")
			center.removeDeliveredNotification(notification)
		}
		//NSWorkspace.sharedWorkspace().openURL(NSURL(string: notification.subtitle ?? "")!)
	}

	// always display notifcations, even if app is active in foreground (for alert sounds)
	public func userNotificationCenter(center: NSUserNotificationCenter, shouldPresentNotification notification: NSUserNotification) -> Bool { return true }
}

extension MacPin2: WKUIDelegate {
	// could attach this to the window or view controllers instead

	func webView(webView: WKWebView!, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: () -> Void) {
		conlog("JS window.alert() -> \(message)")
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
		conlog("JS window.confirm() -> \(message)")
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
		conlog("JS window.prompt() -> \(prompt)")
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

	// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/Cocoa/WKUIDelegatePrivate.h
	// https://github.com/WebKit/webkit/blob/9fc59b8f8a54be88ca1de601435087018c0cc181/Source/WebKit2/UIProcess/ios/WKGeolocationProviderIOS.mm#L187
	// https://github.com/WebKit/webkit/search?q=GeolocationPosition.h http://support.apple.com/en-us/HT202080
	// http://www.cocoawithlove.com/2009/09/whereismymac-snow-leopard-corelocation.html
	func _webView(webView: WKWebView!, shouldRequestGeolocationAuthorizationForURL url: NSURL, isMainFrame: Bool, mainFrameURL: NSURL) -> Bool { return true }
	func _webView(webView: WKWebView!, printFrame: WKFrameInfo) { 
		conlog("JS: window.print()")
		var printer = NSPrintOperation(view: webView, printInfo: NSPrintInfo.sharedPrintInfo())
		// seems to work very early on in the first loaded page, then just becomes blank pages
		// PDF = This view requires setWantsLayer:YES when blendingMode == NSVisualEffectBlendingModeWithinWindow

		//var wkview = (webView.subviews.first as WKView)
		// https://github.com/WebKit/webkit/blob/d3e9af22a535887f7d4d82e37817ba5cfc03e957/Source/WebKit2/UIProcess/API/mac/WKView.mm#L3848
		//var view = WKPrintingView(printFrame, view: wkview)
		// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/mac/WKPrintingView.mm
		//var printer = wkview.printOperationWithPrintInfo(NSPrintInfo.sharedPrintInfo(), forFrame: printFrame) //crash on retain

		printer.showsPrintPanel = true
		printer.runOperation()
	}

}

extension MacPin2: WKScriptMessageHandler {
	public func userContentController(userContentController: WKUserContentController, didReceiveScriptMessage message: WKScriptMessage) {
		//called from JS: webkit.messageHandlers.<messsage.name>.postMessage(<message.body>);
		switch message.name {
			default:
				conlog("JS \(message.name)() -> \(message.body)")
				if _jsapi.hasProperty(message.name) {
					warn("sending webkit.messageHandlers.\(message.name) to JSCore: postMessage(\(message.body))")
					_jsapi.invokeMethod(message.name, withArguments: [message.body])
				}
		}
	}
}

extension MacPin2: WKNavigationDelegate {

	//func webView(webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) { }

	func webView(webView: WKWebView!, decidePolicyForNavigationAction navigationAction: WKNavigationAction, decisionHandler: (WKNavigationActionPolicy) -> Void) {
		let url = navigationAction.request.URL

		// not registering this scheme globally for inter-app deep-linking, but maybe use it with buttons added to DOM
		if let scheme = url.scheme? {
			if scheme == "macpin" {
				switch url.resourceSpecifier! {
					case "resizeTo": fallthrough
					default:
    	    	    	decisionHandler(.Cancel)
				}
			}
		}

		if _jsapi.tryFunc("decideNavigationForURL", url.description) { decisionHandler(.Cancel); return }

		//conlog("WebView decidePolicy() navType:\(navigationAction.navigationType.rawValue) sourceFrame:(\(navigationAction.sourceFrame?.request.URL)) -> \(url)")
		switch navigationAction.navigationType {
			case .LinkActivated:
				let mousebtn = navigationAction.buttonNumber
				let modkeys = navigationAction.modifierFlags
				if (modkeys & NSEventModifierFlags.AlternateKeyMask).rawValue != 0 { NSWorkspace.sharedWorkspace().openURL(url) } //alt-click
					else if (modkeys & NSEventModifierFlags.CommandKeyMask).rawValue != 0 { newAppTab(url.description) } //cmd-click
					else if !_jsapi.tryFunc("decideNavigationForClickedURL", url.description) { // allow override from JS 
						if navigationAction.targetFrame != nil && mousebtn == 1 { fallthrough } // left-click on in_frame target link
						newAppTab(url.description) // middle-clicked, or out of frame target link
					}
				conlog("webView.decidePolicy() -> .Cancel -- user clicked <a href=\(url) target=_blank> or middle-clicked: opening externally")
    	        decisionHandler(.Cancel)
			case .FormSubmitted: fallthrough
			case .BackForward: fallthrough
			case .Reload: fallthrough
			case .FormResubmitted: fallthrough
			case .Other: fallthrough
			default: decisionHandler(.Allow) 
		}
	}

	//func webView(webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {}

	public func webView(webView: WKWebView, didReceiveAuthenticationChallenge challenge: NSURLAuthenticationChallenge,
		completionHandler: (NSURLSessionAuthChallengeDisposition, NSURLCredential!) -> Void) {
		conlog("prompt for credentials!")
			
		completionHandler(.PerformDefaultHandling, nil)
		return // FIXME finish this

		var alert = NSAlert()
		alert.messageText = webView.title
		alert.addButtonWithTitle("Submit")
		alert.informativeText = "auth challenge"
		alert.icon = app?.applicationIconImage

		var userbox = NSTextField(frame: NSMakeRect(0, 0, 200, 24))
		userbox.stringValue = "Enter user"
 		if let cred = challenge.proposedCredential {
			if let user = cred.user { userbox.stringValue = user }
		}
		userbox.editable = true

		var passbox = NSTextField(frame: NSMakeRect(0, 0, 200, 24))
		passbox.stringValue = "Enter password"
 		if let cred = challenge.proposedCredential {
			if cred.hasPassword { passbox.stringValue = cred.password! }
		}
		passbox.editable = true

 		alert.accessoryView = passbox //need a second one for user & password

		alert.beginSheetModalForWindow(windowController.window!, completionHandler:{(response:NSModalResponse) -> Void in
			completionHandler(.UseCredential, NSURLCredential(
				user: userbox.stringValue,
				password: passbox.stringValue,
				persistence: .Permanent
			))
 		})

	}

	public func webView(webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: NSError) { //error returned by webkit when loading content
		//	URL is not always the requested (And invalid) domain name, just the previously loaded location
		//  fixed?: https://github.com/WebKit/webkit/commit/9f890e75fcf7e94aad588881b7ed973c742d3cc8
		if let url = (viewController.urlbox.cell() as NSSearchFieldCell).recentSearches.last as? String ?? webView.URL?.absoluteString ?? "about:blank" {
			conlog("webView.didFailProvisionalNavigation() [\(url)] -> `\(error.localizedDescription)` [\(error.domain)] [\(error.code)] `\(error.localizedFailureReason ?? String())`")
			if error.domain == NSURLErrorDomain && error.code != -999 && !webView.loading {
				//`The operation couldn't be completed. (NSURLErrorDomain error -999.)` [NSURLErrorDomain] [-999] thrown often on working links
				webView.loadHTMLString("<html><body><pre>`\(error.localizedDescription)`\n\(error.domain)\n\(error.code)\n`\(error.localizedFailureReason ?? String())`\n\(url)</pre></body></html>", baseURL: NSURL(string: url)!)
			}
		}
	}

	//func webView(webView: WKWebView!, didCommitNavigation navigation: WKNavigation!) { updateTitleFromPage(webView) } //content starts arriving

	func webView(webView: WKWebView!, decidePolicyForNavigationResponse navigationResponse: WKNavigationResponse, decisionHandler: (WKNavigationResponsePolicy) -> Void) {
		let mime = navigationResponse.response.MIMEType!
		let url = navigationResponse.response.URL!
		let fn = navigationResponse.response.suggestedFilename!
		//conlog("webView.decidePolicyForNavigationResponse() MIME-type:\(mime)\n\t`\(fn)`\n\t\(url)")

		if _jsapi.tryFunc("decideNavigationForMIME", mime, url.description) { decisionHandler(.Cancel); return } //FIXME perf hit?

		if navigationResponse.canShowMIMEType { 
			decisionHandler(.Allow)
		} else {
			conlog("webView cannot render requested MIME-type:\(mime) @ \(url)")
			decisionHandler(.Cancel)
		}
	}

	public func webView(webView: WKWebView, didFailNavigation navigation: WKNavigation!, withError error: NSError) { //error during commited main frame navigation
		// like server-issued error Statuses with no page content
		if let url = webView.URL { 
			conlog("webView.didFailNavigation() [\(url)] -> `\(error.localizedDescription)` [\(error.domain)] [\(error.code)] `\(error.localizedFailureReason ?? String())`")
			if error.domain == WebKitErrorDomain && error.code == 204 { NSWorkspace.sharedWorkspace().openURL(url) } // `Plug-in handled load!` video/mp4 Open in New Window
			webView.loadHTMLString("<html><body><pre>`\(error.localizedDescription)`\n\(error.domain)\n\(error.code)\n`\(error.localizedFailureReason ?? String())`\n\(url)</pre></body></html>", baseURL: url)
		}
    }
	
	func webView(webView: WKWebView!, didFinishNavigation navigation: WKNavigation!) {
		let title = webView.title ?? String()
		let url = webView.URL ?? NSURL(string:"")!
		conlog("webView.didFinishNavigation() \"\(title)\" [\(url)]")
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

		conlog("JS@\(navigationAction.sourceFrame?.request.URL ?? String()) window.open(\(url), \(tgt))")

		if _jsapi.tryFunc("decideWindowOpenForURL", url.description) { return nil }

		if url.description.isEmpty { 
			conlog("url-less JS popup request!")
		} else if url.scheme!.hasPrefix("chrome-http") { //reroute iOS-style chrome-http and chrome-https schemes to Chrome.app
			conlog("redirecting JS popup to Chrome")
			self.sysOpenURL(((url.scheme!.hasSuffix("s") ? "https:" : "http:") + url.resourceSpecifier!), "com.google.Chrome")	
			//perhaps firing a Cocoa Share Extension would be more appropriate? deep-linking is spotty at best
		} else if url.description == "macpin:resizeTo" {
			 // WKWebView doesn't natively support window.resizeTo, use this target to simply resize existing NSWindow
			window.setFrame(newframe, display: true)
		} else if (windowFeatures.allowsResizing ?? 0) == 1 { 
			conlog("JS popup request with size settings, origin,size[\(newframe)]")
			windowController.window!.setFrame(newframe, display: true)
			if let cell = viewController.urlbox.cell() as? NSSearchFieldCell { cell.recentSearches.append(url.description) } //FIXME until WKNavigation is fixed
			var webview = newWebView(url, withAgent: webView._customUserAgent, withConfiguration: configuration)
			newTab(webview)
			conlog("window.open() completed for url[\(url)] origin,size[\(newframe)]")
			return webview // window.open() -> Window()
		} else if tgt.description.isEmpty { //target-less request, assuming == 'top' 
			webView.loadRequest(navigationAction.request)
		} else {
			conlog("redirecting JS popup to system browser")
			NSWorkspace.sharedWorkspace().openURL(url) //send to default browser
		}

		return nil //window.open() -> undefined
	}

	func _webViewWebProcessDidCrash(webView: WKWebView) {
	    warn("WebContent process crashed; reloading")
		webView.reload()
	}

}	

