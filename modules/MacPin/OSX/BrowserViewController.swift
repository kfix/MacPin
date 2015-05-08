/// MacPin BrowserViewController
///
/// A tabbed contentView for OSX

import WebKit // https://github.com/WebKit/webkit/blob/master/Source/WebKit/mac/ChangeLog
import Foundation
import JavaScriptCore //  https://github.com/WebKit/webkit/tree/master/Source/JavaScriptCore/API

@objc protocol BrowserScriptExports : JSExport { // '$browser' in app.js
	var defaultUserAgent: String? { get set } // full UA used for any new tab without explicit UA specified
	var isFullscreen: Bool { get set }
	var isToolbarShown: Bool { get set }
	//var tabs: [AnyObject] { get } // alias to childViewControllers
	var tabs: [MPWebView] { get }
	var childViewControllers: [AnyObject] { get set } // .push() doesn't work nor trigger property observer
	var tabSelected: AnyObject? { get set }
	func addTab(webview: MPWebView)
	func close()
	func switchToNextTab()
	func switchToPreviousTab()
	func newTabPrompt()
	func focusOnBrowser()
	func unhideApp()
	func bounceDock()
	func addShortcut(title: String, _ obj: AnyObject?)
}

@objc class TabViewController: NSTabViewController {
	required init?(coder: NSCoder) { super.init(coder: coder) } // required by NSCoder
	override init!(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) { super.init(nibName:nil, bundle:nil) } // calls loadView() 

	let omnibox = OmniBoxController() // we could & should only present one of these at a time
	lazy var tabPopBtn = NSPopUpButton(frame: NSRect(x:0, y:0, width:400, height:24), pullsDown: false)
	let tabMenu = NSMenu() // list of all active web tabs
	let shortcutsMenu = NSMenu()
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

	let OmniBox	= "Search or Go To URL"
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

	override func insertTabViewItem(tab: NSTabViewItem, atIndex: Int) {
		if let view = tab.view {
			tab.initialFirstResponder = view
			tab.bind(NSLabelBinding, toObject: view, withKeyPath: "title", options: nil)
			tab.bind(NSToolTipBinding, toObject: view, withKeyPath: "title", options: nil)
			//if let wvc = tab.viewController as? WebViewController {
			//	tab.bind(NSImageBinding, toObject: wvc.favicon, withKeyPath: "icon", options: nil)
			//}
			if let wv = tab.viewController?.representedObject as? MPWebView {
				tab.bind(NSImageBinding, toObject: wv.favicon, withKeyPath: "icon", options: nil)
			}

		}
		super.insertTabViewItem(tab, atIndex: atIndex)
	}

	override func removeTabViewItem(tab: NSTabViewItem) {
		if let view = tab.view {
			tab.initialFirstResponder = nil
			tab.unbind(NSLabelBinding)
			tab.unbind(NSToolTipBinding)
			if let wvc = tab.viewController?.representedObject as? MPWebView {
				tab.unbind(NSImageBinding)
			}
			tab.label = ""
			tab.toolTip = nil
			tab.image = nil
		}
		super.removeTabViewItem(tab)
		tabView.selectNextTabViewItem(self) //safari behavior
	}

	override func tabView(tabView: NSTabView, willSelectTabViewItem tabViewItem: NSTabViewItem) { 
		super.tabView(tabView, willSelectTabViewItem: tabViewItem)
		//if omnibox.webview != nil { omnibox.unbind("webview") }
		if let wv = tabViewItem.view as? MPWebView {
			//omnibox.bind("webview", toObject: tabViewItem, withKeyPath: "view", options: nil)
			omnibox.webview = wv
		}
	}

	override func tabView(tabView: NSTabView, didSelectTabViewItem tabViewItem: NSTabViewItem) { 
		super.tabView(tabView, didSelectTabViewItem: tabViewItem)
		if let window = view.window, view = tabViewItem.view {
			window.makeFirstResponder(view) // steal app focus to whatever the tab represents
		}
	}

