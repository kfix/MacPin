import UIKit
import ObjectiveC
import WebKitPrivates
import Darwin

@UIApplicationMain // doesn't work without NIBs, using main.swift instead
class AppDelegate: NSObject {
	var window: UIWindow? // { return UIWindow(frame: UIScreen.mainScreen().bounds) } 

	var browserController = MobileBrowserViewController()

	override init() {
		super.init()
	}
}

extension AppDelegate: UIApplicationDelegate { //UIResponder
	func application(application: UIApplication, openURL url: NSURL, sourceApplication: String?, annotation: AnyObject?) -> Bool {
		warn("`\(url)` -> JSRuntime.jsdelegate.launchURL()")
		JSRuntime.context.objectForKeyedSubscript("$").setObject(url.description, forKeyedSubscript: "launchedWithURL")
		JSRuntime.jsdelegate.tryFunc("launchURL", url.description)
		return true //FIXME
	}

	func application(application: UIApplication, willFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool { // state not restored, UI not presented
		application.registerUserNotificationSettings(UIUserNotificationSettings(forTypes: UIUserNotificationType.Sound | UIUserNotificationType.Alert | UIUserNotificationType.Badge, categories: nil))

		window?.rootViewController = browserController
		window?.makeKeyAndVisible() // presentation is deferred until after didFinishLaunching

		// airplay to an external screen on a mac or appletv
		//	https://developer.apple.com/library/ios/documentation/WindowsViews/Conceptual/WindowAndScreenGuide/UsingExternalDisplay/UsingExternalDisplay.html#//apple_ref/doc/uid/TP40012555-CH3-SW1
		return true //FIXME
	}

	func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject : AnyObject]?) -> Bool { //state restored, but UI not presented yet
		// launchOptions: http://nshipster.com/launch-options/
		JSRuntime.context.objectForKeyedSubscript("$").setObject(browserController, forKeyedSubscript: "browser")
		JSRuntime.loadSiteApp() // load app.js, if present

		if let default_html = NSBundle.mainBundle().URLForResource("default", withExtension: "html") {
			warn("loading initial page from app bundle: \(default_html)")
			browserController.addChildViewController(WebViewControllerIOS(webview: MPWebView(url: default_html))) 
		}

		if browserController.tabs.count < 1 { browserController.newTabPrompt() } //don't allow a tabless state

		for arg in Process.arguments {
			switch (arg) {
				case "-i":
					if isatty(1) == 1 { JSRuntime.REPL() } //open a JS console on the terminal, if present
				case "-iT":
					warn()
					if isatty(1) == 1 { browserController.tabSelected?.REPL() } //open a JS console for the first tab WebView on the terminal, if present
					// ooh, pretty: https://github.com/Naituw/WBWebViewConsole
					// https://github.com/Naituw/WBWebViewConsole/blob/master/WBWebViewConsole/Views/WBWebViewConsoleInputView.m
				default:
					if arg != Process.arguments[0] && !arg.hasPrefix("-psn_0_") { // Process Serial Number from LaunchServices open()
						warn("unrecognized argv[]: `\(arg)`")
					}
			}
		}

		UIApplication.sharedApplication().statusBarStyle = .LightContent
		UINavigationBar.appearance().barTintColor = UIColor(red: 45/255, green: 182/255, blue: 227/255, alpha: 1.0)

		return true //FIXME
    }

	func applicationDidBecomeActive(application: UIApplication) {
		//if application?.orderedDocuments?.count < 1 { showApplication(self) }
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

		if JSRuntime.jsdelegate.tryFunc("handleClickedNotification", notification.alertTitle ?? "", notification.alertAction ?? "", notification.alertBody ?? "") {
			warn("handleClickedNotification fired!")
		}
	}
	//alerts do not display when app is already frontmost, cannot override this like on OSX
}
