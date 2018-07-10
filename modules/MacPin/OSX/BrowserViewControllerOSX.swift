/// MacPin BrowserViewController
///
/// A tabbed contentView for OSX

import WebKit // https://github.com/WebKit/webkit/blob/master/Source/WebKit/mac/ChangeLog
import WebKitPrivates
import Foundation
import JavaScriptCore //  https://github.com/WebKit/webkit/tree/master/Source/JavaScriptCore/API

// http://stackoverflow.com/a/24128149/3878712
struct WeakThing<T: AnyObject> {
  weak var value: T?
  init (value: T) {
    self.value = value
  }
}

@objc class TabViewController: NSTabViewController {
	required init?(coder: NSCoder) { super.init(coder: coder) } // required by NSCoder
	override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) { super.init(nibName:nil, bundle:nil) } // calls loadView()
	let startPage = URL(string: "about:blank")!
	let omnibox = OmniBoxController() // we could & should only present one of these at a time
	lazy var tabPopBtn = NSPopUpButton(frame: NSRect(x:0, y:0, width:400, height:24), pullsDown: false)
	@objc let tabMenu = NSMenu() // list of all active web tabs
	@objc let shortcutsMenu = NSMenu()
	//lazy var tabFlow = TabFlowController()
	lazy var sidebar = TabGridController(tvc: self)
	/*
	lazy var tabFlow: NSCollectionView = {
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

	enum BrowserButtons: String {
		case OmniBox		= "Search or Go To URL"
		case Share			= "Share URL"
		case Snapshot		= "Snapshot"
		case Sidebar		= "Sidebar"
		case NewTab			= "Open New Tab"
		case CloseTab		= "Close Tab"
		case SelectedTab	= "Selected Tab"
		case Back			= "Back"
		case Forward		= "Forward"
		case ForwardBack	= "Forward & Back"
		case Refresh		= "Refresh"
		case TabList		= "Tabs"
	}

	var cornerRadius = CGFloat(0.0) // increment above 0.0 to put nice corners on the window FIXME userDefaults

	@objc func close() { // close all tabs
		self.omnibox.webview = nil
		self.view.window?.makeFirstResponder(nil)

		self.tabViewItems.forEach { // quickly close any remaining tabs
			//dismissViewController($0.viewController?)
			$0.view?.removeFromSuperviewWithoutNeedingDisplay()
			self.removeTabViewItem($0)
		}
		// last webview should be released and deinit'd now

		// FIXME: dispatch a browserClose notification
		self.view.window?.windowController?.close() // kicks off automatic app termination
	}

	override func insertTabViewItem(_ tab: NSTabViewItem, at: Int) {
		warn()
		if let view = tab.view {
			tab.initialFirstResponder = view
			if let wvc = tab.viewController as? WebViewController, wvc.webview.isDescendant(of: view) {
				tab.initialFirstResponder = wvc.webview
				tab.bind(NSBindingName.label, to: wvc.webview, withKeyPath: #keyPath(MPWebView.title), options: nil)
				tab.bind(NSBindingName.toolTip, to: wvc.webview, withKeyPath: #keyPath(MPWebView.title), options: nil)
				//tab.bind(NSBindingName.image, to: wvc.favicon, withKeyPath: #keyPath(FavIcon.icon), options: nil) // retains wvc forever
				tab.bind(NSBindingName.image, to: wvc.webview.favicon, withKeyPath: #keyPath(FavIcon.icon), options: nil)
			}
		} else {
			warn("no view for tabviewitem!!")
		}
		super.insertTabViewItem(tab, at: at)
	}

	//@objc override func addTabViewItem(_ tab: NSTabViewItem) {}
		// I think NSTabViewController uses insertTVI(:at:) exclusively ...

	override func removeTabViewItem(_ tab: NSTabViewItem) {
		if let view = tab.view {
			if tab.viewController is WebViewController {
				tab.unbind(NSBindingName.label)
				tab.unbind(NSBindingName.toolTip)
				tab.unbind(NSBindingName.image)
			}
			if let webview = omnibox.webview, webview.isDescendant(of: view) {
				omnibox.webview = nil
			}
		}
		if let wvc = tab.viewController as? WebViewControllerOSX {
			wvc.dismiss() // remove retainers
		}

		tab.initialFirstResponder = nil
		tab.label = ""
		tab.toolTip = nil
		tab.image = nil
		//tab.viewController = nil // attempt to insert nil object from objects[0]

		super.removeTabViewItem(tab)
	}

	//override func tabView(_ tabView: NSTabView, shouldSelect tabViewItem: NSTabViewItem?) -> Bool { return true }

	//override func tabView(_ tabView: NSTabView, willSelect tabViewItem: NSTabViewItem?) {
	//	super.tabView(tabView, willSelect: tabViewItem)
	//}

	override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
		super.tabView(tabView, didSelect: tabViewItem)
		if let window = self.view.window, let view = tabViewItem?.view, let ifr = tabViewItem?.initialFirstResponder, let frv = window.firstResponder as? NSView {
			//warn("focus is on `\(frv)`")
			if !frv.isDescendant(of: omnibox.view) && !frv.isDescendant(of: view) {
				window.makeFirstResponder(ifr) // steal app focus to whatever the tab represents
				//warn("focus moved to `\(window.firstResponder)`")
			}
		}
	}

	override func tabViewDidChangeNumberOfTabViewItems(_ tabView: NSTabView) {
		warn("@\(tabView.tabViewItems.count)")
	}

	override func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
		let tabs = super.toolbarAllowedItemIdentifiers(toolbar)
		warn(tabs.description)
		return (tabs as [NSToolbarItem.Identifier]) + ([
			.separator,
			.space,
			.flexibleSpace,
			.showColors,
			.showFonts,
			.customizeToolbar,
			.print,
			NSToolbarItem.Identifier(rawValue: BrowserButtons.OmniBox.rawValue),
			NSToolbarItem.Identifier(rawValue: BrowserButtons.Share.rawValue),
			NSToolbarItem.Identifier(rawValue: BrowserButtons.Snapshot.rawValue),
			NSToolbarItem.Identifier(rawValue: BrowserButtons.Sidebar.rawValue),
			NSToolbarItem.Identifier(rawValue: BrowserButtons.NewTab.rawValue),
			NSToolbarItem.Identifier(rawValue: BrowserButtons.CloseTab.rawValue),
			NSToolbarItem.Identifier(rawValue: BrowserButtons.SelectedTab.rawValue),
			NSToolbarItem.Identifier(rawValue: BrowserButtons.Back.rawValue),
			NSToolbarItem.Identifier(rawValue: BrowserButtons.Forward.rawValue),
			NSToolbarItem.Identifier(rawValue: BrowserButtons.ForwardBack.rawValue),
			NSToolbarItem.Identifier(rawValue: BrowserButtons.Refresh.rawValue),
			NSToolbarItem.Identifier(rawValue: BrowserButtons.TabList.rawValue)
		] as [NSToolbarItem.Identifier])
	}

	override func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
		let tabs = super.toolbarDefaultItemIdentifiers(toolbar)
		// TODO: make a custom item view for tab buttons so we can impl on-hover/alt-click actions
		return [
			NSToolbarItem.Identifier(rawValue: BrowserButtons.Share.rawValue),
			NSToolbarItem.Identifier(rawValue: BrowserButtons.NewTab.rawValue),
			//NSToolbarItem.Identifier(rawValue: BrowserButtons.Snapshot.rawValue),
			//NSToolbarItem.Identifier(rawValue: BrowserButtons.Sidebar.rawValue)
		] + tabs + [
			NSToolbarItem.Identifier(rawValue: BrowserButtons.OmniBox.rawValue)
			// [NSToolbarFlexibleSpaceItemIdentifier]
		]
		//tabviewcontroller remembers where tabs was and keeps pushing new tabs to that position
	}

	override func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
		if let btnType = BrowserButtons(rawValue: itemIdentifier.rawValue) {
			let ti = NSToolbarItem(itemIdentifier: itemIdentifier)
			ti.minSize = CGSize(width: 24, height: 24)
			ti.maxSize = CGSize(width: 36, height: 36)
			ti.visibilityPriority = .low
			ti.paletteLabel = itemIdentifier.rawValue

			let btn = NSButton()
			//let btnCell = btn.cell
			//btnCell.controlSize = .SmallControlSize
			btn.toolTip = itemIdentifier.rawValue
			btn.image = NSImage(named: NSImage.Name.preferencesGeneral) // https://hetima.github.io/fucking_nsimage_syntax/
			btn.bezelStyle = .recessed // RoundRectBezelStyle ShadowlessSquareBezelStyle
			btn.setButtonType(.momentaryLight) //MomentaryChangeButton MomentaryPushInButton
			btn.target = nil // walk the Responder Chain
			btn.sendAction(on: .leftMouseDown)
			ti.view = btn

			switch (btnType) {
				case .Share:
					btn.image = NSImage(named: NSImage.Name.shareTemplate)
					btn.action = #selector(WebViewControllerOSX.shareButtonClicked(_:))
					return ti

				case .Sidebar:
					btn.image = NSImage(named: NSImage.Name.touchBarSidebarTemplate)
					btn.action = #selector(BrowserViewControllerOSX.sidebarButtonClicked(_:))
					return ti

				case .Snapshot:
					btn.image = NSImage(named: NSImage.Name.quickLookTemplate)
					btn.action = #selector(WebViewControllerOSX.snapshotButtonClicked(_:))
					return ti

				//case .Inspect: // NSMagnifyingGlass
				case .NewTab:
					btn.image = NSImage(named: NSImage.Name.addTemplate)
					btn.action = #selector(BrowserViewControllerOSX.newTabPrompt)
					return ti

				case .CloseTab:
					btn.image = NSImage(named: NSImage.Name.removeTemplate)
					btn.action = #selector(BrowserViewControllerOSX.closeTab(_:))
					return ti

				case .Forward:
					btn.image = NSImage(named: NSImage.Name.goRightTemplate)
					btn.action = #selector(WebView.goForward(_:))
					return ti

				case .Back:
					btn.image = NSImage(named: NSImage.Name.goLeftTemplate)
					btn.action = #selector(WebView.goBack(_:))
					return ti

				case .ForwardBack:
					let seg = NSSegmentedControl()
					seg.segmentCount = 2
					seg.segmentStyle = .separated
					let segCell = seg.cell as! NSSegmentedCell
					seg.trackingMode = .momentary
					seg.action = #selector(WebView.goBack(_:))

					seg.setImage(NSImage(named: NSImage.Name.goLeftTemplate), forSegment: 0)
					//seg.setLabel(BackButton, forSegment: 0)
					//seg.setMenu(backMenu, forSegment: 0) // wvc.webview.backForwardList.backList (WKBackForwardList)
					segCell.setTag(0, forSegment: 0)

					seg.setImage(NSImage(named: NSImage.Name.goRightTemplate), forSegment: 1)
					//seg.setLabel(ForwardButton, forSegment: 1)
					segCell.setTag(1, forSegment: 1)

					ti.maxSize = CGSize(width: 54, height: 36)
					ti.view = seg
					return ti

				case .Refresh:
					btn.image = NSImage(named: NSImage.Name.refreshTemplate)
					btn.action = #selector(WebView.reload)
					return ti

				case .SelectedTab:
					ti.minSize = CGSize(width: 70, height: 24)
					ti.maxSize = CGSize(width: 600, height: 36)
					tabPopBtn.menu = tabMenu
					//tabPopBtn.menu?.itemAtIndex(0).setView(tabFlow.view) // GridMenu display
					// https://developer.apple.com/library/mac/documentation/Cocoa/Reference/ApplicationKit/Classes/NSMenu_Class/index.html#//apple_ref/occ/instm/NSMenu/popUpMenuPositioningItem:atLocation:inView:
					ti.view = flag ? tabPopBtn : NSPopUpButton()
					return ti


				case .TabList:
					btn.image = NSImage(named: NSImage.Name(rawValue: "ToolbarButtonTabOverviewTemplate.pdf"))
					//btn.action = #selector(BrowserViewControllerOSX.tabListButtonClicked(sender:))
					return ti

				case .OmniBox:
					ti.minSize = CGSize(width: 70, height: 24)
					ti.maxSize = CGSize(width: 600, height: 24)
					ti.view = flag ? omnibox.view : NSTextField()
					return ti
			}
		} else {
			// let NSTabViewController map a TabViewItem to this ToolbarItem
			let tvi = super.toolbar(toolbar, itemForItemIdentifier: itemIdentifier, willBeInsertedIntoToolbar: flag)
			return tvi
		}
	}

	 //override func toolbarWillAddItem(notification: NSNotification) { warn(notification.description) }
	 //	if let ti = notification.userInfo?["item"] as? NSToolbarItem, tb = ti.toolbar, tgt = ti.target as? TabViewController, btn = t i.view as? NSButton { warn(ti.itermIdentifier) }
	 //override func toolbarDidRemoveItem(notification: NSNotification) { warn(notification.description) }

	override func loadView() {
		//tabView.autoresizesSubviews = false
		//tabView.translatesAutoresizingMaskIntoConstraints = false
		super.loadView()
	}

	override func viewDidLoad() {
		// note, .view != tabView, view wraps tabView + whatever tabStyle is selected
		tabView.tabViewType = .noTabsNoBorder
		tabView.drawsBackground = false // let the window be the background
		identifier = NSUserInterfaceItemIdentifier(rawValue: "TabViewController")
		tabStyle = .toolbar // this will reinit window.toolbar to mirror the tabview itembar
		//tabStyle = .Unspecified
		//tabStyle = .SegmentedControlOnTop
		//tabStyle = .SegmentedControlOnBottom

		// http://www.raywenderlich.com/2502/calayers-tutorial-for-ios-introduction-to-calayers-tutorial
		view.wantsLayer = true //use CALayer
		view.layer?.cornerRadius = cornerRadius
		view.layer?.masksToBounds = true // include layer contents in clipping effects
		view.canDrawSubviewsIntoLayer = true // coalesce all subviews' layers into this one

		view.autoresizingMask = [.width, .height] //resize tabview to match parent ContentView size
		view.autoresizesSubviews = true // resize tabbed subviews based on their autoresizingMasks
		transitionOptions = [] //.Crossfade .SlideUp/Down/Left/Right/Forward/Backward

		super.viewDidLoad()
		view.registerForDraggedTypes([NSPasteboard.PasteboardType.string,NSURLPboardType,NSPasteboard.PasteboardType.fileURL]) //webviews already do this, this just enables openURL when tabless
	}

	override func viewWillAppear() {
		super.viewWillAppear()
	}

	override func viewDidAppear() {
		super.viewDidAppear()
		if let window = view.window, let toolbar = window.toolbar {

			// NStvc's toolbar delegation was broken on 10.11.[01] http://www.openradar.me/22348095
			// https://docs.swift.org/swift-book/LanguageGuide/ControlFlow.html#ID523
			if #available(OSX 10.11.2, *) {
				// fixed in 10.11.2 final https://forums.developer.apple.com/thread/14237#88260
				toolbar.delegate = self
			} else if #available(OSX 10.11, *) {
				// thems the breaks
			} else if #available(OSX 10.10, *) {
				toolbar.delegate = self
			}

			// http://robin.github.io/cocoa/mac/2016/03/28/title-bar-and-toolbar-showcase/
			toolbar.allowsUserCustomization = true
			toolbar.displayMode = .iconOnly
			toolbar.sizeMode = .small //favicons are usually 16*2
		}
		view.window?.isExcludedFromWindowsMenu = true
	}

	func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { return NSDragOperation.every }
	func performDragOperation(_ sender: NSDraggingInfo) -> Bool { return true } //should open the file:// url
}

class BrowserViewControllerOSX: TabViewController, BrowserViewController {

	@objc dynamic var tabsArray = [WebViewController]()
	//var tabsController = NSArrayController()

	lazy var windowController: WindowController = {
		var effectController = EffectViewController()
		let win = NSWindow(contentViewController: effectController)

		let wc = WindowController(window: win)
		wc.window?.initialFirstResponder = self.view // should defer to selectedTab.initialFirstRepsonder
		//wc.window?.initialFirstResponder = omnibox.view // crashy! must put a nil somewhere in the responder chain...
		wc.window?.bind(NSBindingName.title, to: self, withKeyPath: #keyPath(BrowserViewController.title), options: nil)
		effectController.view.addSubview(self.view)
		self.view.frame = effectController.view.bounds
		return wc
	}()

	func present() -> WindowController {
		warn()
		if let win = self.windowController.window { // inits window
			win.makeKeyAndOrderFront(self)
			if self.selectedTabViewItemIndex > -1 {
				let vc = childViewControllers[selectedTabViewItemIndex]
				self.prepareTab(vc) // retroactively prep current Tab (JS may have made some headlessly)
			}
		}

		return windowController
	}

	convenience init() {
		self.init(nibName: nil, bundle: nil)

		tabMenu.delegate = self

		let center = NotificationCenter.default
		let mainQueue = OperationQueue.main
		var token: NSObjectProtocol?
		token = center.addObserver(forName: NSWindow.willCloseNotification, object: nil, queue: mainQueue) { [weak self] (note) in //object: self.view.window?
			//warn("window closed notification!")
			center.removeObserver(token!) // prevent notification loop by close()
			//warn(obj: self)
		}
		center.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: mainQueue) { [weak self] (note) in //object: self.view.window?
			//warn("application closed notification!")
		}

		//tabsController.automaticallyRearrangesObjects = false
		//tabsController.entityName = "foo"
	}

	convenience required init?(object: JSValue) {
		// consuming JSValue so we can perform custom/recursive conversion instead of JSExport's stock WrapperMap
		// https://stackoverflow.com/a/36120929/3878712

	/*
		if object.isString { // new WebView("http://webkit.org");
			guard let urlstr = object.toString(), let url = URL(string: urlstr) else { return nil }
			self.init(url: url)
		} else if object.isObject { // new WebView({url: "http://webkit.org", transparent: true, ... });
			var props: [WebViewInitProps: Any] = [:]

			for prop in WebViewInitProps.allCases {
				// will want to consume tabs:[MPWebView]
	*/
		self.init()

		//if DispatchQueue.getSpecific(key: mainQueueKey) == mainQueueValue {
		//DispatchQueue.main.sync { self.present() }
	}

	deinit { warn(description) }
	override var description: String { return "<\(type(of: self))> `\(title ?? String())`" }

	func extend(_ mountObj: JSValue) {
		let browser = JSValue(object: self, in: mountObj.context)!
		// mixin some helper code to smooth out some rough edges & wrinkles in the JSExported API
		// this.tabs: Proxy wrapper actively assigns `fn()`s results back to their originating
			// properties so JSC<=>ObjC bridging can forward the changes to native classes' properties
		let helpers = """
			Object.defineProperty(this, 'tabs', {
				get: function () {
					let backer = "_tabs"; // the ObjC bridged native property's exported name
					return new Proxy(this[backer], {
						parent: this,
						getMutator: function (source, fn) {
							return new Proxy(source[fn], {
								apply: function(target, thisArg, args) {
									let mutant = source.slice(); // needs to be a copy
									let ret = mutant[fn].apply(mutant, args); // mutate the copy
									Reflect.set(thisArg, backer, mutant); // replace the source
									mutant = null; // allow GC on our copied refs
									return ret;
								}
							});
						},
						get: function(target, property, receiver) {
							if (property == "inspect") return () => target;

							// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/prototype#Mutator_methods
							if (["copyWithin", "fill", "pop", "push", "reverse", "shift", "sort", "splice", "unshift"].includes(property))
								return this.getMutator(target, property).bind(this.parent);

							return Reflect.get(...arguments); // passthru
						}
						/*
						set: function(target, property, value, receiver) {
							console.log(`Set [${property}] to ${value.inspect()}`);
							return Reflect.set(...arguments); // passthru
						}
						*/
					});
				}
			});
		"""
		browser.thisEval(helpers)
		mountObj.setValue(browser, forProperty: "browser")
	}

	static func exportSelf(_ mountObj: JSValue, _ name: String = "Browser") {
		// get ObjC-bridged wrapping of Self
		let wrapper = BrowserViewControllerOSX.self.wrapSelf(mountObj.context, name)
		mountObj.setObject(wrapper, forKeyedSubscript: name as NSString)
	}

	static func wrapSelf(_ context: JSContext, _ name: String = "Browser") -> JSValue {
		// make MacPin.BrowserWindow() constructable with a wrapping ES6 class
		// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Classes#Sub_classing_with_extends

		let bridgedClass = JSValue(object: BrowserViewControllerOSX.self, in: context) // ObjC-bridged Self
		guard let wrapper = bridgedClass?.thisEval("""
			(class \(name) extends this {

				constructor(name) {
					//console.log(`constructing [${new.target}]!`)
					super()
					Object.setPrototypeOf(this, \(name).prototype) // WTF do I have to do this, Mr. Extends?
					//this.extend(this) // mixin .tabs
				}
				static doHicky(txt) { console.log(`doHicky: ${txt}`); }
				foo(txt) { console.log(`foo: ${txt}`); }
				//inspect(depth, options) { return this.__proto__; }
				//static get [Symbol.species]() { return this; }
				//get [Symbol.toStringTag]() { return "\(name)"; }
				//[util.inspect.custom](depth, options) {}

				get tabs() {
					let backerKey = "_tabs"; // the ObjC bridged native property's exported name
					return new Proxy(this[backerKey], {backerKey, instance: this, ...{ // ES7 obj-spread-merge FTW
						getMutator: function (source, fn) {
							return new Proxy(source[fn], {backerKey: this.backerKey, ...{
								apply: function(target, thisArg, args) {
									let mutant = source.slice(); // needs to be a copy
									let ret = mutant[fn].apply(mutant, args); // mutate the copy
									Reflect.set(thisArg, this.backerKey, mutant); // replace the source
									mutant = null; // allow GC on our copied refs
									return ret;
								}
							}});
						},
						get: function(target, property, receiver) {
							if (property == "inspect") return () => target;

							// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/prototype#Mutator_methods
							if (["copyWithin", "fill", "pop", "push", "reverse", "shift", "sort", "splice", "unshift"].includes(property))
								return this.getMutator(target, property).bind(this.instance);

							return Reflect.get(...arguments); // passthru
						}
						/*
						set: function(target, property, value, receiver) {
							console.log(`Set [${property}] to ${value.inspect()}`);
							return Reflect.set(...arguments); // passthru
						}
						*/
					}}); // Proxy({handler})
				} // get tabs

			})
		"""), !wrapper.isUndefined else {
			return JSValue(undefinedIn: context)
		}

		//Object.defineProperty(win2, "__proto__", { writable: true, value: $.BrowserWindow } )

		//let wrapObj = JSValueToObject(mountObj.context.jsGlobalContextRef, classWrapper.jsValueRef, nil)
		//JSObjectSetPrototype(jsGlobalContextRef, wrapObj, classWrapper.jsValueRef)
		// Object.setPrototypeOf($.BrowserWindow, $.NBrowserWindow)

		return wrapper // returns a JSValue that we can mount elsewhere
	}

	func unextend(_ mountObj: JSValue) {
		let browser = JSValue(nullIn: mountObj.context)
		mountObj.setValue(browser, forProperty: "browser")
	}

	var defaultUserAgent: String? = nil // {
	//	get { }
	//	set(ua) { NSUserDefaults.standardUserDefaults().setString(ua, forKey: "UserAgent") } //only works on IOS
	//} // https://github.com/WebKit/webkit/blob/master/Source/WebCore/page/NavigatorBase.cpp
	// https://github.com/WebKit/webkit/blob/master/Source/WebCore/page/mac/UserAgentMac.mm

	var isFullscreen: Bool {
		get { return view.window?.contentView?.isInFullScreenMode ?? false }
		set(bool) { if bool != isFullscreen { view.window!.toggleFullScreen(nil) } }
	}

	var isToolbarShown: Bool {
		get { return view.window?.toolbar?.isVisible ?? true }
		set(bool) { if bool != isToolbarShown { view.window!.toggleToolbarShown(nil) } }
	}

	subscript(idx: Int) -> MPWebView {
		get { return self.tabs[idx] }
		set {
			var newTabs = self.tabs
			newTabs[idx] = newValue
			self.tabs = newTabs
		}
	}

	var tabs: [MPWebView] {
		get {
			//return children.flatMap({ $0 as? WebViewControllerOSX }).flatMap({ $0.webview }) // xc10
			return childViewControllers.flatMap({ $0 as? WebViewControllerOSX }).flatMap({ $0.webview })
			// returns mutable *copy* array, which is why JS .push() doesn't invoke the setter below: https://developer.apple.com/documentation/javascriptcore/jsvalue
			// > NSArray objects or Swift arrays become JavaScript arrays and vice versa, with elements recursively copied and converted.
			//  https://github.com/WebKit/webkit/blob/master/Source/JavaScriptCore/API/JSValue.mm
			//return tabViewItems.flatMap({ $0.viewController as? WebViewControllerOSX }).flatMap({ $0.webview })
		}

		set {
			let newWebs: [MPWebView] = (newValue as! Array<Any>).flatMap({ $0 as? MPWebView })
/*
% let {WebView: wv} = require("@MacPin")
% new wv({url: "http://google.com"})
	[MacPin.MPWebView] = `` [http://google.com/]
% $.browser.tabs.push(wv)
	Fatal error: NSArray element failed to match the Swift Array Element type
*/

				// upsert existing tabs as needed with new webviews
				for (idx, webview) in newWebs.enumerated() {
					warn("setting #\(idx)")
					if idx >= self.tabViewItems.endIndex {
						// insert
						self.childViewControllers.append(WebViewControllerOSX(webview: webview))
					} else if let ro = self.childViewControllers[idx].representedObject as? MPWebView, ro == webview {
						warn("no-op at #\(idx)")
					} else {
						// update
						let nwvc = WebViewControllerOSX(webview: webview)
						//self.insertChild(nwvc, at: idx+1) //xc10
						self.insertChildViewController(nwvc, at: idx+1) //push

						//self.removeChild(at: idx) //xc10
						self.removeChildViewController(at: idx) //pop
						// NSTVI will automatically set selectedTabViewItemIndex=idx+1
					}
				}

				// then do a delete pass of excess tabs
				if self.tabViewItems.count > newWebs.count {
					for (idx, _) in self.tabViewItems[newWebs.endIndex ..< self.tabViewItems.endIndex].enumerated() {
						// delete
						let shifted = idx + newWebs.endIndex
						//self.removeChild(at: shifted) //xc10
						self.removeChildViewController(at: shifted)
					}
				}

			// assuming tabs was set thru JS, lets trigger a garbage collect so we don't have lingering WebViews
			JSGarbageCollect(AppScriptRuntime.shared.context.jsGlobalContextRef)
		}
	}

	var tabSelected: AnyObject? { // FIXME: make protocol
		get {
			if selectedTabViewItemIndex == -1 { return nil } // no tabs? bupkiss!
			let vc = childViewControllers[selectedTabViewItemIndex]
			if let obj: AnyObject = vc.representedObject as AnyObject? { return obj } // try returning an actual model first
			return vc
		}
		set(obj) {
			switch (obj) {
				case let vc as NSViewController:
					if self.tabViewItem(for: vc) == nil {
						self.childViewControllers.append(vc) // add the given vc as a child if it isn't already
					}
					if let tvi = self.tabViewItem(for: vc) {
						let idx = self.tabView.indexOfTabViewItem(tvi)
						warn(idx.description)
						if idx != Int.max && idx > -1 {
							self.selectedTabViewItemIndex = idx
							prepareTab(vc)
						}
					}
				case let wv as MPWebView: // find the view's existing controller or else make one and re-assign
					self.tabSelected = self.childViewControllers.filter({ ($0 as? WebViewControllerOSX)?.webview === wv }).first as? WebViewControllerOSX ?? WebViewControllerOSX(webview: wv)
					//FIXME: a backref in the wv to wvc would be helpful
				//case let js as JSValue: guard let wv = js.toObjectOfClass(MPWebView.self) { self.tabSelected = wv } //custom bridging coercion
				default:
					warn("invalid object")
			}
		}
	}

	override func addChildViewController(_ childViewController: NSViewController) {
		warn()
		super.addChildViewController(childViewController)
	}

	override func insertChildViewController(_ childViewController: NSViewController, at index: Int) {
		warn("#\(index)")
		//If a child view controller has a different parent when you call this method, the child is first be removed from its existing parent by calling the child’s removeFromParent() method.
		super.insertChildViewController(childViewController, at: index)
		//tabsController.insert(childViewController, atArrangedObjectIndex: index)

		if let _ = childViewController as? WebViewController {
			//let gridItem = tabFlow.newItemForRepresentedObject(wvc)
			//gridItem.imageView = wv.favicon.icon
			//gridItem.textField = wv.title

			// FIXME: should only do this once per unique processPool, tabs.filter( { $0.configuration.processProol == wvc.webview.configuration.processPool } ) ??
		}
	}

	@objc func menuSelectedTab(_ sender: AnyObject?) {
		warn()
		if let mi = sender as? NSMenuItem { selectedTabViewItemIndex = mi.tag }
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
			presentViewController(tabFlow, asPopoverRelativeToRect: sender.bounds, ofView: sender, preferredEdge:NSMinYEdge, behavior: .Semitransient)
		} else { //keyboard shortcut
			//presentViewControllerAsSheet(tabFlow) // modal, yuck
			var poprect = view.bounds
			poprect.size.height -= tabFlow.preferredContentSize.height + 12 // make room at the top to stuff the popover
			presentViewController(tabFlow, asPopoverRelativeToRect: poprect, ofView: view, preferredEdge: NSMaxYEdge, behavior: .Semitransient)
		}
	}
