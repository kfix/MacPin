import AppKit
import ObjectiveC
import WebKitPrivates
import Darwin

//@NSApplicationMain // doesn't work without NIBs, using main.swift instead
class AppDelegateOSX: AppDelegate{

	var effectController = EffectViewController()
	var browserController = BrowserViewController()
	var windowController: WindowController

	override init() {
		browserController.title = nil
		browserController.canPropagateSelectedChildViewControllerTitle = true
		windowController = WindowController(window: NSWindow(contentViewController: effectController))
		effectController.view.addSubview(browserController.view)
		browserController.view.frame = effectController.view.bounds
		super.init()
	}

	// handle URLs passed by open
	func handleGetURLEvent(event: NSAppleEventDescriptor!, replyEvent: NSAppleEventDescriptor?) {
		if let urlstr = event.paramDescriptorForKeyword(AEKeyword(keyDirectObject))!.stringValue {
			warn("`\(urlstr)` -> AppScriptRuntime.shared.jsdelegate.launchURL()")
			AppScriptRuntime.shared.context.objectForKeyedSubscript("$").setObject(urlstr, forKeyedSubscript: "launchedWithURL")
			AppScriptRuntime.shared.jsdelegate.tryFunc("launchURL", urlstr)
			//replyEvent == ??
		}
		//replyEvent == ??
	}
}

extension AppDelegateOSX: NSApplicationDelegate {

	func applicationDockMenu(sender: NSApplication) -> NSMenu? { return browserController.tabMenu }

	func applicationShouldOpenUntitledFile(app: NSApplication) -> Bool { return false }

	//func application(sender: AnyObject, openFileWithoutUI filename: String) -> Bool {} // app terminates on return!
	//func application(theApplication: NSApplication, printFile filename: String) -> Bool () //app terminates on return

	//public finishLaunching() { super.finishLaunching() } // app activates, NSOpen files opened

