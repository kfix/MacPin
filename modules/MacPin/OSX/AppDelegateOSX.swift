import AppKit
import ObjectiveC
import WebKitPrivates
import Darwin
//import Bookmarks

//@NSApplicationMain // doesn't work without NIBs, using main.swift instead
open class MacPinAppDelegateOSX: NSObject, MacPinAppDelegate {

	var browserController: BrowserViewController = BrowserViewControllerOSX()
	var window: Window?

	var effectController = EffectViewController()
	var windowController: WindowController? // optional so app can run "headless" if desired

	override init() {
		// gotta set these before MacPin()->NSWindow()
		UserDefaults.standard.register(defaults: [
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

		UserDefaults.standard.removeObject(forKey: "__WebInspectorPageGroupLevel1__.WebKit2InspectorStartsAttached") // #13 fixed

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
	@objc func handleGetURLEvent(_ event: NSAppleEventDescriptor!, replyEvent: NSAppleEventDescriptor?) {
		if let urlstr = event.paramDescriptor(forKeyword: AEKeyword(keyDirectObject))!.stringValue {
			warn("`\(urlstr)` -> AppScriptRuntime.shared.jsdelegate.launchURL()")
			AppScriptRuntime.shared.exports.setObject(urlstr, forKeyedSubscript: "launchedWithURL" as NSString)
			AppScriptRuntime.shared.emit(.launchURL, urlstr)
			//replyEvent == ??
		}
		//replyEvent == ??
	}

	func updateProxies() {
		let alert = NSAlert()
		alert.messageText = "Set HTTP(s) proxy"
		alert.addButton(withTitle: "Update")
		alert.informativeText = "Enter the proxy URL:"
		alert.icon = Application.shared.applicationIconImage
		let input = NSTextField(frame: NSMakeRect(0, 0, 200, 24))
		input.stringValue = UserDefaults.standard.string(forKey: "WebKit2HTTPProxy") ?? ""
		input.isEditable = true
 		alert.accessoryView = input
 		guard let window = window else { return }
		alert.beginSheetModal(for: window, completionHandler: { (response: NSApplication.ModalResponse) -> Void in
			UserDefaults.standard.set(input.stringValue, forKey: "WebKit2HTTPProxy")
			UserDefaults.standard.set(input.stringValue, forKey: "WebKit2HTTPSProxy")
			UserDefaults.standard.synchronize()
			// FIXME: need to serialize all tabs & reinit them for proxy change to take effect?
		})
	}

}

@objc extension MacPinAppDelegateOSX: ApplicationDelegate {

	//@available(macOS, obsoleted: 10.13, message: "High Sierra is on drugs!")
	public func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
		warn()
		if #available(OSX 10.13, iOS 11, *) {
			// high sierra seems to cache a *copy* of the tabMenu (containing tabviewitems holding refs to webViews' props) thru NSCopying
			//	until its clicked on *or* until it garbage-collect itself every minute or so
			// causes webview to be retained after close, beacuse the copied menu is stale after tabs are closed and the master menu is updated
			return nil
		} else {
			return browserController.tabMenu
		}
	}

	public func applicationShouldOpenUntitledFile(_ app: NSApplication) -> Bool { return false }

	//public func application(sender: AnyObject, openFileWithoutUI filename: String) -> Bool {} // app terminates on return!
	//public func application(theApplication: NSApplication, printFile filename: String) -> Bool {} // app terminates on return

	//public func finishLaunching() { super.finishLaunching() } // app activates, NSOpen files opened

	public func applicationWillFinishLaunching(_ notification: Notification) { // dock icon bounces, also before self.openFile(foo.bar) is called
		NSUserNotificationCenter.default.delegate = self
		let app = notification.object as? NSApplication
		//let appname = NSBundle.mainBundle().objectForInfoDictionaryKey("CFBundleName") ?? NSProcessInfo.processInfo().processName
		let appname = NSRunningApplication.current.localizedName ?? ProcessInfo.processInfo.processName

		app!.mainMenu = NSMenu()

		let appMenu = NSMenuItem()
		appMenu.submenu = NSMenu()
		appMenu.submenu?.addItem(MenuItem("About \(appname)", "orderFrontStandardAboutPanel:"))
		appMenu.submenu?.addItem(MenuItem("Restart \(appname)", #selector(AppScriptRuntime.loadSiteApp)))
		appMenu.submenu?.addItem(NSMenuItem.separator())
		appMenu.submenu?.addItem(MenuItem("Hide \(appname)", "hide:", "h", [.command]))
		appMenu.submenu?.addItem(MenuItem("Hide Others", "hideOtherApplications:", "H", [.command, .shift]))
		appMenu.submenu?.addItem(NSMenuItem.separator())
		//appMenu.submenu?.addItem(MenuItem("Edit App...", "editSiteApp")) // can't modify signed apps' Resources
		app!.mainMenu?.addItem(appMenu) // 1st item shows up as CFPrintableName

		app!.servicesMenu = NSMenu()
		let svcMenu = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
		svcMenu.submenu = app!.servicesMenu!
		appMenu.submenu?.addItem(svcMenu)
		appMenu.submenu?.addItem(MenuItem("Preferences...", "updateProxies")) // not much for now
		appMenu.submenu?.addItem(MenuItem("Quit \(appname)", "terminate:", "q"))

		let editMenu = NSMenuItem() //NSTextArea funcs
		// plutil -p /System/Library/Frameworks/AppKit.framework/Resources/StandardKeyBinding.dict
		editMenu.submenu = NSMenu()
		editMenu.submenu?.title = "Edit" // https://github.com/WebKit/webkit/commit/f53fbb8b6c206c3cdd8d010267b8d6c430a02dab
		// & https://github.com/WebKit/webkit/commit/a580e447224c51e7cb28a1d03ca96d5ff851e6e1
		editMenu.submenu?.addItem(MenuItem("Cut", "cut:", "x", [.command]))
		editMenu.submenu?.addItem(MenuItem("Copy", "copy:", "c", [.command]))
		editMenu.submenu?.addItem(MenuItem("Paste", "paste:", "v", [.command]))
		editMenu.submenu?.addItem(MenuItem("Select All", "selectAll:", "a", [.command]))
		editMenu.submenu?.addItem(NSMenuItem.separator())
		let findMenu = MenuItem("Find")
		findMenu.submenu = NSMenu()
		findMenu.submenu?.title = "Find"
		findMenu.submenu?.addItem(MenuItem("Find...", "performTextFinderAction:", "f", [.command], tag: NSTextFinder.Action.showFindInterface.rawValue)) //wvc
		findMenu.submenu?.addItem(MenuItem("Find Next", "performTextFinderAction:", tag: NSTextFinder.Action.nextMatch.rawValue)) //wvc
		findMenu.submenu?.addItem(MenuItem("Find Previous", "performTextFinderAction:", tag: NSTextFinder.Action.previousMatch.rawValue)) //wvc
		findMenu.submenu?.addItem(MenuItem("Find and Replace...", "performTextFinderAction:", tag: NSTextFinder.Action.showReplaceInterface.rawValue)) //wvc
		findMenu.submenu?.addItem(MenuItem("Search within Selection", "performTextFinderAction:", tag: NSTextFinder.Action.selectAllInSelection.rawValue)) //wvc
		editMenu.submenu?.addItem(findMenu)
		app!.mainMenu?.addItem(editMenu)

		let tabMenu = NSMenuItem() //WebViewController and WKWebView funcs
		tabMenu.submenu = NSMenu()
		tabMenu.submenu?.title = "Tab"
		tabMenu.submenu?.addItem(MenuItem("Zoom In", #selector(WebViewControllerOSX.zoomIn), "+", [.command]))
		tabMenu.submenu?.addItem(MenuItem("Zoom Out", #selector(WebViewControllerOSX.zoomOut), "-", [.command]))
		tabMenu.submenu?.addItem(MenuItem("Zoom Text Only", #selector(WebViewControllerOSX.zoomText), nil, [.command]))
		tabMenu.submenu?.addItem(MenuItem("Toggle Translucency", #selector(WebViewControllerOSX.toggleTransparency)))
		tabMenu.submenu?.addItem(NSMenuItem.separator())
		tabMenu.submenu?.addItem(MenuItem("Show JS Console", #selector(MPWebView.console), "c", [.option, .command]))
		tabMenu.submenu?.addItem(MenuItem("Toggle Web Inspector", #selector(WebViewControllerOSX.showHideWebInspector(_:)), "i", [.option, .command]))
		tabMenu.submenu?.addItem(MenuItem("Reload", #selector(MPWebView.reload(_:)), "r", [.command]))
		tabMenu.submenu?.addItem(MenuItem("Uncache & Reload", #selector(MPWebView.reloadFromOrigin(_:)), "R", [.command, .shift]))
		tabMenu.submenu?.addItem(MenuItem("Go Back", #selector(MPWebView.goBack(_:)), "[", [.command]))
		tabMenu.submenu?.addItem(MenuItem("Go Forward", #selector(MPWebView.goForward(_:)), "]", [.command]))
		tabMenu.submenu?.addItem(MenuItem("Stop Loading", #selector(MPWebView.stopLoading(_:)), ".", [.command]))
		tabMenu.submenu?.addItem(NSMenuItem.separator())
		tabMenu.submenu?.addItem(MenuItem("Print Page...", #selector(MPWebView.printWebView), "p", [.command]))
		tabMenu.submenu?.addItem(MenuItem("Save Web Archive...", #selector(MPWebView.saveWebArchive), "s", [.command, .shift]))
		tabMenu.submenu?.addItem(MenuItem("Save Page...", #selector(MPWebView.savePage), "s", [.command]))
		tabMenu.submenu?.addItem(MenuItem("Open with Default Browser", #selector(WebViewControllerOSX.askToOpenCurrentURL), "d", [.command]))
		app!.mainMenu?.addItem(tabMenu)

		let winMenu = NSMenuItem() //BrowserViewController and NSWindow funcs
		winMenu.submenu = NSMenu()
		winMenu.submenu?.title = "Window"
		winMenu.submenu?.addItem(MenuItem("Enter URL", #selector(BrowserViewControllerOSX.revealOmniBox), "l", [.command]))
		winMenu.submenu?.addItem(MenuItem(nil, #selector(NSWindow.toggleFullScreen(_:))))
		winMenu.submenu?.addItem(MenuItem(nil, #selector(NSWindow.toggleToolbarShown(_:))))
		winMenu.submenu?.addItem(MenuItem("Toggle Titlebar", #selector(WindowController.toggleTitlebar)))
		//winMenu.submenu?.addItem(MenuItem("Edit Toolbar", "runToolbarCustomizationPalette:"))
		winMenu.submenu?.addItem(MenuItem("New Tab", #selector(BrowserViewControllerOSX.newTabPrompt), "t", [.command]))
		winMenu.submenu?.addItem(MenuItem("New Isolated Tab", #selector(BrowserViewControllerOSX.newIsolatedTabPrompt)))
		winMenu.submenu?.addItem(MenuItem("New Private Tab", #selector(BrowserViewControllerOSX.newPrivateTabPrompt), "t", [.control, .command]))
		winMenu.submenu?.addItem(MenuItem("Close Tab", #selector(BrowserViewControllerOSX.closeTab(_:)), "w", [.command]))
		winMenu.submenu?.addItem(MenuItem("Show Next Tab", #selector(NSTabView.selectNextTabViewItem(_:)), String(format:"%c", NSTabCharacter), [.control]))
		winMenu.submenu?.addItem(MenuItem("Show Previous Tab", #selector(NSTabView.selectPreviousTabViewItem(_:)), String(format:"%c", NSTabCharacter), [.control, .shift]))
		app!.mainMenu?.addItem(winMenu)

		let tabListMenu = NSMenuItem(title: "Tabs", action: nil, keyEquivalent: "")
		tabListMenu.submenu = browserController.tabMenu
		tabListMenu.submenu?.title = "Tabs"
		app!.mainMenu?.addItem(tabListMenu)

		// Tuck these under the app menu?
		let shortcutsMenu = NSMenuItem(title: "Shortcuts", action: nil, keyEquivalent: "")
		shortcutsMenu.isHidden = true // not shown until $.browser.addShortcut(foo, url) is called
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
		dbgMenu.isHidden = true
#endif
		app!.mainMenu?.addItem(dbgMenu)

		// https://developer.apple.com/documentation/appkit/nsappearancecustomization/choosing_a_specific_appearance_for_your_app#2993819
		// NSApp.appearance = NSAppearance(named: .darkAqua) // NSApp.effectiveAppearance

		windowController?.window?.initialFirstResponder = browserController.view // should defer to selectedTab.initialFirstRepsonder
		windowController?.window?.bind(NSBindingName.title, to: browserController, withKeyPath: #keyPath(BrowserViewController.title), options: nil)
		windowController?.window?.makeKeyAndOrderFront(self)

		NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(MacPinAppDelegateOSX.handleGetURLEvent(_:replyEvent:)), forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL)) //route registered url schemes
	}

    public func applicationDidFinishLaunching(_ notification: Notification) { //dock icon stops bouncing

/*
		http://stackoverflow.com/a/13621414/3878712
    	NSSetUncaughtExceptionHandler { exception in
		    print(exception)
		    print(exception.callStackSymbols)
		    prompter = nil // deinit prompter to cleanup the TTY
		}
*/

/*
        NSSetUncaughtExceptionHandler { (exception) in
            let source:String = exception.callStackSymbols[4]
            let separatorSet = CharacterSet(charactersIn: " -[]+?,")
            var array:[String] = source.components(separatedBy: separatorSet)
            array = array.filter({ $0 != "" })
            let exceptionStr:String = array[3];
            let exceptionArr=exceptionStr.split(separator: "\\d+")
            print("filename : \(exceptionArr[2])")
            print("method : \(exceptionArr[3])")
        }
*/

		browserController.extend(AppScriptRuntime.shared.exports)
		AppScriptRuntime.shared.loadSiteApp() // load app.js, if present
		//AppScriptRuntime.shared.jsdelegate.tryFunc("AppFinishedLaunching")
		AppScriptRuntime.shared.emit(.AppFinishedLaunching, "launched with this url")
		AppScriptRuntime.shared.context.evaluateScript("eval = null;") // security thru obscurity

		if let default_html = Bundle.main.url(forResource: "default", withExtension: "html") {
			warn("loading initial page from app bundle: \(default_html)")
			browserController.tabSelected = MPWebView(url: default_html as NSURL)
		}

		if let userNotification = notification.userInfo?["NSApplicationLaunchUserNotificationKey"] as? NSUserNotification {
			userNotificationCenter(NSUserNotificationCenter.default, didActivate: userNotification)
		}

		let launched = CommandLine.arguments.dropFirst().first?.hasPrefix("-psn_0_") ?? false // Process Serial Number from LaunchServices open()
		warn(CommandLine.arguments.description)
		for (idx, arg) in CommandLine.arguments.dropFirst().enumerated() {
			switch (arg) {
				case "-i" where isatty(1) == 1:

#if !(SAFARIDBG)
	// runtime check possible to confirm active remote inspector?

			// make thrown exceptions popup an nserror displaying the file name and error type,
			//   which will be shunted to console.log
			AppScriptRuntime.shared.context.exceptionHandler = { context, exception in
				let line = exception?.forProperty("line").toNumber()
				let column = exception?.forProperty("column").toNumber()
				let stack = exception?.forProperty("stack").toString()
				let message = exception?.forProperty("message").toString()
				let error = NSError(domain: "MacPin", code: 4, userInfo: [
					NSURLErrorKey: context?.name as Any,
					NSLocalizedDescriptionKey: "JS Exception @ \(line ?? -1):\(column ?? -1): \(message ?? "?")\n\(stack ?? "?")"
					// exception seems to be Error.toString(). I want .message|line|column|stack too
				])
				displayError(error) // FIXME: would be nicer to pop up an inspector pane or tab to interactively debug this
				context?.exception = exception //default in JSContext.mm
				return // gets returned to evaluateScript()?
			}
			// if you don't set the exception handler, JSC will directly pass them to console.* so they could bubble up to the Inspector
#endif

					//open a JS console on the terminal, if present
					//AppScriptRuntime.shared.eventCallbacks[.printToREPL, default: []]
					if AppScriptRuntime.shared.eventCallbacks[.printToREPL, default: []].isEmpty {
						if let repl_js = Bundle.main.url(forResource: "app_repl", withExtension: "js") {
							AppScriptRuntime.shared.loadAppScript(repl_js.description)
						}
					}
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
					if idx + 1 >= CommandLine.arguments.count { // no arg after this one
						browserController.tabs.first?.REPL() //open a JS console for the first tab WebView on the terminal, if present
						break
					}

					if let tabnum = Int(CommandLine.arguments[idx + 1]), browserController.tabs.count >= tabnum { // next argv should be tab number
						browserController.tabs[tabnum].REPL() // open a JS Console on the requested tab number
						// FIXME skip one more arg
					} else {
						browserController.tabs.first?.REPL() //open a JS console for the first tab WebView on the terminal, if present
					}
					// ooh, pretty: https://github.com/Naituw/WBWebViewConsole
					// https://github.com/Naituw/WBWebViewConsole/blob/master/WBWebViewConsole/Views/WBWebViewConsoleInputView.m
				case let _ where !launched && (arg.hasPrefix("http:") || arg.hasPrefix("https:") || arg.hasPrefix("about:") || arg.hasPrefix("file:")):
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
		DispatchQueue.main.async {
			// JS tab additions are done on background queue -- wait for them to flush out
			if self.browserController.tabs.count < 1 { self.browserController.newTabPrompt() } //don't allow a tabless state
		}
		//})

		windowController?.window?.makeFirstResponder(browserController.view)
		warn("focus is on `\(windowController?.window?.firstResponder)`")

    }

	public func applicationDidBecomeActive(_ notification: Notification) {
		//if application?.orderedDocuments?.count < 1 { showApplication(self) }
	}

	public func application(_ application: NSApplication, willPresentError error: Error) -> Error {
		// not in iOS: http://stackoverflow.com/a/13083203/3878712
		// NOPE, this can cause loops warn("`\(error.localizedDescription)` [\(error.domain)] [\(error.code)] `\(error.localizedFailureReason ?? String())` : \(error.userInfo)")
		switch error {
			case let error as URLError:
				if let url = error.failingURL?.absoluteString {
					//error.errorUserInfo[NSLocalizedDescriptionKey] = "\(error.localizedDescription)\n\n\(url)" // add failed url to error message
					return error
				}
				fallthrough
			default:
				return error
		}
	}

	public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
		warn()
		windowController?.close() // kill the window if it still exists
		windowController?.window = nil
		windowController = nil // deinit the wc
		window = nil // deinit the window
		browserController.unextend(AppScriptRuntime.shared.exports)
		AppScriptRuntime.shared.resetStates()
		//browserController.close() // kill any zombie tabs -- causes lock-loop?
		// unfocus app?
#if arch(x86_64) || arch(i386)
		if prompter != nil { return .terminateLater } // wait for user to EOF the Prompt
#endif
		return .terminateNow
	}

	public func applicationWillTerminate(_ notification: Notification) {
		warn()
		UserDefaults.standard.synchronize()
#if arch(x86_64) || arch(i386)
		if let prompter = prompter {
			prompter.wait()	// let prompter deinit and cleanup the TTY
		}
#endif
	}

	public func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { return true }

	// handles drag-to-dock-badge, /usr/bin/open and argv[1:] requests specifiying urls & local pathnames
	// https://github.com/WebKit/webkit/commit/3e028543b95387e8ac73e9947a5cef4dd1ac90f2
	public func application(_ theApplication: NSApplication, openFile filename: String) -> Bool {
		warn(filename)
		if let ftype = try? NSWorkspace.shared.type(ofFile: filename) {
			warn(ftype)
			switch ftype {
				// check file:s for spaces and urlescape them
				//case "public.data":
				//case "public.folder":
				case "com.apple.web-internet-location": //.webloc http://stackoverflow.com/questions/146575/crafting-webloc-file
					if let webloc = NSDictionary(contentsOfFile: filename), let urlstr = webloc.value(forKey: "URL") as? String {
						if AppScriptRuntime.shared.jsdelegate.tryFunc("handleDragAndDroppedURLs", NSArray(array: [urlstr])) {
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

		// handles public.url
		if let url = validateURL(filename) {
			warn("opening public.url: \(url)")
			browserController.tabSelected = MPWebView(url: url)
			return true
		}
		warn("not opening: \(filename)")
		return false // will generate modal error popup
	}
}

extension MacPinAppDelegateOSX: NSUserNotificationCenterDelegate {
	//didDeliverNotification
	public func userNotificationCenter(_ center: NSUserNotificationCenter, didActivate notification: NSUserNotification) {
		warn("user clicked notification")

		//if ! (AppScriptRuntime.shared.emit(.handleClickedNotification,
		//....) ?? []).flatMap().isEmpty
		if AppScriptRuntime.shared.jsdelegate.tryFunc("handleClickedNotification",
			(notification.title ?? "") as NSString, (notification.subtitle ?? "") as NSString,
			(notification.informativeText ?? "") as NSString, (notification.identifier ?? "") as NSString) {
				warn("handleClickedNotification fired!")
				center.removeDeliveredNotification(notification)
		}
	}

	// always display notifcations, even if app is active in foreground (for alert sounds)
	public func userNotificationCenter(_ center: NSUserNotificationCenter, shouldPresent notification: NSUserNotification) -> Bool { return true }
}

extension MacPinAppDelegateOSX: NSWindowRestoration {
	// https://developer.apple.com/library/mac/documentation/General/Conceptual/MOSXAppProgrammingGuide/CoreAppDesign/CoreAppDesign.html#//apple_ref/doc/uid/TP40010543-CH3-SW35
	public static func restoreWindow(withIdentifier identifier: NSUserInterfaceItemIdentifier, state: NSCoder, completionHandler: @escaping (NSWindow?, Error?) -> Void) {
		if let app = MacPinApp.shared.appDelegate, let window = app.window, identifier.rawValue == "browser" {
			completionHandler(window, nil)
			//WKWebView._restoreFromSessionStateData ...
		} else {
			completionHandler(nil, nil)
		}
	}
}
