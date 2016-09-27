import AppKit
import ObjectiveC
import WebKitPrivates
import Darwin
//import Bookmarks

//@NSApplicationMain // doesn't work without NIBs, using main.swift instead
public class MacPinAppDelegateOSX: NSObject, MacPinAppDelegate {

	var browserController: BrowserViewController = BrowserViewControllerOSX()
	var window: Window?

	var effectController = EffectViewController()
	var windowController: WindowController

	override init() {
		// gotta set these before MacPin()->NSWindow()
		NSUserDefaults.standardUserDefaults().registerDefaults([
			"NSQuitAlwaysKeepsWindows":	true, // insist on Window-to-Space/fullscreen persistence between launches
			"NSInitialToolTipDelay": 1, // get TTs in 1ms instead of 3s
			"NSInitialToolTipFontSize": 12.0,
			// NSUserDefaults for NetworkProcesses:
			//		https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/Cocoa/WebProcessPoolCocoa.mm
			// 		WebKit2HTTPProxy, WebKit2HTTPSProxy, WebKitOmitPDFSupport, all the cache directories ...
			// 		https://lists.webkit.org/pipermail/webkit-dev/2016-May/028233.html
			"WebKit2HTTPProxy": "",
			"WebKit2HTTPSProxy": "",
			"URLParserEnabled": "" // JS: new URL()
			// wish there was defaults for:
			// 		https://github.com/WebKit/webkit/blob/master/Source/WebKit2/NetworkProcess/mac/NetworkProcessMac.mm overrideSystemProxies()
			// SOCKS (kCFProxyTypeSOCKS)
			// PAC URL (kCFProxyTypeAutoConfigurationURL + kCFProxyAutoConfigurationURLKey)
			// PAC script (kCFProxyTypeAutoConfigurationJavaScript + kCFProxyAutoConfigurationJavaScriptKey)
			//_CFNetworkSetOverrideSystemProxySettings(CFDict)
		])

		NSUserDefaults.standardUserDefaults().removeObjectForKey("__WebInspectorPageGroupLevel1__.WebKit2InspectorStartsAttached") // #13 fixed

		//browserController.title = nil
		//browserController.canPropagateSelectedChildViewControllerTitle = true
		let win = NSWindow(contentViewController: effectController)
		windowController = WindowController(window: win)
		effectController.view.addSubview(browserController.view)
		browserController.view.frame = effectController.view.bounds
		self.window = win

		super.init()
	}

	// handle URLs passed by open
	func handleGetURLEvent(event: NSAppleEventDescriptor!, replyEvent: NSAppleEventDescriptor?) {
		if let urlstr = event.paramDescriptorForKeyword(AEKeyword(keyDirectObject))!.stringValue {
			warn("`\(urlstr)` -> AppScriptRuntime.shared.jsdelegate.launchURL()")
			AppScriptRuntime.shared.exports.setObject(urlstr, forKeyedSubscript: "launchedWithURL")
			AppScriptRuntime.shared.jsdelegate.tryFunc("launchURL", urlstr)
			//replyEvent == ??
		}
		//replyEvent == ??
	}
}

extension MacPinAppDelegateOSX: ApplicationDelegate {

	public func applicationDockMenu(sender: NSApplication) -> NSMenu? { return browserController.tabMenu }

	public func applicationShouldOpenUntitledFile(app: NSApplication) -> Bool { return false }

	//public func application(sender: AnyObject, openFileWithoutUI filename: String) -> Bool {} // app terminates on return!
	//public func application(theApplication: NSApplication, printFile filename: String) -> Bool {} // app terminates on return

	//public func finishLaunching() { super.finishLaunching() } // app activates, NSOpen files opened

