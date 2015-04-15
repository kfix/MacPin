import WebKit // https://github.com/WebKit/webkit/blob/master/Source/WebKit/mac/ChangeLog
import Foundation
import JavaScriptCore //  https://github.com/WebKit/webkit/tree/master/Source/JavaScriptCore/API

@objc protocol BrowserScriptExports : JSExport { // '$browser' in app.js
	var globalUserScripts: [String] { get set } // list of postinjects that any new webview will get
	var defaultUserAgent: String? { get set } // full UA used for any new tab without explicit UA specified
	var isFullscreen: Bool { get set }
	var isToolbarShown: Bool { get set }
	var tabs: [AnyObject] { get set } // alias to childViewControllers
	var childViewControllers: [AnyObject] { get set }
	var tabSelected: AnyObject? { get set }
	func addTab(vc: NSViewController)
	func switchToNextTab()
	func switchToPreviousTab()
	func conlog(msg: String, _ function: String, _ file: String, _ line: Int, _ column: Int) // must kill
	func newTabPrompt()
	func newTab(params: AnyObject?) -> WebViewController?
	func stealAppFocus()
	func unhideApp()
	func bounceDock()
	func addBookmark(title: String, _ obj: AnyObject?)
}

public class TabViewController: NSTabViewController {
	let urlbox = URLBoxController(webViewController: nil)
	lazy var tabPopBtn = NSPopUpButton(frame: NSRect(x:0, y:0, width:400, height:24), pullsDown: false)
	let tabMenu = NSMenu() // list of all active web tabs
	let bookmarksMenu = NSMenu()
	//lazy var tabGrid = TabGridController()
	/*
	lazy var tabGrid: NSCollectionView = {
		var grid = NSCollectionView()
		grid.selectable = true
		grid.allowsMultipleSelection = false
		grid.maxNumberOfRows = 0
		grid.maxNumberOfColumns = 10
		grid.minItemSize = NSSize(width: 0, height: 0)
		grid.maxItemSize = NSSize(width: 0, height: 0)
		//grid.itemPrototype = NSCollectionViewItem
		//grid.preferredContentSize = NSSize(width: 300, height: 300)
		return grid
	}() */

	let URLBox	= "Current URL"
	let ShareButton = "Share URL"
	let NewTabButton = "Open New Tab"
	let CloseTabButton = "Close Tab"
	let SelectedTabButton = "Selected Tab"
	let BackButton = "Back"
	let ForwardButton = "Forward"
	let ForwardBackButton = "Forward & Back"
	let RefreshButton = "Refresh"
	let TabListButton = "Tabs"
	var cornerRadius = CGFloat(0.0) // increment above 0.0 to put nice corners on the window FIXME userDefaults

	override public func insertTabViewItem(tab: NSTabViewItem, atIndex: Int) {
		if let view = tab.view {
			tab.initialFirstResponder = view
			tab.bind(NSLabelBinding, toObject: view, withKeyPath: "title", options: nil)
			tab.bind(NSToolTipBinding, toObject: view, withKeyPath: "title", options: nil)
			if let wvc = tab.viewController as? WebViewController {
				tab.bind(NSImageBinding, toObject: wvc, withKeyPath: "favicon", options: nil)
			}
		}
		super.insertTabViewItem(tab, atIndex: atIndex)
	}

	override public func removeTabViewItem(tab: NSTabViewItem) {
		if let view = tab.view {
			tab.initialFirstResponder = nil
			tab.unbind(NSLabelBinding)
			tab.unbind(NSToolTipBinding)
			if let wvc = tab.viewController as? WebViewController {
				tab.unbind(NSImageBinding)
			}
		}
		super.removeTabViewItem(tab)
	}

	override public func tabView(tabView: NSTabView, didSelectTabViewItem tabViewItem: NSTabViewItem) { 
		super.tabView(tabView, didSelectTabViewItem: tabViewItem)
		if let window = view.window {
			if let view = tabViewItem.view {
				window.makeFirstResponder(view) // steal app focus to whatever the tab represents
			}
		}
	}

	override public func tabViewDidChangeNumberOfTabViewItems(tabView: NSTabView) { warn("@\(tabView.tabViewItems.count)") }