	override func tabViewDidChangeNumberOfTabViewItems(tabView: NSTabView) {
		warn("@\(tabView.tabViewItems.count)") 
		if tabView.tabViewItems.count == 0 { view.window?.performClose(nil) }
	}

	override func toolbarAllowedItemIdentifiers(toolbar: NSToolbar) -> [AnyObject] { 
		let tabs = super.toolbarAllowedItemIdentifiers(toolbar) ?? []
		return tabs + [
			NSToolbarSeparatorItemIdentifier,
			NSToolbarSpaceItemIdentifier,
			NSToolbarFlexibleSpaceItemIdentifier,
			NSToolbarShowColorsItemIdentifier,
			NSToolbarShowFontsItemIdentifier,
			NSToolbarCustomizeToolbarItemIdentifier,
			NSToolbarPrintItemIdentifier,
			OmniBox, ShareButton, NewTabButton, CloseTabButton,
			ForwardButton, BackButton, RefreshButton, SelectedTabButton
		]
	}

	override func toolbarDefaultItemIdentifiers(toolbar: NSToolbar) -> [AnyObject] { 
		let tabs = super.toolbarDefaultItemIdentifiers(toolbar) ?? []
		//return [ShareButton, NewTabButton] + tabs + [NSToolbarFlexibleSpaceItemIdentifier]
		return [ShareButton, NewTabButton] + tabs + [OmniBox]
		//return [ShareButton, NewTabButton, NSToolbarFlexibleSpaceItemIdentifier] + tabs
		//return [NSToolbarFlexibleSpaceItemIdentifier, ShareButton] + tabs! + [NewTabButton, NSToolbarFlexibleSpaceItemIdentifier]
		//return [NSToolbarFlexibleSpaceItemIdentifier, ShareButton, NSToolbarFlexibleSpaceItemIdentifier] + tabs + [NSToolbarFlexibleSpaceItemIdentifier, NewTabButton, NSToolbarFlexibleSpaceItemIdentifier]
		//return [ShareButton, NewTabButton, CloseTabButton, BackButton, ForwardButton, RefreshButton,SelectedTabButton, OmniBox] + tabs + [NSToolbarFlexibleSpaceItemIdentifier]
		//tabviewcontroller somehow remembers where tabs! was and keeps putting new tabs in that position
	}

