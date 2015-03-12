import Cocoa
import ObjectiveC
import WebKitPrivates

class MenuItem: NSMenuItem {
	convenience init(_ itemName: String, _ anAction: String? , _ charCode: String? = nil, _ keyflags: [NSEventModifierFlags] = [], target aTarget: AnyObject? = nil) {
		self.init(
			title: itemName,
			action: (anAction? != nil) ? Selector(anAction!) : nil,
			keyEquivalent: charCode ?? ""
		)
		for keyflag in keyflags {
			keyEquivalentModifierMask |= Int(keyflag.rawValue)
			 // .[AlphaShift|Shift|Control|Alternate|Command|Numeric|Function|Help]KeyMask
		}
		target = aTarget
		// menu item actions walk the responder chain if target == nil
		// https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/EventOverview/EventArchitecture/EventArchitecture.html#//apple_ref/doc/uid/10000060i-CH3-SW9
		// https://developer.apple.com/library/mac/releasenotes/AppKit/RN-AppKit/#10_10ViewController
		// ChildView -> ChildView ViewController -> ParentView -> ParentView's ViewController -> ParentView's ParentView -> Window -> Window's WindowController -> Window's Delegate -> NSApp -> App Delegate
	}
}

//@NSApplicationMain // doesn't work without NIBs, using execs/MacPin.swift instead
public class AppDelegate: NSObject {

	var browserController = BrowserViewController()
	var windowController: WindowController

	override public init() {
		browserController.title = nil
		browserController.canPropagateSelectedChildViewControllerTitle = true
		windowController = WindowController(window: NSWindow(contentViewController: browserController))
		super.init()
	}

	func conlog(msg: String) { browserController.conlog(msg) }

	func handleGetURLEvent(event: NSAppleEventDescriptor!, replyEvent: NSAppleEventDescriptor?) {
		if let urlstr = event.paramDescriptorForKeyword(AEKeyword(keyDirectObject))!.stringValue {
			warn("\(__FUNCTION__) `\(urlstr)` -> jsruntime.delegate.launchURL()")
			jsruntime.delegate.tryFunc("launchURL", urlstr)
			//replyEvent == ??
		}
		//replyEvent == ??
	}
}

extension AppDelegate: NSApplicationDelegate {

	public func applicationDockMenu(sender: NSApplication) -> NSMenu? { return browserController.tabMenu }

	public func applicationShouldOpenUntitledFile(app: NSApplication) -> Bool { return false }

	//public func application(sender: AnyObject, openFileWithoutUI filename: String) -> Bool {} // app terminates on return!
	//public func application(theApplication: NSApplication, printFile filename: String) -> Bool () //app terminates on return