	override public func toolbarAllowedItemIdentifiers(toolbar: NSToolbar) -> [AnyObject] { 
		let tabs = super.toolbarAllowedItemIdentifiers(toolbar) ?? []
		return tabs + [
			NSToolbarSeparatorItemIdentifier,
			NSToolbarSpaceItemIdentifier,
			NSToolbarFlexibleSpaceItemIdentifier,
			NSToolbarShowColorsItemIdentifier,
			NSToolbarShowFontsItemIdentifier,
			NSToolbarCustomizeToolbarItemIdentifier,
			NSToolbarPrintItemIdentifier,
			URLBox, ShareButton, NewTabButton, CloseTabButton,
			ForwardButton, BackButton, RefreshButton, SelectedTabButton
		]
	}

	override public func toolbarDefaultItemIdentifiers(toolbar: NSToolbar) -> [AnyObject] { 
		let tabs = super.toolbarDefaultItemIdentifiers(toolbar) ?? []
		return [ShareButton, NewTabButton] + tabs + [NSToolbarFlexibleSpaceItemIdentifier]
		//return [ShareButton, NewTabButton, NSToolbarFlexibleSpaceItemIdentifier] + tabs
		//return [NSToolbarFlexibleSpaceItemIdentifier, ShareButton] + tabs! + [NewTabButton, NSToolbarFlexibleSpaceItemIdentifier]
		//return [NSToolbarFlexibleSpaceItemIdentifier, ShareButton, NSToolbarFlexibleSpaceItemIdentifier] + tabs + [NSToolbarFlexibleSpaceItemIdentifier, NewTabButton, NSToolbarFlexibleSpaceItemIdentifier]
		//return [ShareButton, NewTabButton, CloseTabButton, BackButton, ForwardButton, RefreshButton,SelectedTabButton, URLBox] + tabs + [NSToolbarFlexibleSpaceItemIdentifier]
		//tabviewcontroller somehow remembers where tabs! was and keeps putting new tabs in that position
	}

	override public func toolbar(toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: String, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
		let ti = NSToolbarItem(itemIdentifier: itemIdentifier)
		ti.minSize = CGSize(width: 24, height: 24)
		ti.maxSize = CGSize(width: 36, height: 36)
		ti.visibilityPriority = NSToolbarItemVisibilityPriorityLow
		ti.paletteLabel = itemIdentifier

		let btn = NSButton()
		let btnCell = btn.cell() as! NSButtonCell
		//btnCell.controlSize = .SmallControlSize
		btn.toolTip = itemIdentifier
		btn.image = NSImage(named: NSImageNamePreferencesGeneral) // https://hetima.github.io/fucking_nsimage_syntax/
		btn.bezelStyle = .RecessedBezelStyle // RoundRectBezelStyle ShadowlessSquareBezelStyle
		btn.setButtonType(.MomentaryLightButton) //MomentaryChangeButton MomentaryPushInButton
		btn.target = nil // walk the Responder Chain
		btn.sendActionOn(Int(NSEventMask.LeftMouseDownMask.rawValue))
		ti.view = btn
	
		switch (itemIdentifier) {
			case ShareButton:
				btn.image = NSImage(named: NSImageNameShareTemplate)
				btn.action = Selector("shareButtonClicked:")
				return ti

			case NewTabButton:
				btn.image = NSImage(named: NSImageNameAddTemplate)
				btn.action = Selector("newTabPrompt")
				return ti

			case CloseTabButton:
				btn.image = NSImage(named: NSImageNameRemoveTemplate)
				btn.action = Selector("closeCurrentTab")
				return ti

			case ForwardButton:
				btn.image = NSImage(named: NSImageNameGoRightTemplate)
				btn.action = Selector("goForward:")
				return ti

			case BackButton:
				btn.image = NSImage(named: NSImageNameGoLeftTemplate)
				btn.action = Selector("goBack:")
				return ti

			case ForwardBackButton:
				let seg = NSSegmentedControl()
				seg.segmentCount = 2
				seg.segmentStyle = .Separated
				let segCell = seg.cell() as! NSSegmentedCell
				segCell.trackingMode = .Momentary
				seg.action = Selector("goBack:")

				seg.setImage(NSImage(named: NSImageNameGoLeftTemplate), forSegment: 0)
				//seg.setLabel(BackButton, forSegment: 0)
				//seg.setMenu(backMenu, forSegment: 0) // wvc.webview.backForwardList.backList (WKBackForwardList)
				segCell.setTag(0, forSegment: 0)
	
				seg.setImage(NSImage(named: NSImageNameGoRightTemplate), forSegment: 1)
				//seg.setLabel(ForwardButton, forSegment: 1)
				segCell.setTag(1, forSegment: 1)

				ti.maxSize = CGSize(width: 54, height: 36)
				ti.view = seg
				return ti

			case RefreshButton:
				btn.image = NSImage(named: NSImageNameRefreshTemplate)
				btn.action = Selector("reload:")
				return ti

			case SelectedTabButton:
				ti.minSize = CGSize(width: 70, height: 24)
				ti.maxSize = CGSize(width: 600, height: 36)
				tabPopBtn.menu = tabMenu
				//tabPopBtn.menu?.itemAtIndex(0).setView(tabGrid.view) // GridMenu display
				// https://developer.apple.com/library/mac/documentation/Cocoa/Reference/ApplicationKit/Classes/NSMenu_Class/index.html#//apple_ref/occ/instm/NSMenu/popUpMenuPositioningItem:atLocation:inView:
				ti.view = flag ? tabPopBtn : NSPopUpButton()
				return ti

			case TabListButton:
				btn.image = NSImage(named: "ToolbarButtonTabOverviewTemplate.pdf")
				btn.action = Selector("tabListButtonClicked:")
				return ti


			case URLBox:
				ti.minSize = CGSize(width: 70, height: 24)
				ti.maxSize = CGSize(width: 600, height: 24)
				ti.view = flag ? urlbox.view : NSTextField()
				return ti

			default:
				// let NSTabViewController map a TabViewItem to this ToolbarItem
				let tvi = super.toolbar(toolbar, itemForItemIdentifier: itemIdentifier, willBeInsertedIntoToolbar: flag)
				//warn("\(itemIdentifier) \(tvi?.image) \(tvi?.action)")
				return tvi
		}
	}

