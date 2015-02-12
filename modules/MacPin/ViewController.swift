let URLBoxId = "urlbox"
let ShareButton = "sharing"

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

public extension NSTabViewItem {
	// convenience props to get webview pertinents
	var webview: WKWebView? { get {
		//if let webview = viewController?.view as? WKWebView { return webview }
		if let webview = view as? WKWebView { return webview }
		return nil
	}}

	//swift 1.3 will safely perform `if let url = webview?.URL`
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

class TabViewItem: NSTabViewItem {
	//viewController.view is where the webview is set ...

	override func watchWebview() { }
	override func unwatchWebview() { }

	override var view: NSView? {
		willSet(newview) {
			if let newview = newview {
				newview.addObserver(self, forKeyPath: "title", options: .Initial | .New, context: nil)
				newview.addObserver(self, forKeyPath: "URL", options: .Initial | .New, context: nil)
			}
		}
		didSet(oldview) {
			if let oldview = oldview {
				//oldview.removeObserver(self, forKeyPath: "title")
				//oldview.removeObserver(self, forKeyPath: "URL")
			}
		}
	}

	deinit { view = nil }
}

class TabViewController: NSTabViewController { // & NSViewController

	let urlbox = URLBox() // retains some state and serves as a history go-between for WKNavigation / WKBackForwardList

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
		super.viewDidLoad()
	}
	
	override func viewWillAppear() {
		super.viewWillAppear()
		if let window = view.window {
			view.frame = window.contentLayoutRect //initial size to entire window +/- toolbar movement
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