	func applicationWillFinishLaunching(notification: NSNotification) { // dock icon bounces, also before self.openFile(foo.bar) is called
		NSUserNotificationCenter.defaultUserNotificationCenter().delegate = self
		let app = notification.object as? NSApplication
		//let appname = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleName") ?? NSProcessInfo.processInfo().processName
		let appname = NSRunningApplication.currentApplication().localizedName ?? NSProcessInfo.processInfo().processName

		app!.mainMenu = NSMenu()

		let appMenu = NSMenuItem()
		appMenu.submenu = NSMenu()
		appMenu.submenu?.addItem(MenuItem("About \(appname)", "orderFrontStandardAboutPanel:"))
		appMenu.submenu?.addItem(MenuItem("Restart \(appname)", "loadSiteApp"))
		appMenu.submenu?.addItem(NSMenuItem.separatorItem())
		appMenu.submenu?.addItem(MenuItem("Hide \(appname)", "hide:", "h", [.CommandKeyMask]))
		appMenu.submenu?.addItem(MenuItem("Hide Others", "hideOtherApplications:", "H", [.CommandKeyMask, .ShiftKeyMask]))
		appMenu.submenu?.addItem(NSMenuItem.separatorItem())
		//appMenu.submenu?.addItem(MenuItem("Edit App...", "editSiteApp")) // can't modify signed apps' Resources
		app!.mainMenu?.addItem(appMenu) // 1st item shows up as CFPrintableName

		app!.servicesMenu = NSMenu()
		let svcMenu = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
		svcMenu.submenu = app!.servicesMenu!
		appMenu.submenu?.addItem(svcMenu)
		appMenu.submenu?.addItem(MenuItem("Quit \(appname)", "terminate:", "q"))

		let editMenu = NSMenuItem() //NSTextArea funcs
		// plutil -p /System/Library/Frameworks/AppKit.framework/Resources/StandardKeyBinding.dict
		editMenu.submenu = NSMenu()
		editMenu.submenu?.title = "Edit"
		editMenu.submenu?.addItem(MenuItem("Cut", "cut:", "x", [.CommandKeyMask]))
		editMenu.submenu?.addItem(MenuItem("Copy", "copy:", "c", [.CommandKeyMask]))
		editMenu.submenu?.addItem(MenuItem("Paste", "paste:", "v", [.CommandKeyMask]))
		editMenu.submenu?.addItem(MenuItem("Select All", "selectAll:", "a", [.CommandKeyMask]))
		//WKWebView._findString(str, options: _WKFindOptions, maxCount: 1)
		// https://github.com/WebKit/webkit/blob/d82b804eac88bb7e2c96fb87fb56845ae4dd8f7f/Source/WebKit2/UIProcess/API/Cocoa/WKWebView.mm#L2049
		app!.mainMenu?.addItem(editMenu)

		let tabMenu = NSMenuItem() //WebViewController and WKWebView funcs
		tabMenu.submenu = NSMenu()
		tabMenu.submenu?.title = "Tab"
		tabMenu.submenu?.addItem(MenuItem("Zoom In", "zoomIn", "+", [.CommandKeyMask])) //wvc
		tabMenu.submenu?.addItem(MenuItem("Zoom Out", "zoomOut", "-", [.CommandKeyMask])) //wvc
		tabMenu.submenu?.addItem(MenuItem("Zoom Text Only", "zoomOut", nil, [.CommandKeyMask]))
		tabMenu.submenu?.addItem(MenuItem("Toggle Translucency", "toggleTransparency")) //wvc
		//tabMenu.submenu?.addItem(MenuItem("Web Inspector", "showConsole:", "i", [.CommandKeyMask, .AlternateKeyMask]) //need impl of WKInspectorShow
		//	^ https://bugs.webkit.org/show_bug.cgi?id=137612
		tabMenu.submenu?.addItem(MenuItem("Reload", "reload:", "r", [.CommandKeyMask])) //webview
		tabMenu.submenu?.addItem(MenuItem("Uncache & Reload", "reloadFromOrigin:", "R", [.CommandKeyMask, .ShiftKeyMask])) //webview
		tabMenu.submenu?.addItem(MenuItem("Go Back", "goBack:", "[", [.CommandKeyMask])) //webview
		tabMenu.submenu?.addItem(MenuItem("Go Forward", "goForward:", "]", [.CommandKeyMask]))	//webview
		tabMenu.submenu?.addItem(MenuItem("Stop Loading", "stopLoading:", ".", [.CommandKeyMask])) //webview
		tabMenu.submenu?.addItem(MenuItem("Print Page", "print:")) //NSView
		tabMenu.submenu?.addItem(MenuItem("Print Tab", "printTab", target: browserController)) //bc
		tabMenu.submenu?.addItem(MenuItem("Copy view as PDF text", "copyAsPDF")) //webview
		tabMenu.submenu?.addItem(MenuItem("Save Web Archive...", "saveWebArchive")) //webview
		tabMenu.submenu?.addItem(MenuItem("Open in default Browser", "askToOpenCurrentURL")) //webview
		app!.mainMenu?.addItem(tabMenu)

		let winMenu = NSMenuItem() //BrowserViewController and NSWindow funcs
		winMenu.submenu = NSMenu()
		winMenu.submenu?.title = "Window"
		winMenu.submenu?.addItem(MenuItem("Enter URL", "revealOmniBox", "l", [.CommandKeyMask])) //bc
		winMenu.submenu?.addItem(MenuItem(nil, "toggleFullScreen:")) //bc
		winMenu.submenu?.addItem(MenuItem(nil, "toggleToolbarShown:")) //bc
		winMenu.submenu?.addItem(MenuItem("Toggle Titlebar", "toggleTitlebar")) //wc
		//winMenu.submenu?.addItem(MenuItem("Edit Toolbar", "runToolbarCustomizationPalette:"))
		winMenu.submenu?.addItem(MenuItem("New Tab", "newTabPrompt", "t", [.CommandKeyMask])) //bc
		winMenu.submenu?.addItem(MenuItem("New Isolated Tab", "newIsolatedTabPrompt", "t", [.ControlKeyMask, .CommandKeyMask])) //bc
		//winMenu.submenu?.addItem(MenuItem("Close Tab", "closeCurrentTab", "w", [.CommandKeyMask])) //bc
		winMenu.submenu?.addItem(MenuItem("Close Tab", "closeTab", "w", [.CommandKeyMask])) //wvc, bc
		winMenu.submenu?.addItem(MenuItem("Show Next Tab", "selectNextTabViewItem:", String(format:"%c", NSTabCharacter), [.ControlKeyMask])) //bc
		winMenu.submenu?.addItem(MenuItem("Show Previous Tab", "selectPreviousTabViewItem:", String(format:"%c", NSTabCharacter), [.ControlKeyMask, .ShiftKeyMask])) //bc
		app!.mainMenu?.addItem(winMenu)

		let tabListMenu = NSMenuItem(title: "Tabs", action: nil, keyEquivalent: "")
		tabListMenu.submenu = browserController.tabMenu
		tabListMenu.submenu?.title = "Tabs"
		app!.mainMenu?.addItem(tabListMenu)

		let shortcutsMenu = NSMenuItem(title: "Shortcuts", action: nil, keyEquivalent: "")
		shortcutsMenu.hidden = true // not shown until $.browser.addShortcut(foo, url) is called
		shortcutsMenu.submenu = browserController.shortcutsMenu
		shortcutsMenu.submenu?.title = "Shortcuts"
		app!.mainMenu?.addItem(shortcutsMenu)

		let dbgMenu = NSMenuItem()
		dbgMenu.submenu = NSMenu()
		dbgMenu.submenu?.title = "Debug"
		//dbgMenu.submenu?.autoenablesItems = false
		dbgMenu.submenu?.addItem(MenuItem("Highlight TabView Constraints", "highlightConstraints")) //bc
		dbgMenu.submenu?.addItem(MenuItem("Randomize TabView Layout", "exerciseAmbiguityInLayout")) //bc
		dbgMenu.submenu?.addItem(MenuItem("Replace contentView With Tab", "replaceContentView")) //bc
		dbgMenu.submenu?.addItem(MenuItem("Dismiss VC", "dismissController:")) //bc
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
		windowController.window?.makeKeyAndOrderFront(self)

		NSAppleEventManager.sharedAppleEventManager().setEventHandler(self, andSelector: "handleGetURLEvent:replyEvent:", forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL)) //route registered url scehems
	}

	//func application(theApplication: NSApplication, openFile filename: String) -> Bool {}

    func applicationDidFinishLaunching(notification: NSNotification) { //dock icon stops bouncing
		AppScriptRuntime.shared.context.objectForKeyedSubscript("$").setObject(browserController, forKeyedSubscript: "browser")
		AppScriptRuntime.shared.loadSiteApp() // load app.js, if present
		AppScriptRuntime.shared.jsdelegate.tryFunc("AppFinishedLaunching")

		if let default_html = NSBundle.mainBundle().URLForResource("default", withExtension: "html") {
			warn("loading initial page from app bundle: \(default_html)")
			browserController.tabSelected = MPWebView(url: default_html)
		}

		if browserController.tabs.count < 1 { browserController.newTabPrompt() } //don't allow a tabless state

		if let userNotification = notification.userInfo?["NSApplicationLaunchUserNotificationKey"] as? NSUserNotification {
			userNotificationCenter(NSUserNotificationCenter.defaultUserNotificationCenter(), didActivateNotification: userNotification)
		}

		//warn("focus is on `\(windowController.window?.firstResponder)`")

		for (idx, arg) in enumerate(Process.arguments) {
			switch (arg) {
				case "-i":
					if isatty(1) == 1 { AppScriptRuntime.shared.REPL() } //open a JS console on the terminal, if present
					// would like to natively implement a simple remote console for webkit-using osx apps, Valence only targets IOS-usbmuxd based stuff.
					// https://www.webkit.org/blog/1875/announcing-remote-debugging-protocol-v1-0/
					// https://bugs.webkit.org/show_bug.cgi?id=124613
					// `sudo launchctl print user/com.apple.webinspectord`
					// https://github.com/google/ios-webkit-debug-proxy/blob/master/src/ios_webkit_debug_proxy.c just connect to local com.apple.webinspectord
					// https://github.com/WebKit/webkit/tree/master/Source/JavaScriptCore/inspector/protocol
					// https://github.com/WebKit/webkit/blob/master/Source/JavaScriptCore/inspector/remote/RemoteInspector.mm
					// https://github.com/WebKit/webkit/blob/master/Source/JavaScriptCore/inspector/remote/RemoteInspectorConstants.h
					// https://github.com/siuying/IGJavaScriptConsole
				case "-t":
					if isatty(1) == 1 {
						if idx + 1 >= Process.arguments.count { // no arg after this one
							browserController.tabs.first?.REPL() //open a JS console for the first tab WebView on the terminal, if present
							break
						}

						if let tabnum = Process.arguments[idx + 1].toInt() where browserController.tabs.count >= tabnum { // next argv should be tab number
							browserController.tabs[tabnum].REPL() // open a JS Console on the requested tab number
						} else {
							browserController.tabs.first?.REPL() //open a JS console for the first tab WebView on the terminal, if present
						}
					}
					// ooh, pretty: https://github.com/Naituw/WBWebViewConsole
					// https://github.com/Naituw/WBWebViewConsole/blob/master/WBWebViewConsole/Views/WBWebViewConsoleInputView.m
				default:
					if arg != Process.arguments[0] && !arg.hasPrefix("-psn_0_") { // Process Serial Number from LaunchServices open()
						warn("unrecognized argv[]: `\(arg)`")
					}
			}
		}
    }

	func applicationDidBecomeActive(notification: NSNotification) {
		//if application?.orderedDocuments?.count < 1 { showApplication(self) }
	}

	func application(application: NSApplication, willPresentError error: NSError) -> NSError {
		// not in iOS: http://stackoverflow.com/a/13083203/3878712
		// NOPE, this can cause loops warn("`\(error.localizedDescription)` [\(error.domain)] [\(error.code)] `\(error.localizedFailureReason ?? String())` : \(error.userInfo)")
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

	func applicationShouldTerminate(sender: NSApplication) -> NSApplicationTerminateReply {
		warn()
#if arch(x86_64) || arch(i386)
		if let prompter = prompter {
			return .TerminateLater
		}
#endif
		return .TerminateNow
	}

	func applicationWillTerminate(notification: NSNotification) {
		warn()
		NSUserDefaults.standardUserDefaults().synchronize()
#if arch(x86_64) || arch(i386)
		if let prompter = prompter {
			prompter.wait()	// let prompt cleanup the TTY
		}
#endif
	}

	func applicationShouldTerminateAfterLastWindowClosed(app: NSApplication) -> Bool { return true }

	// handles drag-to-dock-badge, /usr/bin/open and argv[1] requests specifiying urls & local pathnames
	func application(theApplication: NSApplication, openFile filename: String) -> Bool {
		if let ftype = NSWorkspace.sharedWorkspace().typeOfFile(filename, error: nil) {
			switch ftype {
				//case "public.data":
				//case "public.html":
				//case "public.folder":
				case "com.apple.web-internet-location": //.webloc http://stackoverflow.com/questions/146575/crafting-webloc-file
					if let webloc = NSDictionary(contentsOfFile: filename), urlstr = webloc.valueForKey("URL") as? String {
						if AppScriptRuntime.shared.jsdelegate.tryFunc("handleDragAndDroppedURLs", [urlstr]) {
					 		return true  // app.js indicated it handled drag itself
						} else if let url = validateURL(urlstr) {
							browserController.tabSelected = MPWebView(url: url)
							return true
						}
					}
					return false

				case "com.netscape.javascript-source": //.js
					warn(filename)
					AppScriptRuntime.shared.loadAppScript("file://\(filename)")
					AppScriptRuntime.shared.jsdelegate.tryFunc("AppFinishedLaunching")
					return true
				// FIXME: make a custom .macpinjs ftype
				// when opened, offer to edit, test, or package as MacPin app
				// package will use JXA scripts to do the heavy lifting, port Makefile to use them
				default: break;
			}
		}

		if let url = validateURL(filename) {
			warn("opening: \(url)")
			browserController.tabSelected = MPWebView(url: url)
			return true
		}
		return false // will generate modal error popup
	}
}

