import WebKit // https://github.com/WebKit/webkit/blob/master/Source/WebKit/mac/ChangeLog
import Foundation
import JavaScriptCore //  https://github.com/WebKit/webkit/tree/master/Source/JavaScriptCore/API

@objc protocol BrowserScriptExports : JSExport { // '$browser' in app.js
	var globalUserScripts: [String] { get set } // list of postinjects that any new webview will get
	var isTransparent: Bool { get set }
	var isFullscreen: Bool { get set }
	var isToolbarShown: Bool { get set }
	var tabCount: Int { get }
	var tabSelected: WebViewController? { get set }
	func switchToNextTab()
	func switchToPreviousTab()
	func conlog(msg: String) // FIXME: must kill
	func newTabPrompt()
	func newTab(params: [String:AnyObject]) -> WebViewController?
	func stealAppFocus()
	func unhideApp()
}

public class TabViewController: NSTabViewController { // & NSViewController
	let URLBox	= "Current URL"
	let urlboxVC = URLBoxController(urlbox: NSTextField())!
	let ShareButton = "Share URL"
	let NewTabButton = "Open New Tab"
	var cornerRadius = CGFloat(0.0) // increment above 0.0 to put nice corners on the window FIXME userDefaults

	override public func addTabViewItem(tab: NSTabViewItem) {
		super.addTabViewItem(tab)
		if let view = tab.view {
			tab.bind(NSLabelBinding, toObject: view, withKeyPath: "title", options: nil)
			tab.bind(NSToolTipBinding, toObject: view, withKeyPath: "title", options: nil)
		}
		if let viewController = tab.viewController {
			//tab.bind(NSToolTipBinding, toObject: viewController, withKeyPath: "title", options: nil)
		}
	}

	override public func tabView(tabView: NSTabView, didSelectTabViewItem tabViewItem: NSTabViewItem) { 
		super.tabView(tabView, didSelectTabViewItem: tabViewItem)
		urlboxVC.representedObject = tabViewItem.viewController // KVC bind webview title and URL to urlbox
		urlboxVC.nextResponder = tabViewItem.view // ensure all menu bindings will walk responder tree starting from webview
		urlboxVC.view.nextKeyView = tabViewItem.view // TABbing off the urlbox will move focus to selected webview

		if let window = view.window {
			if let view = tabViewItem.view {
				window.makeFirstResponder(view) // steal app focus to whatever the tab represents
				window.unbind(NSTitleBinding)
				window.bind(NSTitleBinding, toObject: view, withKeyPath: "title", options: nil)
			}
		}
	}

	func tabForView(view: NSView) -> NSTabViewItem? {
		let tabIdx = tabView.indexOfTabViewItemWithIdentifier(view.identifier)
		if tabIdx == NSNotFound { return nil }
		else if let tabItem = (tabView.tabViewItems[tabIdx] as? NSTabViewItem) { return tabItem }
		else { return nil }
	}	//toolbarButtonForView? toolbarButtonForTab?

	override public func toolbarAllowedItemIdentifiers(toolbar: NSToolbar) -> [AnyObject] { 
		let tabs = super.toolbarAllowedItemIdentifiers(toolbar)
		return (tabs ?? []) + [
			NSToolbarSeparatorItemIdentifier,
			NSToolbarSpaceItemIdentifier,
			NSToolbarFlexibleSpaceItemIdentifier,
			NSToolbarShowColorsItemIdentifier,
			NSToolbarShowFontsItemIdentifier,
			NSToolbarCustomizeToolbarItemIdentifier,
			NSToolbarPrintItemIdentifier, URLBox, ShareButton, NewTabButton
		]
	}

	override public func toolbarDefaultItemIdentifiers(toolbar: NSToolbar) -> [AnyObject] { 
		let tabs = super.toolbarDefaultItemIdentifiers(toolbar)
		//return [ShareButton, NewTabButton] + tabs! + [NSToolbarFlexibleSpaceItemIdentifier]
		return [ShareButton, NewTabButton, NSToolbarFlexibleSpaceItemIdentifier] + tabs!
		//tabviewcontroller somehow remembers where tabs! was and keeps putting new tabs in that position
	}