	public func applicationWillFinishLaunching(notification: NSNotification) { // dock icon bounces, also before self.openFile(foo.bar) is called
		NSUserNotificationCenter.defaultUserNotificationCenter().delegate = self
		let app = notification.object as? NSApplication

		app!.mainMenu = NSMenu()

		let appMenu = NSMenuItem()
		appMenu.submenu = NSMenu()
		appMenu.submenu?.addItem(MenuItem("Quit \(NSProcessInfo.processInfo().processName)", "terminate:", "q"))
		appMenu.submenu?.addItem(MenuItem("About", "orderFrontStandardAboutPanel:"))
		appMenu.submenu?.addItem(MenuItem("Restart App", "loadSiteApp"))
		appMenu.submenu?.addItem(MenuItem("Edit App...", "editSiteApp"))
		app!.mainMenu?.addItem(appMenu) // 1st item shows up as CFPrintableName

		app!.servicesMenu = NSMenu()
		let svcMenu = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
		svcMenu.submenu = app!.servicesMenu!
		appMenu.submenu?.addItem(svcMenu)

		let editMenu = NSMenuItem() //NSTextArea funcs
		editMenu.submenu = NSMenu()
		editMenu.submenu?.title = "Edit"
		editMenu.submenu?.addItem(MenuItem("Cut", "cut:", "x", [.CommandKeyMask])) 
		editMenu.submenu?.addItem(MenuItem("Copy", "copy:", "c", [.CommandKeyMask]))
		editMenu.submenu?.addItem(MenuItem("Paste", "paste:", "p", [.CommandKeyMask]))
		editMenu.submenu?.addItem(MenuItem("Select All", "selectAll:", "a", [.CommandKeyMask]))
		app!.mainMenu?.addItem(editMenu) 

		let tabMenu = NSMenuItem() //WebViewController and WKWebView funcs
		tabMenu.submenu = NSMenu()
		tabMenu.submenu?.title = "Tab"
		tabMenu.submenu?.addItem(MenuItem("Zoom In", "zoomIn", "+", [.CommandKeyMask]))
		tabMenu.submenu?.addItem(MenuItem("Zoom Out", "zoomOut", "-", [.CommandKeyMask]))
		tabMenu.submenu?.addItem(MenuItem("Zoom Text Only", "zoomOut", "", [.CommandKeyMask]))
		tabMenu.submenu?.addItem(MenuItem("Toggle Translucency", "toggleTransparency"))
		//tabMenu.submenu?.addItem(MenuItem("Web Inspector", "showConsole:", "i", [.CommandKeyMask, .AlternateKeyMask]) //need impl of WKInspectorShow
		tabMenu.submenu?.addItem(MenuItem("Reload", "reload:", "r", [.CommandKeyMask])) //webview
		tabMenu.submenu?.addItem(MenuItem("Uncache & Reload", "reloadFromOrigin:", "R", [.CommandKeyMask, .ShiftKeyMask])) //webview
		tabMenu.submenu?.addItem(MenuItem("Go Back", "goBack:", "[", [.CommandKeyMask])) //webview
		tabMenu.submenu?.addItem(MenuItem("Go Forward", "goForward:", "]", [.CommandKeyMask]))	//webview
		tabMenu.submenu?.addItem(MenuItem("Stop Loading", "stopLoading:", ".", [.CommandKeyMask])) //webview
		tabMenu.submenu?.addItem(MenuItem("Print Page", "print:")) //NSView
		app!.mainMenu?.addItem(tabMenu) 

		let winMenu = NSMenuItem() //BrowserViewController and NSWindow funcs
		winMenu.submenu = NSMenu()
		winMenu.submenu?.title = "Window"
		//winMenu.submenu?.addItem(MenuItem("Enter URL", "focusOnURLBox", "l", [.CommandKeyMask]))
		winMenu.submenu?.addItem(MenuItem("Enter URL", "gotoButtonClicked:", "l", [.CommandKeyMask]))
		winMenu.submenu?.addItem(MenuItem("", "toggleFullScreen:"))
		winMenu.submenu?.addItem(MenuItem("", "toggleToolbarShown:"))
		//winMenu.submenu?.addItem(MenuItem("Edit Toolbar", "runToolbarCustomizationPalette:"))
		winMenu.submenu?.addItem(MenuItem("New Tab", "newTabPrompt", "t", [.CommandKeyMask]))
		winMenu.submenu?.addItem(MenuItem("Close Tab", "closeCurrentTab", "w", [.CommandKeyMask]))
		winMenu.submenu?.addItem(MenuItem("Show Next Tab", "selectNextTabViewItem:", String(format:"%c", NSTabCharacter), [.ControlKeyMask]))
		winMenu.submenu?.addItem(MenuItem("Show Previous Tab", "selectPreviousTabViewItem:", String(format:"%c", NSTabCharacter), [.ControlKeyMask, .ShiftKeyMask]))
		app!.mainMenu?.addItem(winMenu) 

		let tabListMenu = NSMenuItem(title: "Tabs", action: nil, keyEquivalent: "")
		tabListMenu.submenu = browserController.tabMenu
		tabListMenu.submenu?.title = "Tabs"
		app!.mainMenu?.addItem(tabListMenu)
		////appMenu.submenu?.addItem(tabListMenu)

		let dbgMenu = NSMenuItem()
		dbgMenu.submenu = NSMenu()
		dbgMenu.submenu?.title = "Debug"
		dbgMenu.submenu?.addItem(MenuItem("Highlight TabView Constraints", "highlightConstraints"))
		dbgMenu.submenu?.addItem(MenuItem("Randomize TabView Layout", "exerciseAmbiguityInLayout"))
		dbgMenu.submenu?.addItem(MenuItem("Replace contentView With Tab", "replaceContentView"))
		dbgMenu.submenu?.addItem(MenuItem("Dismiss VC", "dismissController:"))
#if DBGMENU
#else
		dbgMenu.hidden = true
#endif
		app!.mainMenu?.addItem(dbgMenu) 

		var origDnD = class_getInstanceMethod(WKView.self, "performDragOperation:")
		var newDnD = class_getInstanceMethod(WKView.self, "shimmedPerformDragOperation:")
		method_exchangeImplementations(origDnD, newDnD) //swizzle that shizzle to enable logging of DnD's

		windowController.window?.initialFirstResponder = browserController.view // should defer to selectedTab.initialFirstRepsonder
		windowController.window?.bind(NSTitleBinding, toObject: browserController, withKeyPath: "title", options: nil)
		windowController.showWindow(self)

		NSAppleEventManager.sharedAppleEventManager().setEventHandler(self, andSelector: "handleGetURLEvent:replyEvent:", forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL)) //route registered url scehems
	}

	//public func application(theApplication: NSApplication, openFile filename: String) -> Bool {}

    public func applicationDidFinishLaunching(notification: NSNotification?) { //dock icon stops bouncing
		jsruntime.context.setObject(browserController, forKeyedSubscript: "$browser")
		jsruntime.loadSiteApp() // load app.js, if present

		if let default_html = NSBundle.mainBundle().URLForResource("default", withExtension: "html") {
			conlog("\(__FUNCTION__) loading initial page from app bundle: \(default_html)")
			browserController.newTab(default_html.description)
		}

		if countElements(Process.arguments) > 1 { // got argv
			var urlstr = Process.arguments[1] ?? "about:blank"
			conlog("\(__FUNCTION__) loading initial page from argv[1]: \(urlstr)")
			browserController.newTab(urlstr)
			browserController.unhideApp()
		}

		if browserController.tabCount < 1 { browserController.newTabPrompt() } //don't allow a tabless state

		if let notification = notification {
			if let userNotification = notification.userInfo?["NSApplicationLaunchUserNotificationKey"] as? NSUserNotification {
				userNotificationCenter(NSUserNotificationCenter.defaultUserNotificationCenter(), didActivateNotification: userNotification)
			}
		}

		conlog("\(__FUNCTION__) focus is on `\(windowController.window?.firstResponder)`")
    }

	public func applicationDidBecomeActive(notification: NSNotification) {
		//if application?.orderedDocuments?.count < 1 { showApplication(self) }
	}

	public func application(application: NSApplication, willPresentError error: NSError) -> NSError { 
		conlog("\(__FUNCTION__) `\(error.localizedDescription)` [\(error.domain)] [\(error.code)] `\(error.localizedFailureReason ?? String())` : \(error.userInfo)")
		if error.domain == NSURLErrorDomain {
			if let userInfo = error.userInfo {
				if let errstr = userInfo[NSLocalizedDescriptionKey] as? String {
					if let url = userInfo[NSURLErrorFailingURLStringErrorKey] as? String {
						var newUserInfo = userInfo
						newUserInfo[NSLocalizedDescriptionKey] = "\(errstr)\n\n\(url)" // add failed url to error message
						let newerror = NSError(domain: error.domain, code: error.code, userInfo: newUserInfo)
						return newerror
					}
				}
			}
		}
		return error 
	}

	public func applicationWillTerminate(notification: NSNotification) { NSUserDefaults.standardUserDefaults().synchronize() }
    
	public func applicationShouldTerminateAfterLastWindowClosed(app: NSApplication) -> Bool { return true }

}

