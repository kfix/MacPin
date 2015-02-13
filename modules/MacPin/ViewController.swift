let URLBoxId = "urlbox"
let ShareButton = "sharing"

class URLBox: NSSearchField { //NSTextField
	var tab: NSTabViewItem? {
		didSet { //KVC to copy updates to webviews url & title (user navigations, history.pushState(), window.title=)
			if let newtab = tab { 
				bind(NSToolTipBinding, toObject: newtab.view!, withKeyPath: "title", options: nil)

				//let ttPattern = "%{value1}@ [%{value2}@]";
				//bind("displayPatternValue1", toObject:newtab.view!, withKeyPath: "title", options: [NSDisplayPatternBindingOption: ttPattern])
				//bind("displayPatternValue2", toObject:newtab.view!, withKeyPath: "URL", options: [NSDisplayPatternBindingOption: ttPattern])

				bind(NSValueBinding, toObject: newtab.view!, withKeyPath: "URL", options: nil)
				//^ this seems to work bidirectionally, which crashes when user hand inputs a url
			 }
		}
		willSet(newtab) { 
			if let oldtab = tab { 
				unbind(NSToolTipBinding)
				//unbind("displayPatternValue1")
				//unbind("displayPatternValue2")
				unbind(NSValueBinding)
			 }
		}
	}
}

class TabViewController: NSTabViewController { // & NSViewController

	let urlbox = URLBox() // retains some state and serves as a history go-between for WKNavigation / WKBackForwardList

	var currentTab: NSTabViewItem? { get {
		if selectedTabViewItemIndex == -1 { return nil }
		return (tabViewItems[selectedTabViewItemIndex] as? NSTabViewItem) ?? nil
	}}

	override func addTabViewItem(tab: NSTabViewItem) {
		super.addTabViewItem(tab)
		if let view = tab.view {
			tab.bind(NSLabelBinding, toObject: view, withKeyPath: "title", options: nil)
			tab.bind(NSToolTipBinding, toObject: view, withKeyPath: "title", options: nil)
		}
	}

	//shouldSelect didSelect
	override func tabView(tabView: NSTabView, willSelectTabViewItem tabViewItem: NSTabViewItem) { 
		super.tabView(tabView, willSelectTabViewItem: tabViewItem)
		urlbox.tab = tabViewItem // make the urlbox monitor the newly-selected tab's webview (if any)
		if let window = view.window {
			window.unbind(NSTitleBinding)
			window.bind(NSTitleBinding, toObject: tabViewItem.view!, withKeyPath: "title", options: nil)
		}
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
				urlbox.textColor = NSColor.controlTextColor() 
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

	override func loadView() {
		tabView = NSTabView()
		tabView.identifier = "NSTabView"
		tabView.tabViewType = .NoTabsNoBorder
		tabView.drawsBackground = false // let the window be the background
		super.loadView()
	}

	override func viewDidLoad() {
		identifier = "NSTabViewController"
		view.wantsLayer = true //use CALayer to coalesce views
		view.autoresizingMask = .ViewWidthSizable | .ViewHeightSizable //resize tabview to match parent ContentView size
		tabStyle = .Toolbar // this will reinit window.toolbar to mirror the tabview itembar
		transitionOptions = .None //.Crossfade .SlideUp/Down/Left/Right/Forward/Backward
		view.frame = NSMakeRect(0, 0, 600, 800) // default size
		super.viewDidLoad()
	}
	
	override func viewWillAppear() {
		super.viewWillAppear()
		if let window = view.window {
			window.toolbar!.allowsUserCustomization = false
			window.showsToolbarButton = false
		}
	}

	/*
	override func viewWillLayout() {
		println("viewWillLayout() \(view.frame)")
		super.viewWillLayout()
	}
	*/
}
