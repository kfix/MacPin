import UIKit
import ObjectiveC
import WebKitPrivates
import Darwin

@UIApplicationMain
class AppDelegateIOS: AppDelegate {
	var window: UIWindow? = nil // don't assign up here, first value is persistently used for rotation size calculations!
	var browserController = MobileBrowserViewController() //frame: UIScreen.mainScreen().applicationFrame)
	override init() { super.init() }
}

extension AppDelegateIOS: UIApplicationDelegate { //UIResponder
	func application(application: UIApplication, openURL url: NSURL, sourceApplication: String?, annotation: AnyObject) -> Bool {
		warn("`\(url)` -> AppScriptRuntime.shared.jsdelegate.launchURL()")
		AppScriptRuntime.shared.context.objectForKeyedSubscript("$").setObject(url.description, forKeyedSubscript: "launchedWithURL")
		AppScriptRuntime.shared.jsdelegate.tryFunc("launchURL", url.description)
		return true //FIXME
	}

	func application(application: UIApplication, willFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool { // state not restored, UI not presented
		application.registerUserNotificationSettings(UIUserNotificationSettings(forTypes: [UIUserNotificationType.Sound, UIUserNotificationType.Alert, UIUserNotificationType.Badge], categories: nil))

		return true //FIXME
	}

	func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool { //state restored, but UI not presented yet
		// launchOptions: http://nshipster.com/launch-options/

		window = UIWindow(frame: UIScreen.mainScreen().bounds) // total pixels w/ rotation
		UIApplication.sharedApplication().statusBarStyle = .LightContent
		window?.backgroundColor = UIColor.whiteColor() // visible behind status bar area when unobscured by page content
		window?.rootViewController = browserController //adds the browserView to window.subviews
		window?.makeKeyAndVisible() // presentation is deferred until after didFinishLaunching

		// airplay to an external screen on a mac or appletv
		//	https://developer.apple.com/library/ios/documentation/WindowsViews/Conceptual/WindowAndScreenGuide/UsingExternalDisplay/UsingExternalDisplay.html#//apple_ref/doc/uid/TP40012555-CH3-SW1

		for (idx, arg) in Process.arguments.enumerate() {
			switch (arg) {
				case "-i":
					if isatty(1) == 1 { AppScriptRuntime.shared.REPL() } //open a JS console on the terminal, if present
				case "-t":
					if isatty(1) == 1 {
						if idx + 1 >= Process.arguments.count { // no arg after this one
							browserController.tabs.first?.REPL() //open a JS console for the first tab WebView on the terminal, if present
							break
						}
						if let tabnum = Int(Process.arguments[idx + 1]) where browserController.tabs.count >= tabnum { // next argv should be tab number
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

		return true //FIXME
  }

	func applicationDidBecomeActive(application: UIApplication) { // UI presented
		//if application?.orderedDocuments?.count < 1 { showApplication(self) }

		browserController.view.frame = UIScreen.mainScreen().bounds

		if !AppScriptRuntime.shared.context.objectForKeyedSubscript("$").objectForKeyedSubscript("browser").isObject { //first run, not an app restore
			AppScriptRuntime.shared.context.objectForKeyedSubscript("$").setObject(browserController, forKeyedSubscript: "browser")
			AppScriptRuntime.shared.loadSiteApp() // load app.js, if present
			AppScriptRuntime.shared.jsdelegate.tryFunc("AppFinishedLaunching")
		} else {
			AppScriptRuntime.shared.jsdelegate.tryFunc("AppRestored")
		}

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

	func applicationWillTerminate(application: UIApplication) { NSUserDefaults.standardUserDefaults().synchronize() }

	func application(application: UIApplication, shouldSaveApplicationState coder: NSCoder) -> Bool { return false }
	func application(application: UIApplication, shouldRestoreApplicationState coder: NSCoder) -> Bool { return false }

	//func applicationDidReceiveMemoryWarning(application: UIApplication) { close all hung tabs! }

	func application(application: UIApplication, didReceiveLocalNotification notification: UILocalNotification) {
		warn("user clicked notification")

		if AppScriptRuntime.shared.jsdelegate.tryFunc("handleClickedNotification", notification.alertTitle ?? "", notification.alertAction ?? "", notification.alertBody ?? "") {
			warn("handleClickedNotification fired!")
		}
	}
	//alerts do not display when app is already frontmost, cannot override this like on OSX
}