*/
	override func removeChildViewController(at index: Int) {
		warn("#\(index)")
		super.removeChildViewController(at: index)
		// if index was the currentselected, NSTVC will reselect to the left if this was the last controller, else to the right
		//tabsController.remove(atArrangedObjectIndex: index)
	}

	override func presentViewController(_ viewController: NSViewController, animator: NSViewControllerPresentationAnimator) {
		warn()
		super.presentViewController(viewController, animator: animator)
	}

	override func transition(from fromViewController: NSViewController, to toViewController: NSViewController,
		options: NSViewController.TransitionOptions, completionHandler completion: (() -> Void)?) {
		warn()
		// BUG?: func not called for [tab#0] ... there is no vc to transition away from ...

		super.transition(from: fromViewController, to: toViewController,
			options: options, completionHandler: completion)

		//view.layer?.addSublayer(toViewController.view.layer?)

		prepareTab(toViewController)
	}

	func prepareTab(_ viewController: NSViewController) {
		guard let webview = viewController.representedObject as? MPWebView else {
			warn("making plain view first responder!!!")
			view.window?.makeFirstResponder(viewController.view)
			return
		}

		omnibox.webview = webview

		if let window = view.window {
			window.initialFirstResponder = omnibox.view
			if webview.url == startPage {
				// check for isLoaded too?
				// for pageless tabs (about:blank), we should focus on the omnibox, like Safari...
				// brand new tabs don't have init'd webview yet, so this check will fail
				revealOmniBox()
				//warn("represented!")
			} else { // isLoaded, isLoading
				window.makeFirstResponder(webview)
				// omni should be next Responder, but keyFocus should be on the webview
				//omnibox.view.resignFirstResponder()
				//window.selectNextKeyView(nil)
			}
			warn("visible webview prepared!")
			// warn("focus is on `\(view.window?.firstResponder)`")
		} else {
			warn("headless app???")
			// I think some app.js's start so fast and create and tabSelected their webviews before the window is even up...
			//    responder chain ends up being broke until one clicks into the webview
		}

		//warn("browser title is now `\(title ?? String())`")
	}

	@objc override func viewDidAppear() {
		super.viewDidAppear()
		warn()
	}

    //var matchedAddressOptions: [String:String] { //alias to global singleton from WebViewDelegates
    //    get { return MatchedAddressOptions }
    //    set { MatchedAddressOptions = newValue }
    //}

	//MARK: menu & shortcut selectors

	@objc func switchToPreviousTab() { tabView.selectPreviousTabViewItem(self) }
	@objc func switchToNextTab() { tabView.selectNextTabViewItem(self) }

	@objc func loadSiteApp() { AppScriptRuntime.shared.loadSiteApp() }
	@objc func editSiteApp() { NSWorkspace.shared.openFile(Bundle.main.resourcePath!) }

	@objc func newTabPrompt() {
		//tabSelected = WebViewControllerOSX(url: startPage)
		tabSelected = MPWebView(url: startPage)
		revealOmniBox()
	}

	@objc func newIsolatedTabPrompt() {
		tabSelected = MPWebView(url: startPage, agent: nil, isolated: true)
		revealOmniBox()
	}

	@objc func newPrivateTabPrompt() {
		tabSelected = MPWebView(url: startPage, agent: nil, isolated: true, privacy: true)
		revealOmniBox()
	}

	//@objc func pushTab(_ webview: AnyObject) { if let webview = webview as? MPWebView { addChildViewController(WebViewControllerOSX(webview: webview)) } }

	@objc func closeTab(_ tab: AnyObject?) {
		switch (tab) {
			case let vc as NSViewController:
				guard let ti = tabViewItem(for: vc) else { break } // not a loaded tab
				removeTabViewItem(ti)
				return
			case let wv as MPWebView: // find the view's existing controller or else make one and re-assign
				guard let vc = childViewControllers.filter({ ($0 as? WebViewControllerOSX)?.webview === wv }).first else { break }
				guard let ti = tabViewItem(for: vc) else { break } // not a loaded tab
				removeTabViewItem(ti)
				return
			//case let js as JSValue: guard let wv = js.toObjectOfClass(MPWebView.self) { self.tabSelected = wv } //custom bridging coercion
			default:
				// sender from a MenuItem?
				break
		}

		// close currently selected tab
		if selectedTabViewItemIndex == -1 { return } // no tabs? bupkiss!
		removeChildViewController(at: selectedTabViewItemIndex)
	}

	@objc func revealOmniBox() {
		warn()
		if omnibox.view.window != nil {
			// if omnibox is already visible somewhere in the window, move key focus there
			view.window?.makeFirstResponder(omnibox.view)
			warn("omniboxed! \(omnibox.view)")
		} else if view.window != nil {
			//let omnibox = OmniBoxController(webViewController: self)
			// otherwise, present it as a sheet or popover aligned under the window-top/toolbar
			//presentViewControllerAsSheet(omnibox) // modal, yuck
			var poprect = view.bounds
			poprect.size.height -= omnibox.preferredContentSize.height + 12 // make room at the top to stuff the popover
			presentViewController(omnibox, asPopoverRelativeTo: poprect, of: view, preferredEdge: NSRectEdge.maxY, behavior: NSPopover.Behavior.transient)
		} else {
			warn("headless browser?? no window to sheet/popover omnibox into!")
		}
	}

	@objc func sidebarButtonClicked(_ tab: AnyObject?) {
		warn()
		if self.sidebar.presenting != nil {
			dismissViewController(self.sidebar)
		} else {

			//DispatchQueue.main.async() {
				/*
				let tgv = self.sidebar.view
					tgv.frame = //view.bounds
						CGRect(
							x: 0, //self.view.bounds.origin.x,
							y: 0, //self.view.bounds.origin.y,
							width: 200,
							height: self.view.frame.size.height // - statusHeight - toolBar.frame.size.height)
					self.view.addSubview(tgv, positioned: .above, relativeTo: self.view)
					)
				*/
			//}
			presentViewControllerAsModalWindow(self.sidebar)
			//presentViewControllerAsSheet(self.sidebar)
			return
		}

		switch (tab) {
			case let vc as NSViewController:
				guard let ti = tabViewItem(for: vc) else { break } // not a loaded tab

			case let wv as MPWebView: // find the view's existing controller or else make one and re-assign
				guard let vc = childViewControllers.filter({ ($0 as? WebViewControllerOSX)?.webview === wv }).first else { break }
				guard let ti = tabViewItem(for: vc) else { break } // not a loaded tab
				//DispatchQueue.main.async() { self.removeTabViewItem(ti) }
				return
			//case let js as JSValue: guard let wv = js.toObjectOfClass(MPWebView.self) { self.tabSelected = wv } //custom bridging coercion
			default:
				// sender from a MenuItem?
				break
		}
	}

	override func insertTabViewItem(_ tab: NSTabViewItem, at: Int) {
		super.insertTabViewItem(tab, at: at)
		menuNeedsUpdate(tabMenu)
	}

	override func removeTabViewItem(_ tab: NSTabViewItem) {
		super.removeTabViewItem(tab)
		if tabView.tabViewItems.count != 0 {
			tabView.selectNextTabViewItem(self) //safari behavior
		}

		menuNeedsUpdate(tabMenu) // previous webview should be released and deinit'd now

		if tabView.tabViewItems.count == 0 {
			// no more tabs? close the window and app, like Safari
			// FIXME: check for "protection" before defenestrating
			omnibox.webview = nil //retains last webview
			view.window?.windowController?.close() // kicks off automatic app termination
		}
	}

	override func tabView(_ tabView: NSTabView, willSelect tabViewItem: NSTabViewItem?) {
		super.tabView(tabView, willSelect: tabViewItem)
		warn()
		//omnibox.webview = tabViewItem?.view?.subviews.first as? MPWebView
		// FIXME: hokey reference to webview, can't get a ref to the tabViewItem?.viewController?
		if let vc = tabViewItem?.viewController { prepareTab(vc) }
	}

	override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
		super.tabView(tabView, didSelect: tabViewItem)
		menuNeedsUpdate(tabMenu)
	}

	func focusOnBrowser() {  // un-minimizes app, switches to its screen/space, and steals key focus to the window
		//NSApplication.sharedApplication().activateIgnoringOtherApps(true)
		let app = NSRunningApplication.current
		app.unhide() // un-minimize app
		app.activate(options: .activateIgnoringOtherApps) // brings up key window
		view.window?.makeKeyAndOrderFront(nil) // steals key focus
		// CoreProcess stealer: https://github.com/gnachman/iTerm2/commit/c2a79333da01116ce84ec38d573fd95e3f632e4f
	}

	func unhideApp() { // un-minimizes app, but doesn't steal key focus or screen or menubar
		let app = NSRunningApplication.current
		app.unhide() // un-minimize app
		app.activate(options: .activateIgnoringOtherApps) // brings up key window
		view.window?.makeKeyAndOrderFront(nil) // steals key focus
/*
		//windowController.showWindow(self)
		NSApplication.sharedApplication().unhide(self)
		NSApplication.sharedApplication().arrangeInFront(self)
		view.window?.makeKeyAndOrderFront(nil)
*/
	}

	func indicateTab(_ vc: NSViewController) {
		// if VC has a tab, flash a popover pointed at its toolbar button to indicate its location
		//if let tvi = tabViewItemForViewController(vc) { }
	}

	func bounceDock() { NSApplication.shared.requestUserAttention(.informationalRequest) } //Critical keeps bouncing

	func addShortcut(_ title: String, _ obj: AnyObject?, _ cb: JSValue?) {
		if title.isEmpty {
			warn("title not provided")
			return
		}
		var mi: NSMenuItem
		switch (obj) {
			//case is String: fallthrough
			//case is [String:AnyObject]: fallthrough
			//case is [String]: shortcutsMenu.addItem(MenuItem(title, "gotoShortcut:", target: self, represents: obj))
			case let str as String: mi = MenuItem(title, "gotoShortcut:", target: self, represents: str as NSString)
			//case let jsobj as [String: JSValue]:
			//	mi = MenuItem(title, "gotoShortcut:", target: self, represents: jsobj)
			//		jsobj can't be coerced to AnyObject
			case let dict as [String: AnyObject]:
				mi = MenuItem(title, "gotoShortcut:", target: self, represents: NSDictionary(dictionary: dict, copyItems: true))
			case let arr as [AnyObject]:
				guard let cb = cb, let narr: [AnyObject] = [cb] + arr else { warn("no callback func provided for array!"); fallthrough }
				mi = MenuItem(title, "gotoShortcut:", target: self, represents: narr)
			default:
				warn("invalid shortcut object type!")
				return
		}
		shortcutsMenu.addItem(mi)
		mi.parent?.isHidden = false
	}

	@objc func gotoShortcut(_ sender: AnyObject?) {
		if let shortcut = sender as? NSMenuItem {
			switch (shortcut.representedObject) {
				case let urlstr as String: AppScriptRuntime.shared.emit(.launchURL, urlstr as NSString)
				// FIXME: fire event in jsdelegate if string, only validated-and-bridged NSURLs should do launchURL
				case let dict as [String:AnyObject]: tabSelected = MPWebView(object: dict) // FIXME: do a try here
				case let dict as [WebViewInitProps:AnyObject]: tabSelected = MPWebView(props: dict) // FIXME: do a try here
				case let jsobj as [String: JSValue]:
					warn("\(jsobj)")
				case let arr as [AnyObject?] where arr.count > 0 && arr.first is String?:
					// FIXME: funcs (arr[0]) should be passed in by ref, and not un-strung and hoisted from `delegate`
					var args = Array(arr.dropFirst()).map({ $0! }) // filters nils....buggish?
					if let wv = tabSelected as? MPWebView { args.append(wv) }
					AppScriptRuntime.shared.jsdelegate.tryFunc((arr.first as! String), argv: args)
				case let arr as [AnyObject?] where arr.count > 0 && arr.first is JSValue:
					guard let callback = arr.first! as? JSValue, // we may have a JS func-ref to call here ...
					!callback.isNull && !callback.isUndefined && callback.hasProperty("call") else {
						warn("leading value is uncallable")
						warn(obj: arr.first!)
						fallthrough
					}
					var args = Array(arr.dropFirst()).map({ $0! }) // filters nils....buggish?
					if let wv = tabSelected as? MPWebView { args.append(wv) }
					callback.call(withArguments: args)
				default:
					warn("invalid shortcut object type!")
					warn(obj: shortcut.representedObject)
			}
		}
	}
}