	override public func toolbar(toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: String, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
		let ti = NSToolbarItem(itemIdentifier: itemIdentifier)
		switch (itemIdentifier) {
			case ShareButton:
				ti.paletteLabel = ShareButton
				ti.minSize = CGSize(width: 24, height: 24)
				ti.maxSize = CGSize(width: 36, height: 36)
				ti.visibilityPriority = NSToolbarItemVisibilityPriorityLow

				let btn = NSButton()
				btn.image = NSImage(named: NSImageNameShareTemplate) // https://hetima.github.io/fucking_nsimage_syntax/
				btn.bezelStyle = .RecessedBezelStyle // RoundRectBezelStyle ShadowlessSquareBezelStyle
				btn.setButtonType(.MomentaryLightButton) //MomentaryChangeButton MomentaryPushInButton
				btn.target = nil // walk the Responder Chain
				btn.action = Selector("shareButtonClicked:")
				btn.sendActionOn(Int(NSEventMask.LeftMouseDownMask.rawValue))
				btn.toolTip = ShareButton
				ti.view = btn
				return ti

			case NewTabButton:
				ti.paletteLabel = NewTabButton
				ti.minSize = CGSize(width: 24, height: 24)
				ti.maxSize = CGSize(width: 36, height: 36)
				ti.visibilityPriority = NSToolbarItemVisibilityPriorityLow

				let btn = NSButton()
				btn.image = NSImage(named: NSImageNameAddTemplate) // https://hetima.github.io/fucking_nsimage_syntax/
				btn.bezelStyle = .RecessedBezelStyle // RoundRectBezelStyle ShadowlessSquareBezelStyle
				btn.setButtonType(.MomentaryLightButton) //MomentaryChangeButton MomentaryPushInButton
				btn.target = nil // walk the Responder Chain
				btn.action = Selector("newTabPrompt")
				btn.sendActionOn(Int(NSEventMask.LeftMouseDownMask.rawValue))
				btn.toolTip = NewTabButton
				ti.view = btn
				return ti

			case URLBox:
				ti.paletteLabel = URLBox
				ti.enabled = true
				ti.visibilityPriority = NSToolbarItemVisibilityPriorityLow
				ti.minSize = CGSize(width: 70, height: 24)
				ti.maxSize = CGSize(width: 600, height: 24)
				ti.view = urlboxVC.view
				return ti

			default:
				// let NSTabViewController map a TabViewItem to this ToolbarItem
				let tvi = super.toolbar(toolbar, itemForItemIdentifier: itemIdentifier, willBeInsertedIntoToolbar: flag)
				//warn("\(__FUNCTION__) \(itemIdentifier) \(tvi?.image) \(tvi?.action)")
				return tvi
		}
		// optional func toolbarWillAddItem(_ notification: NSNotification)
		// optional func toolbarDidRemoveItem(_ notification: NSNotification)

	}

	override public func loadView() {
		tabView = NSTabView()
		tabView.identifier = "NSTabView"
		tabView.tabViewType = .NoTabsNoBorder
		tabView.drawsBackground = false // let the window be the background
		//tabView.autoresizesSubviews = false 
		//tabView.translatesAutoresizingMaskIntoConstraints = false
		super.loadView()
		// note, .view != tabView, view wraps tabView + whatever tabStyle is selected
		//preferredContentSize = CGSize(width: 600, height: 800)
	}

	override public func viewDidLoad() {
		identifier = "TabViewController"

		// http://www.raywenderlich.com/2502/calayers-tutorial-for-ios-introduction-to-calayers-tutorial
		view.wantsLayer = true //use CALayer
		//view.layer?.frame = view.frame
		view.layer?.cornerRadius = cornerRadius
		view.layer?.masksToBounds = true // include layer contents in clipping effects
		view.canDrawSubviewsIntoLayer = true // coalesce all subviews' layers into this one

		view.autoresizingMask = .ViewWidthSizable | .ViewHeightSizable //resize tabview to match parent ContentView size
		tabStyle = .Toolbar // this will reinit window.toolbar to mirror the tabview itembar
		transitionOptions = .None //.Crossfade .SlideUp/Down/Left/Right/Forward/Backward
		view.frame = NSMakeRect(0, 0, 600, 800) // default size
		super.viewDidLoad()

		// lay down a blurry view underneath, only seen when transparency is toggled * document.body.bgColor == transparent, or no tabs loaded
		var blurView = NSVisualEffectView(frame: view.frame)
		blurView.blendingMode = .BehindWindow
		blurView.material = .AppearanceBased //.Dark .Light .Titlebar
		blurView.state = NSVisualEffectState.Active // set it to always be blurry regardless of window state
		blurView.autoresizingMask = .ViewWidthSizable | .ViewHeightSizable
		view.addSubview(blurView, positioned: .Below, relativeTo: view) // FIXME add replace toggle

		view.registerForDraggedTypes([NSPasteboardTypeString,NSURLPboardType,NSFilenamesPboardType])
	}
	