	// optional func toolbarWillAddItem(_ notification: NSNotification)
	// optional func toolbarDidRemoveItem(_ notification: NSNotification)

	override public func loadView() {
		tabView = NSTabView()
		tabView.identifier = "NSTabView"
		tabView.tabViewType = .NoTabsNoBorder
		tabView.drawsBackground = false // let the window be the background
		//tabView.delegate = self // http://www.openradar.me/19732856
		//tabView.autoresizesSubviews = false 
		//tabView.translatesAutoresizingMaskIntoConstraints = false
		super.loadView()
		// note, .view != tabView, view wraps tabView + whatever tabStyle is selected
	}

	override public func viewDidLoad() {
		identifier = "TabViewController"
		tabStyle = .Toolbar // this will reinit window.toolbar to mirror the tabview itembar
		//tabStyle = .Unspecified
		//tabStyle = .SegmentedControlOnTop
		//tabStyle = .SegmentedControlOnBottom

		// http://www.raywenderlich.com/2502/calayers-tutorial-for-ios-introduction-to-calayers-tutorial
		view.wantsLayer = true //use CALayer
		//view.layer?.frame = view.frame
		view.layer?.cornerRadius = cornerRadius
		view.layer?.masksToBounds = true // include layer contents in clipping effects
		view.canDrawSubviewsIntoLayer = true // coalesce all subviews' layers into this one

		view.autoresizingMask = .ViewWidthSizable | .ViewHeightSizable //resize tabview to match parent ContentView size
		view.autoresizesSubviews = true // resize tabbed subviews based on their autoresizingMasks
		transitionOptions = .None //.Crossfade .SlideUp/Down/Left/Right/Forward/Backward

		//view.frame = NSMakeRect(0, 0, 600, 800) // default size

		//view.frame = CGRectZero
		//preferredContentSize = CGSize(width: 600, height: 800)
		//view.appearance = NSAppearance(named: NSAppearanceNameAqua) 

		super.viewDidLoad()

		// lay down a blurry view underneath, only seen when transparency is toggled * document.body.bgColor == transparent, or no tabs loaded
		//var blurView = NSVisualEffectView(frame: view.frame)
		//blurView.blendingMode = .BehindWindow
		////blurView.material = .AppearanceBased //.Dark .Light .Titlebar
		//blurView.material = .Dark //.Dark .Light .Titlebar
		//blurView.state = NSVisualEffectState.Active // set it to always be blurry regardless of window state
		//blurView.autoresizingMask = .ViewWidthSizable | .ViewHeightSizable
		//view.addSubview(blurView, positioned: .Below, relativeTo: view) // FIXME add replace toggle

		view.registerForDraggedTypes([NSPasteboardTypeString,NSURLPboardType,NSFilenamesPboardType]) //webviews already do this, this just enables openURL when tabless
	}
	
