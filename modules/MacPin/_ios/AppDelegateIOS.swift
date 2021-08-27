import UIKit
import ObjectiveC
import WebKitPrivates
import Darwin

//UIApplicationMain
public class MacPinAppDelegateIOS: NSObject, MacPinAppDelegate {
	var browserController: BrowserViewController = MobileBrowserViewController() //frame: UIScreen.mainScreen().applicationFrame)
	let window = UIWindow(frame: UIScreen.main.bounds) // total pixels w/ rotation

	var prompter: Prompter? = nil
	func application(_ application: UIApplication, openURL url: URL, sourceApplication: String?, annotation: AnyObject) -> Bool {
		warn("`\(url)` -> AppScriptRuntime.shared.jsdelegate.launchURL()")
		AppScriptRuntime.shared.emit(.launchURL, url.absoluteString ?? "")
		return true //FIXME
	}

	public func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool { // state not restored, UI not presented
		application.registerUserNotificationSettings(UIUserNotificationSettings(types: [UIUserNotificationType.sound, UIUserNotificationType.alert, UIUserNotificationType.badge], categories: nil))

		if !AppScriptRuntime.shared.loadMainScript() { // load main.js, if present
			self.browserController.extend(AppScriptRuntime.shared.exports) // expose our default browser instance early on, because legacy
			BrowserController.self.exportSelf(AppScriptRuntime.shared.context.globalObject) // & the type for self-setup
			AppScriptRuntime.shared.exports.setObject(MPWebView.self, forKeyedSubscript: "WebView" as NSString) // because legacy
			AppScriptRuntime.shared.exports.setObject("", forKeyedSubscript: "launchedWithURL" as NSString)
			AppScriptRuntime.shared.loadSiteApp() // load app.js, if present
			AppScriptRuntime.shared.emit(.AppFinishedLaunching)
		}

		AppScriptRuntime.shared.emit(.AppWillFinishLaunching, self) // allow JS to replace our browserController
		AppScriptRuntime.shared.context.evaluateScript("eval = null;") // security thru obscurity
		return true
	}

	public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool { //state restored, but UI not presented yet
		// launchOptions: http://nshipster.com/launch-options/
		UIApplication.shared.statusBarStyle = .lightContent
		window.backgroundColor = UIColor.white // visible behind status bar area when unobscured by page content
		window.rootViewController = browserController as! UIViewController //adds the browserView to window.subviews
		window.makeKeyAndVisible() // presentation is deferred until after didFinishLaunching
		AppScriptRuntime.shared.emit(.AppFinishedLaunching, "FIXME: provide real launch URLs")

		// airplay to an external screen on a mac or appletv
		//	https://developer.apple.com/library/ios/documentation/WindowsViews/Conceptual/WindowAndScreenGuide/UsingExternalDisplay/UsingExternalDisplay.html#//apple_ref/doc/uid/TP40012555-CH3-SW1

		warn(CommandLine.arguments.description)
		for (idx, arg) in CommandLine.arguments.enumerated() {
			switch (arg) {
				case "-i":
					//open a JS console on the terminal, if present
					if AppScriptRuntime.shared.eventCallbacks[.printToREPL, default: []].isEmpty {
						if let repl_js = Bundle.main.url(forResource: "app_repl", withExtension: "js") {
							warn("injecting TTY REPL")
							AppScriptRuntime.shared.eventCallbacks[.printToREPL] = [
								AppScriptRuntime.shared.loadCommonJSScript(repl_js.absoluteString).objectForKeyedSubscript("repl")
							]
						}
					}
					prompter = AppScriptRuntime.shared.REPL()

				case "-t":
					if idx + 1 >= CommandLine.arguments.count { // no arg after this one
						prompter = browserController.tabs.first?.REPL() //open a JS console for the first tab WebView on the terminal, if present
						break
					}

					if let tabnum = Int(CommandLine.arguments[idx + 1]), browserController.tabs.count >= tabnum { // next argv should be tab number
						prompter = browserController.tabs[tabnum].REPL() // open a JS Console on the requested tab number
						// FIXME skip one more arg
					} else {
						prompter = browserController.tabs.first?.REPL() //open a JS console for the first tab WebView on the terminal, if present
					}

				case let _ where (arg.hasPrefix("http:") || arg.hasPrefix("https:") || arg.hasPrefix("about:") || arg.hasPrefix("file:")):
					warn("\(arg)")
					//application(NSApp, openFile: arg) // LS will openFile AND argv.append() fully qualified URLs
				default:
					if arg != CommandLine.arguments[0] && !arg.hasPrefix("-psn_0_") { // Process Serial Number from LaunchServices open()
						warn("unrecognized argv[]: `\(arg)`")
					}
			}
		}
		prompter?.start()
		return true //FIXME
  }

	public func applicationDidBecomeActive(_ application: UIApplication) { // UI presented
		//if application?.orderedDocuments?.count < 1 { showApplication(self) }

		browserController.view.frame = UIScreen.main.bounds
		if browserController.tabs.count < 1 { browserController.newTabPrompt() } //don't allow a tabless state
	}

	// need https://github.com/kemenaran/ios-presentError
	// w/ http://nshipster.com/uialertcontroller/
	/*
	func application(application: NSApplication, willPresentError error: NSError) -> NSError {
		//warn("`\(error.localizedDescription)` [\(error.domain)] [\(error.code)] `\(error.localizedFailureReason ?? String())` : \(error.userInfo)")
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
	*/

	public func applicationWillTerminate(_ application: UIApplication) {
		AppScriptRuntime.shared.emit(.AppShouldTerminate, self) // allow JS to clean up its refs
	    UserDefaults.standard.synchronize()
	}

	public func application(_ application: UIApplication, shouldSaveApplicationState coder: NSCoder) -> Bool { return false }
	public func application(_ application: UIApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool { return false }

	//func applicationDidReceiveMemoryWarning(application: UIApplication) { close all hung tabs! }

	public func application(_ application: UIApplication, didReceive notification: UILocalNotification) {
		warn("user clicked notification")

		// FIXME should be passing a [:]
		if AppScriptRuntime.shared.anyHandled(.handleClickedNotification, [
			"title":	(notification.alertTitle ?? "") as NSString,
			"subtitle":	(notification.alertAction ?? "") as NSString,
			"body":		(notification.alertBody ?? "") as NSString,
		]) {
				warn("handleClickedNotification fired!")
		}

	}
	//alerts do not display when app is already frontmost, cannot override this like on OSX
}