	public func applicationWillFinishLaunching(notification: NSNotification) { // dock icon bounces, also before self.openFile(foo.bar) is called
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
		appMenu.submenu?.addItem(MenuItem("Hide \(appname)", "hide:", "h", [.Command]))
		appMenu.submenu?.addItem(MenuItem("Hide Others", "hideOtherApplications:", "H", [.Command, .Shift]))
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
		editMenu.submenu?.addItem(MenuItem("Cut", "cut:", "x", [.Command]))
		editMenu.submenu?.addItem(MenuItem("Copy", "copy:", "c", [.Command]))
		editMenu.submenu?.addItem(MenuItem("Paste", "paste:", "v", [.Command]))
		editMenu.submenu?.addItem(MenuItem("Select All", "selectAll:", "a", [.Command]))
		editMenu.submenu?.addItem(NSMenuItem.separatorItem())
		let findMenu = MenuItem("Find")
		findMenu.submenu = NSMenu()
		findMenu.submenu?.title = "Find"
		findMenu.submenu?.addItem(MenuItem("Find...", "performTextFinderAction:", "f", [.Command], tag: NSTextFinderAction.ShowFindInterface.rawValue)) //wvc
		findMenu.submenu?.addItem(MenuItem("Find Next", "performTextFinderAction:", tag: NSTextFinderAction.NextMatch.rawValue)) //wvc
		findMenu.submenu?.addItem(MenuItem("Find Previous", "performTextFinderAction:", tag: NSTextFinderAction.PreviousMatch.rawValue)) //wvc
		findMenu.submenu?.addItem(MenuItem("Find and Replace...", "performTextFinderAction:", tag: NSTextFinderAction.ShowReplaceInterface.rawValue)) //wvc
		findMenu.submenu?.addItem(MenuItem("Search within Selection", "performTextFinderAction:", tag: NSTextFinderAction.SelectAllInSelection.rawValue)) //wvc
		editMenu.submenu?.addItem(findMenu)
		app!.mainMenu?.addItem(editMenu)

		let tabMenu = NSMenuItem() //WebViewController and WKWebView funcs
		tabMenu.submenu = NSMenu()
		tabMenu.submenu?.title = "Tab"
		tabMenu.submenu?.addItem(MenuItem("Zoom In", "zoomIn", "+", [.Command])) //wvc
		tabMenu.submenu?.addItem(MenuItem("Zoom Out", "zoomOut", "-", [.Command])) //wvc
		tabMenu.submenu?.addItem(MenuItem("Zoom Text Only", "zoomText", nil, [.Command]))
		tabMenu.submenu?.addItem(MenuItem("Toggle Translucency", "toggleTransparency")) //wvc
		tabMenu.submenu?.addItem(NSMenuItem.separatorItem())
		tabMenu.submenu?.addItem(MenuItem("Show JS Console", "console", "c", [.Option, .Command])) //wv
		tabMenu.submenu?.addItem(MenuItem("Reload", "reload:", "r", [.Command])) //webview
		tabMenu.submenu?.addItem(MenuItem("Uncache & Reload", "reloadFromOrigin:", "R", [.Command, .Shift])) //webview
		tabMenu.submenu?.addItem(MenuItem("Go Back", "goBack:", "[", [.Command])) //webview
		tabMenu.submenu?.addItem(MenuItem("Go Forward", "goForward:", "]", [.Command]))	//webview
		tabMenu.submenu?.addItem(MenuItem("Stop Loading", "stopLoading:", ".", [.Command])) //webview
		tabMenu.submenu?.addItem(NSMenuItem.separatorItem())
		tabMenu.submenu?.addItem(MenuItem("Print Page...", "printWebView:", "p", [.Command])) //webview
		tabMenu.submenu?.addItem(MenuItem("Save Web Archive...", "saveWebArchive", "s", [.Command, .Shift])) //webview
		tabMenu.submenu?.addItem(MenuItem("Save Page...", "savePage", "s", [.Command])) //webview
		tabMenu.submenu?.addItem(MenuItem("Open with Default Browser", "askToOpenCurrentURL", "d", [.Command])) //wvc
		app!.mainMenu?.addItem(tabMenu)

		let winMenu = NSMenuItem() //BrowserViewController and NSWindow funcs
		winMenu.submenu = NSMenu()
		winMenu.submenu?.title = "Window"
		winMenu.submenu?.addItem(MenuItem("Enter URL", "revealOmniBox", "l", [.Command])) //bc
		winMenu.submenu?.addItem(MenuItem(nil, "toggleFullScreen:")) //bc
		winMenu.submenu?.addItem(MenuItem(nil, "toggleToolbarShown:")) //bc
		winMenu.submenu?.addItem(MenuItem("Toggle Titlebar", "toggleTitlebar")) //wc
		//winMenu.submenu?.addItem(MenuItem("Edit Toolbar", "runToolbarCustomizationPalette:"))
		winMenu.submenu?.addItem(MenuItem("New Tab", "newTabPrompt", "t", [.Command])) //bc
		winMenu.submenu?.addItem(MenuItem("New Isolated Tab", "newIsolatedTabPrompt")) //bc
		winMenu.submenu?.addItem(MenuItem("New Private Tab", "newPrivateTabPrompt", "t", [.Control, .Command])) //bc
		winMenu.submenu?.addItem(MenuItem("Close Tab", "closeTab", "w", [.Command])) //wvc, bc
		winMenu.submenu?.addItem(MenuItem("Show Next Tab", "selectNextTabViewItem:", String(format:"%c", NSTabCharacter), [.Control])) //bc
		winMenu.submenu?.addItem(MenuItem("Show Previous Tab", "selectPreviousTabViewItem:", String(format:"%c", NSTabCharacter), [.Control, .Shift])) //bc
		app!.mainMenu?.addItem(winMenu)

		let tabListMenu = NSMenuItem(title: "Tabs", action: nil, keyEquivalent: "")
		tabListMenu.submenu = browserController.tabMenu
		tabListMenu.submenu?.title = "Tabs"
		app!.mainMenu?.addItem(tabListMenu)

		// Tuck these under the app menu?
		let shortcutsMenu = NSMenuItem(title: "Shortcuts", action: nil, keyEquivalent: "")
		shortcutsMenu.hidden = true // not shown until $.browser.addShortcut(foo, url) is called
		shortcutsMenu.submenu = browserController.shortcutsMenu
		shortcutsMenu.submenu?.title = "Shortcuts"
		app!.mainMenu?.addItem(shortcutsMenu)

/*
		let bookMenu = NSMenuItem()
		bookMenu.submenu = NSMenu()
		bookMenu.submenu?.title = "Bookmarks"
		let bookmarks = Bookmark.readFrom("~/Library/Safari/Bookmarks.plist")
		app!.mainMenu?.addItem(bookMenu)
		// https://github.com/peckrob/FRBButtonBar
*/

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

		windowController.window?.initialFirstResponder = browserController.view // should defer to selectedTab.initialFirstRepsonder
		windowController.window?.bind(NSTitleBinding, toObject: browserController, withKeyPath: "title", options: nil)
		windowController.window?.makeKeyAndOrderFront(self)

		NSAppleEventManager.sharedAppleEventManager().setEventHandler(self, andSelector: #selector(MacPinAppDelegateOSX.handleGetURLEvent(_:replyEvent:)), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL)) //route registered url schemes
	}

    public func applicationDidFinishLaunching(notification: NSNotification) { //dock icon stops bouncing

/*
		http://stackoverflow.com/a/13621414/3878712
    	NSSetUncaughtExceptionHandler { exception in
		    print(exception)
		    print(exception.callStackSymbols)
		    prompter = nil // deinit prompter to cleanup the TTY
		}
*/

		browserController.extend(AppScriptRuntime.shared.exports)
		AppScriptRuntime.shared.loadSiteApp() // load app.js, if present
		AppScriptRuntime.shared.jsdelegate.tryFunc("AppFinishedLaunching")

		if let default_html = NSBundle.mainBundle().URLForResource("default", withExtension: "html") {
			warn("loading initial page from app bundle: \(default_html)")
			browserController.tabSelected = MPWebView(url: default_html)
		}

		if let userNotification = notification.userInfo?["NSApplicationLaunchUserNotificationKey"] as? NSUserNotification {
			userNotificationCenter(NSUserNotificationCenter.defaultUserNotificationCenter(), didActivateNotification: userNotification)
		}

		let launched = Process.arguments.dropFirst().first?.hasPrefix("-psn_0_") ?? false // Process Serial Number from LaunchServices open()
		warn(Process.arguments.description)
		for (idx, arg) in Process.arguments.dropFirst().enumerate() {
			switch (arg) {
				case "-i" where isatty(1) == 1:
					 //open a JS console on the terminal, if present
					if let repl_js = NSBundle.mainBundle().URLForResource("app_repl", withExtension: "js") { AppScriptRuntime.shared.loadAppScript(repl_js.description); }
					AppScriptRuntime.shared.REPL()
					// would like to natively implement a simple remote console for webkit-using osx apps, Valence only targets IOS-usbmuxd based stuff.
					// https://www.webkit.org/blog/1875/announcing-remote-debugging-protocol-v1-0/
					// https://bugs.webkit.org/show_bug.cgi?id=124613
					// `sudo launchctl print user/com.apple.webinspectord`
					// https://github.com/google/ios-webkit-debug-proxy/blob/master/src/ios_webkit_debug_proxy.c just connect to local com.apple.webinspectord
					// https://github.com/WebKit/webkit/tree/master/Source/JavaScriptCore/inspector/protocol
					// https://github.com/WebKit/webkit/blob/master/Source/JavaScriptCore/inspector/remote/RemoteInspector.mm
					// https://github.com/WebKit/webkit/blob/master/Source/JavaScriptCore/inspector/remote/RemoteInspectorConstants.h
					// https://github.com/siuying/IGJavaScriptConsole
				case "-t" where isatty(1) == 1:
					if idx + 1 >= Process.arguments.count { // no arg after this one
						browserController.tabs.first?.REPL() //open a JS console for the first tab WebView on the terminal, if present
						break
					}

					if let tabnum = Int(Process.arguments[idx + 1]) where browserController.tabs.count >= tabnum { // next argv should be tab number
						browserController.tabs[tabnum].REPL() // open a JS Console on the requested tab number
						// FIXME skip one more arg
					} else {
						browserController.tabs.first?.REPL() //open a JS console for the first tab WebView on the terminal, if present
					}
					// ooh, pretty: https://github.com/Naituw/WBWebViewConsole
					// https://github.com/Naituw/WBWebViewConsole/blob/master/WBWebViewConsole/Views/WBWebViewConsoleInputView.m
				case let isurl where !launched && (arg.hasPrefix("http:") || arg.hasPrefix("https:")):
					warn("launched: \(launched) -> \(arg)")
					application(NSApp, openFile: arg) // LS will openFile AND argv.append() fully qualified URLs
				default:
					// FIXME unqualified URL from cmdline get openFile()d for some reason
					warn("unrecognized argv[\(idx)]: `\(arg)`")
			}
		}

		//NSApp.setServicesProvider(ServiceOSX())

		//dispatch_sync(dispatch_get_main_queue(), {
		//dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
			// JS tab additions are done on background queue -- wait for them to flush out
			//if self.browserController.tabs.count < 1 { self.browserController.newTabPrompt() } //don't allow a tabless state
		//})

		//warn("focus is on `\(windowController.window?.firstResponder)`")

    }

	public func applicationDidBecomeActive(notification: NSNotification) {
		//if application?.orderedDocuments?.count < 1 { showApplication(self) }
	}

	public func application(application: NSApplication, willPresentError error: NSError) -> NSError {
		// not in iOS: http://stackoverflow.com/a/13083203/3878712
		// NOPE, this can cause loops warn("`\(error.localizedDescription)` [\(error.domain)] [\(error.code)] `\(error.localizedFailureReason ?? String())` : \(error.userInfo)")
		if error.domain == NSURLErrorDomain {
			let uI = error.userInfo
			if let errstr = uI[NSLocalizedDescriptionKey] as? String {
				if let url = uI[NSURLErrorFailingURLStringErrorKey] as? String {
					var newUserInfo = uI
					newUserInfo[NSLocalizedDescriptionKey] = "\(errstr)\n\n\(url)" // add failed url to error message
					let newerror = NSError(domain: error.domain, code: error.code, userInfo: newUserInfo)
					return newerror
				}
			}
		}
		return error
	}

	public func applicationShouldTerminate(sender: NSApplication) -> NSApplicationTerminateReply {
		warn()
		//browserController.close() // kill the tabs
		//windowController.close() // kill the window
		// unfocus app?
#if arch(x86_64) || arch(i386)
		if prompter != nil { return .TerminateLater } // wait for user to EOF the Prompt
#endif
		return .TerminateNow
	}

	public func applicationWillTerminate(notification: NSNotification) {
		warn()
		NSUserDefaults.standardUserDefaults().synchronize()
#if arch(x86_64) || arch(i386)
		if let prompter = prompter {
			prompter.wait()	// let prompter deinit and cleanup the TTY
		}
#endif
	}

	public func applicationShouldTerminateAfterLastWindowClosed(app: NSApplication) -> Bool { return true }

	// handles drag-to-dock-badge, /usr/bin/open and argv[1:] requests specifiying urls & local pathnames
	public func application(theApplication: NSApplication, openFile filename: String) -> Bool {
		warn(filename)
		if let ftype = try? NSWorkspace.sharedWorkspace().typeOfFile(filename) {
			switch ftype {
				//case "public.data":
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
				case "public.html":
					warn(filename)
					browserController.tabSelected = MPWebView(url: NSURL(string:"file://\(filename)")!)
					return true
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
		warn("not opening: \(filename)")
		return false // will generate modal error popup
	}
}

extension MacPinAppDelegateOSX: NSUserNotificationCenterDelegate {
	//didDeliverNotification
	public func userNotificationCenter(center: NSUserNotificationCenter, didActivateNotification notification: NSUserNotification) {
		warn("user clicked notification")

		if AppScriptRuntime.shared.jsdelegate.tryFunc("handleClickedNotification", notification.title ?? "", notification.subtitle ?? "", notification.informativeText ?? "", notification.identifier ?? "") {
			warn("handleClickedNotification fired!")
			center.removeDeliveredNotification(notification)
		}
	}

	// always display notifcations, even if app is active in foreground (for alert sounds)
	public func userNotificationCenter(center: NSUserNotificationCenter, shouldPresentNotification notification: NSUserNotification) -> Bool { return true }
}

extension MacPinAppDelegateOSX: NSWindowRestoration {
	// https://developer.apple.com/library/mac/documentation/General/Conceptual/MOSXAppProgrammingGuide/CoreAppDesign/CoreAppDesign.html#//apple_ref/doc/uid/TP40010543-CH3-SW35
	public static func restoreWindowWithIdentifier(identifier: String, state: NSCoder, completionHandler: ((NSWindow?,NSError?) -> Void)) {
		if let app = MacPinApp.sharedApplication().appDelegate, let window = app.window where identifier == "browser" {
			completionHandler(window, nil)
			//WKWebView._restoreFromSessionStateData ...
		} else {
			completionHandler(nil, nil)
		}
	}
}