	override public func viewWillAppear() {
		super.viewWillAppear()
	}

	override public func viewDidAppear() {
		super.viewDidAppear()
		let toolbar = view.window?.toolbar ?? NSToolbar(identifier: "toolbar")
		toolbar.delegate = self
		toolbar.allowsUserCustomization = true
		toolbar.displayMode = .IconOnly
		toolbar.sizeMode = .Small //favicons are usually 16*2
		view.window?.toolbar = toolbar
		view.window?.excludedFromWindowsMenu = true
	}

	public func draggingEntered(sender: NSDraggingInfo) -> NSDragOperation { return NSDragOperation.Every }
	public func performDragOperation(sender: NSDraggingInfo) -> Bool { return true } //should open the file:// url

	deinit { warn("") }
}

public class BrowserViewController: TabViewController, BrowserScriptExports {
	var globalUserScripts: [String] = []
		//willSet {} auto-replace loaded scripts in each tab's contentController?

	var defaultUserAgent: String? = nil //{
	//	get { }
	//	set(ua) { NSUserDefaults.standardUserDefaults().setString(ua, forKey: "UserAgent") } //only works on IOS
	//} // https://github.com/WebKit/webkit/blob/master/Source/WebCore/page/NavigatorBase.cpp
	// https://github.com/WebKit/webkit/blob/master/Source/WebCore/page/mac/UserAgentMac.mm

	var isTransparent: Bool = false {
		didSet {
			if let window = view.window {
				//window.backgroundColor = isTransparent ? NSColor.clearColor() : NSColor.whiteColor()
				window.backgroundColor = window.backgroundColor.colorWithAlphaComponent(isTransparent ? 0 : 1) //clearColor | fooColor
				window.opaque = !isTransparent
				window.hasShadow = !isTransparent
				window.toolbar!.showsBaselineSeparator = !isTransparent
			}
		}
	}

	var isFullscreen: Bool { 
		get { return (view.window?.contentView as? NSView)?.inFullScreenMode ?? false }
		set(bool) { if bool != isFullscreen { view.window!.toggleFullScreen(nil) } }
	}

	var isToolbarShown: Bool { 
		get { return view.window?.toolbar?.visible ?? true }
		set(bool) { if bool != isToolbarShown { view.window!.toggleToolbarShown(nil) } }
	}

	/*
	var tabs: [WebViewController] { 
		get { return childViewControllers.filter({ $0 is WebViewController }).map({ $0 as WebViewController }) }
		set(newTabs) { 
			for tab in newTabs {
				addChildViewController(tab)
				//warn(tab.webview.URL?.description ?? "no url!")
			}
		}
	}
	var tabCount: Int { get { return childViewControllers.count } }
	var firstTab: WebViewController? { get { return (childViewControllers.first as? WebViewController) ?? nil }}
	var tabSelected: WebViewController? {
		get {
			if selectedTabViewItemIndex == -1 { return nil }
			return childViewControllers[selectedTabViewItemIndex] as? WebViewController
		}
		//set(wvc) { if let wvc = wvc { tabView.selectTabViewItem(tabViewItemForViewController(wvc)) } }
		set(wvc) { tabView.selectTabViewItem(tabViewItemForViewController(wvc)) }
	}
	*/

	var tabs: [AnyObject] { 
		get { return childViewControllers }
		set(newTabs) { childViewControllers = newTabs }
	}

	var tabSelected: AnyObject? {
		get {
			if selectedTabViewItemIndex == -1 { return nil } // no tabs? bupkiss!
			return childViewControllers[selectedTabViewItemIndex]
		}
		set(obj) { if let vc = obj as? NSViewController { tabView.selectTabViewItem(tabViewItemForViewController(vc)) } }
	}