extension AppDelegateOSX: NSUserNotificationCenterDelegate {
	//didDeliverNotification
	func userNotificationCenter(center: NSUserNotificationCenter, didActivateNotification notification: NSUserNotification) {
		warn("user clicked notification")

		if AppScriptRuntime.shared.jsdelegate.tryFunc("handleClickedNotification", notification.title ?? "", notification.subtitle ?? "", notification.informativeText ?? "", notification.identifier ?? "") {
			warn("handleClickedNotification fired!")
			center.removeDeliveredNotification(notification)
		}
	}

	// always display notifcations, even if app is active in foreground (for alert sounds)
	func userNotificationCenter(center: NSUserNotificationCenter, shouldPresentNotification notification: NSUserNotification) -> Bool { return true }
}

extension AppDelegateOSX: NSWindowRestoration {
	// https://developer.apple.com/library/mac/documentation/General/Conceptual/MOSXAppProgrammingGuide/CoreAppDesign/CoreAppDesign.html#//apple_ref/doc/uid/TP40010543-CH3-SW35
	class func restoreWindowWithIdentifier(identifier: String, state: NSCoder, completionHandler: ((NSWindow!,NSError!) -> Void)) {
		if let app = NSApplication.sharedApplication().delegate as? AppDelegateOSX, let window = app.windowController.window {
			completionHandler(window, nil)
			//WKWebView._restoreFromSessionStateData ...
		} else {
			completionHandler(nil, nil)
		}
	}
}

// modules/WebKitPrivates/_WKDownloadDelegate.h
// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/Cocoa/DownloadClient.mm
// https://github.com/WebKit/webkit/blob/master/Tools/TestWebKitAPI/Tests/WebKit2Cocoa/Download.mm
extension AppDelegateOSX: _WKDownloadDelegate {
	override func _download(download: _WKDownload!, decideDestinationWithSuggestedFilename filename: String!, allowOverwrite: UnsafeMutablePointer<ObjCBool>) -> String! {
		warn(download.description)
		//pop open a save Panel to dump data into file
		let saveDialog = NSSavePanel();
		saveDialog.canCreateDirectories = true
		saveDialog.nameFieldStringValue = filename
		if let app = NSApplication.sharedApplication().delegate as? AppDelegateOSX, let window = app.windowController.window {
			let result = saveDialog.runModal()
			if let url = saveDialog.URL, path = url.path where result == NSFileHandlingPanelOKButton {
				warn(path)
				return path
			}
		}
		download.cancel()
		return ""
	}
}