extension AppDelegate: NSUserNotificationCenterDelegate {
	//didDeliverNotification
	public func userNotificationCenter(center: NSUserNotificationCenter, didActivateNotification notification: NSUserNotification) {
		conlog("user clicked notification")

		if jsruntime.delegate.tryFunc("handleClickedNotification", notification.title ?? "", notification.subtitle ?? "", notification.informativeText ?? "") {
			conlog("handleClickedNotification fired!")
			center.removeDeliveredNotification(notification)
		}
	}

	// always display notifcations, even if app is active in foreground (for alert sounds)
	public func userNotificationCenter(center: NSUserNotificationCenter, shouldPresentNotification notification: NSUserNotification) -> Bool { return true }
}

extension AppDelegate: NSWindowRestoration {
	// https://developer.apple.com/library/mac/documentation/General/Conceptual/MOSXAppProgrammingGuide/CoreAppDesign/CoreAppDesign.html#//apple_ref/doc/uid/TP40010543-CH3-SW35
	public class func restoreWindowWithIdentifier(identifier: String, state: NSCoder, completionHandler: ((NSWindow!,NSError!) -> Void)) {
		if let window = (NSApplication.sharedApplication().delegate as AppDelegate).windowController.window {
			completionHandler(window, nil)
		} else {
			completionHandler(nil, nil)
		}
	}
}