	override public func insertChildViewController(childViewController: NSViewController, atIndex index: Int) {
		conlog("#\(index)")
		super.insertChildViewController(childViewController, atIndex: index)

		if let wvc = childViewController as? WebViewController {
			let mi = NSMenuItem(title:"", action:Selector("menuSelectedTab:"), keyEquivalent:"")
			mi.bind(NSTitleBinding, toObject: wvc, withKeyPath:"view.title", options:nil)
			mi.bind(NSImageBinding, toObject: wvc, withKeyPath:"favicon", options:nil)
			mi.image?.size = NSSize(width: 16, height: 16)
			mi.representedObject = wvc // FIXME: anti-retain needed? 
			mi.target = self
			tabMenu.addItem(mi)

			//let gridItem = tabGrid.newItemForRepresentedObject(wvc)
			//gridItem.imageView = wvc.favicon
			//gridItem.textField = wvc.webview.title
		}
	}

	func menuSelectedTab(sender: AnyObject?) {
		if let mi = sender as? NSMenuItem, let wvc = mi.representedObject as? WebViewController {
			//if tabSelected == wvc {
			//	wvc.gotoButtonClicked(tabPopBtn) //prompt user to edit URL of currently-selected tab
			//} else {
				tabSelected = wvc
			//}
		}
	}

/*
	func selectedTabButtonClicked(sender: AnyObject?) {
		let urlbox = URLBoxController(webViewController: self)

		if let btn = sender? as? NSView { 
			presentViewController(urlbox, asPopoverRelativeToRect: btn.bounds, ofView: btn, preferredEdge:NSMinYEdge, behavior: .Semitransient)
		} else {
			presentViewControllerAsSheet(urlbox) //Keyboard shortcut
		}
	}
*/
/*
	func tabListButtonClicked(sender: AnyObject?) {
		if let sender = sender? as? NSView { //OpenTab toolbar button
			presentViewController(tabGrid, asPopoverRelativeToRect: sender.bounds, ofView: sender, preferredEdge:NSMinYEdge, behavior: .Semitransient)
		} else { //keyboard shortcut
			//presentViewControllerAsSheet(tabGrid) // modal, yuck
			var poprect = view.bounds
			poprect.size.height -= tabGrid.preferredContentSize.height + 12 // make room at the top to stuff the popover
			presentViewController(tabGrid, asPopoverRelativeToRect: poprect, ofView: view, preferredEdge: NSMaxYEdge, behavior: .Semitransient)
		}
	}
*/
	override public func removeChildViewControllerAtIndex(index: Int) {
		conlog("#\(index)")
		if let wvc = childViewControllers[index] as? WebViewController {

			// unassign strong property references that will cause a retain cycle
			if urlbox.representedObject === wvc { urlbox.representedObject = nil }
			if let mitem = tabMenu.itemAtIndex(tabMenu.indexOfItemWithRepresentedObject(wvc)) {
				mitem.target = nil
				mitem.representedObject = nil
				tabMenu.removeItem(mitem)
			}

		}
		super.removeChildViewControllerAtIndex(index)
	}

	override public func presentViewController(viewController: NSViewController, animator: NSViewControllerPresentationAnimator) {
		conlog("")
		super.presentViewController(viewController, animator: animator)
	}

	override public func transitionFromViewController(fromViewController: NSViewController, toViewController: NSViewController,
		options: NSViewControllerTransitionOptions, completionHandler completion: (() -> Void)?) {

		var midex = tabMenu.indexOfItemWithRepresentedObject(fromViewController)
		if midex != -1, let mitem = tabMenu.itemAtIndex(midex) { mitem.state = NSOffState }

		midex = tabMenu.indexOfItemWithRepresentedObject(toViewController)
		if midex != -1, let mitem = tabMenu.itemAtIndex(midex) { mitem.state = NSOnState }

		let tabnum = tabPopBtn.indexOfItemWithRepresentedObject(toViewController)
		if tabnum != -1 { tabPopBtn.selectItemAtIndex(tabnum) }

		urlbox.representedObject = toViewController

		super.transitionFromViewController(fromViewController, toViewController: toViewController,
			options: options, completionHandler: completion)

		//view.layer?.addSublayer(toViewController.view.layer?)

		if let window = view.window {
			window.makeFirstResponder(toViewController.view) // steal app focus to whatever the tab represents
		}
		conlog("browser title is now `\(title ?? String())`")
		conlog("focus is on `\(view.window?.firstResponder)`")
	}