	override func toolbar(toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: String, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
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
				btn.action = Selector("closeTab")
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


			case OmniBox:
				ti.minSize = CGSize(width: 70, height: 24)
				ti.maxSize = CGSize(width: 600, height: 24)
				ti.view = flag ? omnibox.view : NSTextField()
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

	override func loadView() {
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

	override func viewDidLoad() {
		identifier = "TabViewController"
		tabStyle = .Toolbar // this will reinit window.toolbar to mirror the tabview itembar
		//tabStyle = .Unspecified
		//tabStyle = .SegmentedControlOnTop
		//tabStyle = .SegmentedControlOnBottom

		// http://www.raywenderlich.com/2502/calayers-tutorial-for-ios-introduction-to-calayers-tutorial
		view.wantsLayer = true //use CALayer
		view.layer?.cornerRadius = cornerRadius
		view.layer?.masksToBounds = true // include layer contents in clipping effects
		view.canDrawSubviewsIntoLayer = true // coalesce all subviews' layers into this one

		view.autoresizingMask = .ViewWidthSizable | .ViewHeightSizable //resize tabview to match parent ContentView size
		view.autoresizesSubviews = true // resize tabbed subviews based on their autoresizingMasks
		transitionOptions = .None //.Crossfade .SlideUp/Down/Left/Right/Forward/Backward

		super.viewDidLoad()
		view.registerForDraggedTypes([NSPasteboardTypeString,NSURLPboardType,NSFilenamesPboardType]) //webviews already do this, this just enables openURL when tabless
	}
	
	override func viewWillAppear() {
		super.viewWillAppear()
	}

	override func viewDidAppear() {
		super.viewDidAppear()
		let toolbar = view.window?.toolbar ?? NSToolbar(identifier: "toolbar")
		toolbar.delegate = self
		toolbar.allowsUserCustomization = true
		toolbar.displayMode = .IconOnly
		toolbar.sizeMode = .Small //favicons are usually 16*2
		view.window?.toolbar = toolbar
		view.window?.excludedFromWindowsMenu = true
	}

	func draggingEntered(sender: NSDraggingInfo) -> NSDragOperation { return NSDragOperation.Every }
	func performDragOperation(sender: NSDraggingInfo) -> Bool { return true } //should open the file:// url
}

class BrowserViewController: TabViewController, BrowserScriptExports {

	convenience init() {
		self.init(nibName: nil, bundle: nil)
	}

	deinit { warn(description) }
	override var description: String { return "<\(reflect(self).summary)> `\(title ?? String())`" }

	var defaultUserAgent: String? = nil // {
	//	get { }
	//	set(ua) { NSUserDefaults.standardUserDefaults().setString(ua, forKey: "UserAgent") } //only works on IOS
	//} // https://github.com/WebKit/webkit/blob/master/Source/WebCore/page/NavigatorBase.cpp
	// https://github.com/WebKit/webkit/blob/master/Source/WebCore/page/mac/UserAgentMac.mm

	var isFullscreen: Bool { 
		get { return (view.window?.contentView as? NSView)?.inFullScreenMode ?? false }
		set(bool) { if bool != isFullscreen { view.window!.toggleFullScreen(nil) } }
	}

	var isToolbarShown: Bool { 
		get { return view.window?.toolbar?.visible ?? true }
		set(bool) { if bool != isToolbarShown { view.window!.toggleToolbarShown(nil) } }
	}

	//var tabs: [AnyObject] { return childViewControllers } // alias
					
	var tabs: [MPWebView] { return childViewControllers.filter({ $0 is WebViewControllerOSX }).map({ $0.webview }) }
	// set { } ? trying to get `$.browser.tabs.push(new $.WebView({}))` to work

 	//override var childViewControllers: [AnyObject] { didSet { warn(childViewControllers.count.description); warn(childViewControllers.description) } } //no workie

	var tabSelected: AnyObject? {
		get {
			if selectedTabViewItemIndex == -1 { return nil } // no tabs? bupkiss!
			if let vc = childViewControllers[selectedTabViewItemIndex] as? NSViewController {
				if let obj: AnyObject = vc.representedObject { return obj } // try returning an actual model first
				return vc
			}
			return nil
		}
		set(obj) {
			switch (obj) { 
				case let vc as NSViewController:
					//if (find(childViewControllers, obj) ?? -1) < 0 { childViewControllers.append(obj) } // add the given vc as a child if it isn't already
					//if !contains(childViewControllers, vc) { childViewControllers.append(obj) } // add the given vc as a child if it isn't already
					//if childViewControllers.containsObject(obj) { childViewControllers.append(obj) } // add the given vc as a child if it isn't already
					if tabViewItemForViewController(vc) == nil { childViewControllers.append(vc) } // add the given vc as a child if it isn't already
					tabView.selectTabViewItem(tabViewItemForViewController(vc))
				case let wv as MPWebView:
					// find the view's existing controller or else make one
					let wvc = childViewControllers.filter({ ($0 as? WebViewControllerOSX)?.webview === wv }).first as? WebViewControllerOSX ?? WebViewControllerOSX(webview: wv)
					if tabViewItemForViewController(wvc) == nil { childViewControllers.append(wvc) } // add the given vc as a child if it isn't already
					tabView.selectTabViewItem(tabViewItemForViewController(wvc))
				default:
					warn("invalid object")		
			}
		}
	}


	override func insertChildViewController(childViewController: NSViewController, atIndex index: Int) {
		warn("#\(index)")
		super.insertChildViewController(childViewController, atIndex: index)

		if let wvc = childViewController as? WebViewController {
			let mi = NSMenuItem(title:"", action:Selector("menuSelectedTab:"), keyEquivalent:"")
			mi.bind(NSTitleBinding, toObject: wvc.webview, withKeyPath: "title", options:nil)
			mi.bind(NSImageBinding, toObject: wvc.webview, withKeyPath: "favicon.icon", options: nil)
			mi.image?.size = NSSize(width: 16, height: 16)
			mi.representedObject = wvc // FIXME: anti-retain needed? 
			mi.target = self
			tabMenu.addItem(mi)
			//if omnibox.webview == nil { omnibox.webview = wv } //very first tab added

			//let gridItem = tabGrid.newItemForRepresentedObject(wvc)
			//gridItem.imageView = wv.favicon.icon
			//gridItem.textField = wv.title
		}
	}

	func menuSelectedTab(sender: AnyObject?) {
		//if let mi = sender as? NSMenuItem, let wvc = mi.representedObject as? WebViewController { tabSelected = wvc }
		if let mi = sender as? NSMenuItem, wv = mi.representedObject as? MPWebView { tabSelected = wv }
	}

/*
	func selectedTabButtonClicked(sender: AnyObject?) {
		let omnibox = OmniBoxController(webViewController: self)

		if let btn = sender? as? NSView { 
			presentViewController(omnibox, asPopoverRelativeToRect: btn.bounds, ofView: btn, preferredEdge:NSMinYEdge, behavior: .Semitransient)
		} else {
			presentViewControllerAsSheet(omnibox) //Keyboard shortcut
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
	override func removeChildViewControllerAtIndex(index: Int) {
		warn("#\(index)")
		if let wvc = childViewControllers[index] as? WebViewController {

			// unassign strong property references that will cause a retain cycle
			//if omnibox.representedObject === wvc { omnibox.representedObject = nil }
			//if omnibox.webview === wvc.webview { omnibox.webview = nil }
			if let mitem = tabMenu.itemAtIndex(tabMenu.indexOfItemWithRepresentedObject(wvc)) {
				mitem.unbind(NSTitleBinding)
				mitem.unbind(NSImageBinding)
				mitem.target = nil
				mitem.representedObject = nil
				tabMenu.removeItem(mitem)
			}

		}
		super.removeChildViewControllerAtIndex(index)
	}

	override func presentViewController(viewController: NSViewController, animator: NSViewControllerPresentationAnimator) {
		warn()
		super.presentViewController(viewController, animator: animator)
	}

	override func transitionFromViewController(fromViewController: NSViewController, toViewController: NSViewController,
		options: NSViewControllerTransitionOptions, completionHandler completion: (() -> Void)?) {

		var midex = tabMenu.indexOfItemWithRepresentedObject(fromViewController)
		if midex != -1, let mitem = tabMenu.itemAtIndex(midex) { mitem.state = NSOffState }

		midex = tabMenu.indexOfItemWithRepresentedObject(toViewController)
		if midex != -1, let mitem = tabMenu.itemAtIndex(midex) { mitem.state = NSOnState }

		let tabnum = tabPopBtn.indexOfItemWithRepresentedObject(toViewController)
		if tabnum != -1 { tabPopBtn.selectItemAtIndex(tabnum) }

		super.transitionFromViewController(fromViewController, toViewController: toViewController,
			options: options, completionHandler: completion)

		//view.layer?.addSublayer(toViewController.view.layer?)

		if let window = view.window {
			window.makeFirstResponder(toViewController.view) // steal app focus to whatever the tab represents
			//warn("focus is on `\(view.window?.firstResponder)`")
		}

		//warn("browser title is now `\(title ?? String())`")
	}

	// menu & shortcut selectors //////////////////////////////

	func close() { view.window?.performClose(nil) }
	func switchToPreviousTab() { tabView.selectPreviousTabViewItem(self) }
	func switchToNextTab() { tabView.selectNextTabViewItem(self) }

	func loadSiteApp() { JSRuntime.loadSiteApp() }
	func editSiteApp() { NSWorkspace.sharedWorkspace().openFile(NSBundle.mainBundle().resourcePath!) }

	func newTabPrompt() {
		//tabSelected = WebViewControllerOSX(url: NSURL(string: "about:blank")!)
		tabSelected = MPWebView(url: NSURL(string: "about:blank")!)
		revealOmniBox()
	}

	func revealOmniBox() {
		if omnibox.view.window != nil {
			// if omnibox is already visible somewhere in the window, move key focus there
			view.window?.makeFirstResponder(omnibox.view)
		} else {
			// otherwise, present it as a sheet or popover aligned under the window-top/toolbar
			//presentViewControllerAsSheet(omnibox) // modal, yuck
			var poprect = view.bounds
			poprect.size.height -= omnibox.preferredContentSize.height + 12 // make room at the top to stuff the popover
			presentViewController(omnibox, asPopoverRelativeToRect: poprect, ofView: view, preferredEdge: NSMaxYEdge, behavior: NSPopoverBehavior.Semitransient)
		}
	}

	func addTab(wv: MPWebView) { addChildViewController(WebViewControllerOSX(webview: wv)) }

	func focusOnBrowser() {  // un-minimizes app, switches to its screen/space, and steals key focus to the window
		//NSApplication.sharedApplication().activateIgnoringOtherApps(true)
		let app = NSRunningApplication.currentApplication()
		app.unhide() // un-minimize app
		app.activateWithOptions(.ActivateIgnoringOtherApps) // brings up key window
		view.window?.makeKeyAndOrderFront(nil) // steals key focus
	}

	func unhideApp() { // un-minimizes app, but doesn't steal key focus or screen or menubar
		let app = NSRunningApplication.currentApplication()
		app.unhide() // un-minimize app
		app.activateWithOptions(.ActivateIgnoringOtherApps) // brings up key window
		view.window?.makeKeyAndOrderFront(nil) // steals key focus
/*
		//windowController.showWindow(self)
		NSApplication.sharedApplication().unhide(self)
		NSApplication.sharedApplication().arrangeInFront(self)
		view.window?.makeKeyAndOrderFront(nil)
*/
	}

	func bounceDock() { NSApplication.sharedApplication().requestUserAttention(.InformationalRequest) } //Critical keeps bouncing

	func printTab() {
		// https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/Printing/osxp_printapps/osxp_printapps.html#//apple_ref/doc/uid/20000861-BAJBFGED
		//var printer = NSPrintOperation(view: tabSelected!.view, printInfo: NSPrintInfo.sharedPrintInfo()) //same as webview.print()
		var printer = NSPrintOperation(view: view, printInfo: NSPrintInfo.sharedPrintInfo()) // prints 8pgs of blurView
		printer.runOperation()
	}
	
	func addShortcut(title: String, _ obj: AnyObject?) {
		if title.isEmpty {
			warn("title not provided")
			return
		}
		switch (obj) {
			case let urlstr as String: shortcutsMenu.addItem(MenuItem(title, "gotoShortcut:", target: self, represents: ["url": urlstr]))
			case is [String:AnyObject]: shortcutsMenu.addItem(MenuItem(title, "gotoShortcut:", target: self, represents: obj))
			case nil: fallthrough
			default:
				warn("invalid object type to represent bookmark")
				return
		}
	}

	func gotoShortcut(sender: AnyObject?) {
		if let shortcut = sender as? NSMenuItem {
			switch (shortcut.representedObject) {
				case let urlstr as String: JSRuntime.jsdelegate.tryFunc("launchURL", urlstr)
				// or fire event in jsdelegate if string, NSURLs do launchURL
				case let obj as [String:AnyObject]: tabSelected = MPWebView(object: obj)
				default: return
			}
		}
	}
}

extension BrowserViewController: NSMenuDelegate {
	func menuNeedsUpdate(menu: NSMenu) {
		//switch menu.tag {
		//case 1: //historyMenu
	}
}