	override public func viewWillAppear() {
		super.viewWillAppear()
		if let window = view.window {
			window.toolbar!.allowsUserCustomization = true
			window.toolbar!.displayMode = .IconOnly
		}
	}

	public func draggingEntered(sender: NSDraggingInfo) -> NSDragOperation { return NSDragOperation.Every }
	public func performDragOperation(sender: NSDraggingInfo) -> Bool { return true } //should open the file:// url
}

public class BrowserViewController: TabViewController, BrowserScriptExports {

	var _globalUserScripts: [String] = []
	var globalUserScripts: [String] { // protect the app from bad JS settings?
		get { return self._globalUserScripts }
		set(newarr) { self._globalUserScripts = newarr }
		//auto-replace loaded scripts in contentController?
	}

	//var defaultUserAgent: String {
	//	get { }
	//	set(ua) { NSUserDefaults.standardUserDefaults().setString(ua, forKey: "UserAgent") } //only works on IOS
	//} // https://github.com/WebKit/webkit/blob/master/Source/WebCore/page/NavigatorBase.cpp
	// https://github.com/WebKit/webkit/blob/master/Source/WebCore/page/mac/UserAgentMac.mm

	var isTransparent: Bool = false {
		didSet {
			if let window = view.window {
				window.backgroundColor = window.backgroundColor.colorWithAlphaComponent(isTransparent ? 0 : 1) //clearColor | fooColor
				//window.backgroundColor = isTranparent ? NSColor(calibratedHue:0.0, saturation:0.0, brightness:0.2, alpha:0.5) : NSColor.whiteColor()
				window.opaque = !isTransparent
				window.hasShadow = !isTransparent
				window.toolbar!.showsBaselineSeparator = !isTransparent
			}

			//for tab in tabViewItems {
			//	if let webview = (tab as NSTabViewItem).webview {
			for vc in childViewControllers {
				if let webview = (vc as WebViewController).webview {
	
					webview._drawsTransparentBackground = isTransparent
					//^ background-color:transparent sites immediately bleedthru to a black CALayer, which won't go clear until the content is reflowed or reloaded
					webview.needsDisplay = true
					webview.setFrameSize(NSSize(width: webview.frame.size.width, height: webview.frame.size.height - 1)) //needed to fully redraw w/ dom-reflow or reload! 
					webview.evaluateJavaScript(
						"window.dispatchEvent(new window.CustomEvent('MacPinTransparencyChanged',{'detail':{'isTransparent': \(isTransparent)}})); ",	
					completionHandler: nil)
					webview.evaluateJavaScript("document.head.appendChild(document.createElement('style')).remove();", completionHandler: nil) //force redraw in case event didn't
					webview.setFrameSize(NSSize(width: webview.frame.size.width, height: webview.frame.size.height + 1))
				}
			}
		}
	}

	var isFullscreen: Bool { 
		get { return (view.window?.contentView as NSView).inFullScreenMode ?? false }
		set(bool) { if bool != isFullscreen { view.window!.toggleFullScreen(nil) } }
	}

	var isToolbarShown: Bool { 
		get { return view.window?.toolbar?.visible ?? true }
		set(bool) { if bool != isToolbarShown { view.window!.toggleToolbarShown(nil) } }
	}

	var tabCount: Int { get { return childViewControllers.count } }
	var firstTab: WebViewController? { get { return (childViewControllers.first as? WebViewController) ?? nil }}
	var tabSelected: WebViewController? {
		get {
			if selectedTabViewItemIndex == -1 { return nil }
			return (childViewControllers[selectedTabViewItemIndex] as? WebViewController) ?? nil
		}
		set(wvc) { tabView.selectTabViewItem(tabViewItemForViewController(wvc!)) }
	}

	func closeCurrentTab() {
		tabSelected?.removeFromParentViewController()	//FIXME: not dealloc'ing the actual webviews
		if tabView.numberOfTabViewItems == 0 { view.window?.performClose(self) }
			else { switchToNextTab() } //safari behavior
	}

	func switchToPreviousTab() { tabView.selectPreviousTabViewItem(self) }
	func switchToNextTab() { tabView.selectNextTabViewItem(self) }

	func toggleTransparency() { isTransparent = !isTransparent }