extension BrowserViewControllerOSX: NSMenuDelegate {
	func menuHasKeyEquivalent(_ menu: NSMenu, for event: NSEvent, target: AutoreleasingUnsafeMutablePointer<AnyObject?>, action: UnsafeMutablePointer<Selector?>) -> Bool {
		return false // no numeric index shortcuts for tabz (unlike Safari)
	}

	func menuNeedsUpdate(_ menu: NSMenu) {
		switch menu.title {
			//case "Shortcuts":
			//	warn(menu.title)
			case "Tabs":
				menu.removeAllItems()
				for (idx, tab) in tabViewItems.enumerated() {
					guard let toolTip = tab.toolTip else { continue }
					let mi = NSMenuItem(title: String(tab.label), action:#selector(menuSelectedTab(_:)), keyEquivalent:"")
					mi.toolTip = String(toolTip)
					if let image = tab.image {
						mi.image = image.copy() as! NSImage
						mi.image?.size = NSSize(width: 16, height: 16)
					}
					mi.tag = idx
					mi.target = self
					mi.state = (selectedTabViewItemIndex == idx) ? .on : .off
					//mi.state = (tab.tabState == .selectedTab) ? .on : .off
					menu.addItem(mi)
				}
			default: return
		}
	}

	func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
		// popup thumbnail snapshot?
	}
}
