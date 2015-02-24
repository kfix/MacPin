import Cocoa
import ObjectiveC

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
		mi.target = nil // walk responder chain
		addItem(mi)
		//return mi? or apply closure to it before add?
	}
}

//@NSApplicationMain // doesn't work without NIBs, using main.swift instead :-(
public class AppDelegate: NSObject, NSApplicationDelegate {

	public var browserController = BrowserViewController()
	public var windowController: WindowController

	override public init() {
		browserController.title = nil
		browserController.canPropagateSelectedChildViewControllerTitle = true
		windowController = WindowController(window: NSWindow(contentViewController: browserController))
		super.init()
	}

	func conlog(msg: String) { browserController.conlog(msg) }

	//public func applicationDockMenu(sender: NSApplication) -> NSMenu?

	public func applicationShouldOpenUntitledFile(app: NSApplication) -> Bool { return false }

	//public func application(sender: AnyObject, openFileWithoutUI filename: String) -> Bool {} // app terminates on return!
	//public func application(theApplication: NSApplication, printFile filename: String) -> Bool () //app terminates on return

	public func applicationWillFinishLaunching(notification: NSNotification) { // dock icon bounces, also before self.openFile(foo.bar) is called
		NSUserNotificationCenter.defaultUserNotificationCenter().delegate = self
		let app = notification.object as? NSApplication

		// menu item actions walk the responder chain
		// https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/EventOverview/EventArchitecture/EventArchitecture.html#//apple_ref/doc/uid/10000060i-CH3-SW9
		// https://developer.apple.com/library/mac/releasenotes/AppKit/RN-AppKit/#10_10ViewController
		// ChildView -> ChildView ViewController -> ParentView -> ParentView's ViewController -> ParentView's ParentView -> Window -> Window's WindowController -> Window's Delegate -> NSApp -> App Delegate

		app!.mainMenu = NSMenu()

		var appMenu = NSMenuItem()
		appMenu.submenu = NSMenu()
		appMenu.submenu?.easyAddItem("Quit \(NSProcessInfo.processInfo().processName)", "terminate:", "q")
		appMenu.submenu?.easyAddItem("About", "orderFrontStandardAboutPanel:")
		appMenu.submenu?.easyAddItem("Restart App", "loadSiteApp")
		appMenu.submenu?.easyAddItem("Edit App...", "editSiteApp")
		app!.mainMenu?.addItem(appMenu) // 1st item shows up as CFPrintableName

		app!.servicesMenu = NSMenu()
		let svcMenu = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
		svcMenu.submenu = app!.servicesMenu!
		appMenu.submenu?.addItem(svcMenu)

		var editMenu = NSMenuItem() //NSTextArea funcs
		editMenu.submenu = NSMenu()
		editMenu.submenu?.title = "Edit"
		editMenu.submenu?.easyAddItem("Cut", "cut:", "x", [.CommandKeyMask]) 
		editMenu.submenu?.easyAddItem("Copy", "copy:", "c", [.CommandKeyMask]) 
		editMenu.submenu?.easyAddItem("Paste", "paste:", "p", [.CommandKeyMask])
		editMenu.submenu?.easyAddItem("Select All", "selectAll:", "a", [.CommandKeyMask])
		app!.mainMenu?.addItem(editMenu) 

		var tabMenu = NSMenuItem() //WebViewController and WKWebView funcs
		tabMenu.submenu = NSMenu()
		tabMenu.submenu?.title = "Tab"
		tabMenu.submenu?.easyAddItem("Zoom In", "zoomIn", "+", [.CommandKeyMask])
		tabMenu.submenu?.easyAddItem("Zoom Out", "zoomOut", "-", [.CommandKeyMask])
		tabMenu.submenu?.easyAddItem("Zoom Text Only", "zoomOut", "", [.CommandKeyMask])
		//tabMenu.submenu?.easyAddItem("Web Inspector", "showConsole:", "i", [.CommandKeyMask, .AlternateKeyMask]) //need impl of WKInspectorShow
		tabMenu.submenu?.easyAddItem("Reload", "reload:", "r", [.CommandKeyMask]) //webview
		tabMenu.submenu?.easyAddItem("Uncache & Reload", "reloadFromOrigin:", "R", [.CommandKeyMask, .ShiftKeyMask]) //webview
		tabMenu.submenu?.easyAddItem("Go Back", "goBack:", "[", [.CommandKeyMask]) //webview
		tabMenu.submenu?.easyAddItem("Go Forward", "goForward:", "]", [.CommandKeyMask])	//webview
		tabMenu.submenu?.easyAddItem("Stop Loading", "stopLoading:", ".", [.CommandKeyMask]) //webview
		tabMenu.submenu?.easyAddItem("Print Page", "print:") //NSView
		app!.mainMenu?.addItem(tabMenu) 

		var winMenu = NSMenuItem() //BrowserViewController and NSWindow funcs
		winMenu.submenu = NSMenu()
		winMenu.submenu?.title = "Window"
		//winMenu.submenu?.easyAddItem("Enter URL", "focusOnURLBox", "l", [.CommandKeyMask])
		winMenu.submenu?.easyAddItem("Enter URL", "gotoButtonClicked:", "l", [.CommandKeyMask])
		winMenu.submenu?.easyAddItem("Toggle Translucency", "toggleTransparency")
		winMenu.submenu?.easyAddItem("", "toggleFullScreen:")
		winMenu.submenu?.easyAddItem("", "toggleToolbarShown:")
		//winMenu.submenu?.easyAddItem("Edit Toolbar", "runToolbarCustomizationPalette:")
		winMenu.submenu?.easyAddItem("New Tab", "newTabPrompt", "t", [.CommandKeyMask])
		winMenu.submenu?.easyAddItem("Close Tab", "closeCurrentTab", "w", [.CommandKeyMask])
		winMenu.submenu?.easyAddItem("Show Next Tab", "selectNextTabViewItem:", String(format:"%c", NSTabCharacter), [.ControlKeyMask]) 
		winMenu.submenu?.easyAddItem("Show Previous Tab", "selectPreviousTabViewItem:", String(format:"%c", NSTabCharacter), [.ControlKeyMask, .ShiftKeyMask])
		app!.mainMenu?.addItem(winMenu) 
		
		//app!.windowsMenu!

		var dbgMenu = NSMenuItem()
		dbgMenu.submenu = NSMenu()
		dbgMenu.submenu?.title = "Debug"
		dbgMenu.submenu?.easyAddItem("Highlight TabView Constraints", "highlightConstraints")
		dbgMenu.submenu?.easyAddItem("Randomize TabView Layout", "exerciseAmbiguityInLayout")
		dbgMenu.submenu?.easyAddItem("Replace contentView With Tab", "replaceContentView")
#if DBGMENU
#else
		dbgMenu.hidden = true
#endif
		app!.mainMenu?.addItem(dbgMenu) 

		var origDnD = class_getInstanceMethod(WKView.self, "performDragOperation:")
		var newDnD = class_getInstanceMethod(WKView.self, "shimmedPerformDragOperation:")
		method_exchangeImplementations(origDnD, newDnD) //swizzle that shizzlee to enable logging of DnD's

		windowController.window?.bind(NSTitleBinding, toObject: browserController, withKeyPath: "title", options: nil)
		windowController.window?.initialFirstResponder = browserController.view // should defer to selectedTab.initialFirstRepsonder, which is always a webview
		windowController.showWindow(self)

		NSAppleEventManager.sharedAppleEventManager().setEventHandler(self, andSelector: "handleGetURLEvent:replyEvent:", forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL)) //handle `open url`
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

		if browserController.tabCount < 1 { browserController.newTabPrompt(); } //don't allow a tabless state

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