	func editSiteApp() { NSWorkspace.sharedWorkspace().openFile(NSBundle.mainBundle().resourcePath!) }

	func newTabPrompt() {
		if let wvc = newTab(NSURL(string: "about:blank")!) {
			//if let id: AnyObject = tabViewItemForViewController(wvc)?.identifier { tabSelected = id }
			tabSelected = wvc
			wvc.gotoButtonClicked(nil)
		}
	}

 	// exported to jsruntime.context as $browser.newTab({url: 'http://example.com'})
	// NEEDS TO BE DECLARED FIRST (above all other newTab overload funcs) in order for jsruntime to use this. crazy, amirite?
 	// FIXME: (params: JSValue)->JSValue would be safer? and prevent this selector confusion?
	func newTab(params: [String:AnyObject]) -> WebViewController? {
		// prototype vars
		var url = NSURL(string: "about:blank")
		var icon: String? = nil
		var agent: String? = nil
		var msgHandlers: [String] = []
		let webctl = WKUserContentController()

			for (key, value) in params {
				switch key {
					case "url":
						if let value = value as? String { url = NSURL(string: value) }
					case "agent":
						if let value = value as? String { agent = value }
					case "icon":
						if let value = value as? String { icon = value }
					case "preinject":
						if let value = value as? [String] {
							for script in value { loadUserScriptFromBundle(script, webctl, .AtDocumentStart, onlyForTop: false) } }
					case "postinject":
						if let value = value as? [String] {
							for script in value { loadUserScriptFromBundle(script, webctl, .AtDocumentEnd, onlyForTop: false) } }
					case "handlers":
						if let value = value as? [String] {
							for handler in value { msgHandlers.append(handler) } }
					default:
						conlog("\(__FUNCTION__) unhandled param: `\(key)`")
				}
			}

		for script in _globalUserScripts { loadUserScriptFromBundle(script, webctl, .AtDocumentEnd, onlyForTop: false) }

		if let url = url {
			let webcfg = WKWebViewConfiguration()
			webcfg.userContentController = webctl
			if let wvc = WebViewController(agent: agent, configuration: webcfg) {
				for handler in msgHandlers { webctl.addScriptMessageHandler(wvc, name: handler) }
				newTab(wvc, withIcon: icon)
				wvc.gotoURL(url)
				return wvc
			}
		}
		return nil
	}
	func newTab(urlstr: String) { if let url = NSURL(string: urlstr) { newTab(url) } }
	func newTab(url: NSURL) -> WebViewController? { 
		if let wvc = WebViewController(agent: nil) {
			newTab(wvc)
			wvc.gotoURL(url)
			return wvc
		}
		return nil
	}
	func newTab(subvc: NSViewController, withIcon: String? = nil) {
		//addChildViewController(subvc)
		//childViewControllers.append(subvc)
		let tab = NSTabViewItem(viewController: subvc)
		tab.identifier = subvc.identifier //NSUserInterfaceItemIdentification
		tab.image = NSApplication.sharedApplication().applicationIconImage
		if let icon = withIcon {
			if !icon.isEmpty { tab.image = NSImage(byReferencingURL: NSURL(string: icon)!) }
			//need 24 & 36px**2 representations for the NSImage
			// https://developer.apple.com/library/ios/documentation/AppleApplications/Reference/SafariWebContent/ConfiguringWebApplications/ConfiguringWebApplications.html
			// just C, no Cocoa API yet: WKIconDatabaseCopyIconURLForPageURL(icodb, url) WKIconDatabaseCopyIconDataForPageURL(icodb, url)
			// also https://github.com/WebKit/webkit/commit/660d1e55c2d1ee19ece4a7565d8df8cab2e15125
			// OSX has libxml2 built-in https://developer.apple.com/library/mac/samplecode/LinkedImageFetcher/Listings/Read_Me_About_LinkedImageFetcher_txt.html
		}
		tab.initialFirstResponder = subvc.view
		addTabViewItem(tab)
	}

	func conlog(msg: String) { // _ webview: WKWebView? = nil
		warn(msg)
#if APP2JSLOG
		tabSelected?.evalJS("console.log(\'<\(__FILE__)> \(msg)\')")
#endif
	}

	func stealAppFocus() { NSApplication.sharedApplication().activateIgnoringOtherApps(true) }
	func unhideApp() {
		stealAppFocus()
		NSApplication.sharedApplication().unhide(self)
		NSApplication.sharedApplication().arrangeInFront(self)
		view.window?.makeKeyAndOrderFront(nil)
	}
}