	func closeCurrentTab() {
		if let tab = tabSelected as? NSViewController { tab.removeFromParentViewController() } // calls func above
		//tabSelected.removeFromParentViewController() // calls func above
		if tabs.count == 0 { view.window?.performClose(nil) }
			else { switchToNextTab() } //safari behavior
	}

	func switchToPreviousTab() { tabView.selectPreviousTabViewItem(self) }
	func switchToNextTab() { tabView.selectNextTabViewItem(self) }

	func toggleTransparency() { isTransparent = !isTransparent }

	func loadSiteApp() { JSRuntime.loadSiteApp() }
	func editSiteApp() { NSWorkspace.sharedWorkspace().openFile(NSBundle.mainBundle().resourcePath!) }

	func newTabPrompt() {
		let wvc = newTab(NSURL(string: "about:blank")!)!
		tabSelected = wvc
		wvc.gotoButtonClicked(nil)
	}

	func newTab(params: AnyObject?) -> WebViewController? {
		switch(params) {
			case let urlstr as String:
				if let url = NSURL(string: urlstr) { return newTab(url) }
				return nil
			case let url as NSURL:
				let wvc = WebViewController(agent: defaultUserAgent)
				wvc.gotoURL(url)
				addChildViewController(wvc)
				return wvc
			case let obj as [String:AnyObject]:
				if let wvc = WebViewController.createWithObj(obj) {
					addChildViewController(wvc)
					return wvc
				}
				fallthrough
			case nil: fallthrough
			default:
				return nil
		}
	}

	func addTab(vc: NSViewController) { addChildViewController(vc) }

	func conlog(msg: String, _ function: String = __FUNCTION__, _ file: String = __FILE__, _ line: Int = __LINE__, _ column: Int = __COLUMN__) {
		let logmsg = "<\(__FILE__):\(line):\(column)> [\(function)] \(msg)\n"
		NSFileHandle.fileHandleWithStandardError().writeData((logmsg).dataUsingEncoding(NSUTF8StringEncoding)!)
#if APP2JSLOG
		tabSelected?.evalJS("console.log(\'\(logmsg)\')")
#endif
	}

	func stealAppFocus() { NSApplication.sharedApplication().activateIgnoringOtherApps(true) }
	func unhideApp() {
		//windowController.showWindow(self)
		stealAppFocus()
		NSApplication.sharedApplication().unhide(self)
		NSApplication.sharedApplication().arrangeInFront(self)
		view.window?.makeKeyAndOrderFront(nil)
	}
	func bounceDock() { NSApplication.sharedApplication().requestUserAttention(.InformationalRequest) } //Critical keeps bouncing

	func printTab() {
		// https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/Printing/osxp_printapps/osxp_printapps.html#//apple_ref/doc/uid/20000861-BAJBFGED
		//var printer = NSPrintOperation(view: tabSelected!.view, printInfo: NSPrintInfo.sharedPrintInfo()) //same as webview.print()
		var printer = NSPrintOperation(view: view, printInfo: NSPrintInfo.sharedPrintInfo()) // prints 8pgs of blurView
		printer.runOperation()
	}
	
	func addBookmark(title: String, _ obj: AnyObject?) {
		if title.isEmpty {
			conlog("title not provided")
			return
		}
		switch (obj) {
			case let urlstr as String: bookmarksMenu.addItem(MenuItem(title, "gotoBookmark:", target: self, represents: ["url": urlstr]))
			case is [String:AnyObject]: bookmarksMenu.addItem(MenuItem(title, "gotoBookmark:", target: self, represents: obj))
			case nil: fallthrough
			default:
				conlog("invalid object type to represent bookmark")
				return
		}
	}

	func gotoBookmark(sender: AnyObject?) {
		if let bookmark = sender as? NSMenuItem {
			switch (bookmark.representedObject) {
				case let urlstr as String: JSRuntime.delegate.tryFunc("launchURL", urlstr)
				case let obj as [String:AnyObject]: tabSelected = newTab(obj)
				default: return
			}
		}
	}

}

extension BrowserViewController: NSMenuDelegate {
	public func menuNeedsUpdate(menu: NSMenu) {
		//switch menu.tag {
		//case 1: //historyMenu
	}
}
