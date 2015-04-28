/// MacPin AppScript Runtime
///
/// Creates a singleton-instance of JavaScriptCore for intepreting bundled javascripts to control a MacPin app

// somehow get a JXA bridge working?
//  https://developer.apple.com/library/mac/releasenotes/InterapplicationCommunication/RN-JavaScriptForAutomation/index.html

let JSRuntime = AppScriptRuntime() //singleton

#if os(OSX)
import AppKit
#elseif os(iOS)
import UIKit
#endif

import Foundation
import JavaScriptCore // https://github.com/WebKit/webkit/tree/master/Source/JavaScriptCore/API

#if arch(x86_64) || arch(i386)
import Prompt // https://github.com/neilpa/swift-libedit
#endif

public extension JSValue {
	func tryFunc (method: String, _ args: AnyObject...) -> Bool {
		if self.hasProperty(method) {
			warn("jsruntime.delegate.\(method)(\(args))")
			var ret = self.invokeMethod(method, withArguments: args)
			if let bool = ret.toObject() as? Bool { return bool }
			// exec passed closure here?
		}
		return false
	}
}

@objc protocol AppScriptExports : JSExport { // '$.app' 
	//func warn(msg: String)
	var appPath: String { get }
	var resourcePath: String { get }
	var arguments: [AnyObject] { get }
	var environment: [NSObject:AnyObject] { get }
	var name: String { get }
	var bundleID: String { get }
	var hostname: String { get }
	var architecture: String { get }
	var arches: [AnyObject]? { get }
	var platform: String { get }
	var platformVersion: String { get }
	func registerURLScheme(scheme: String)
	func changeAppIcon(iconpath: String)
	func postNotification(title: String, _ subtitle: String?, _ msg: String)
	func openURL(urlstr: String, _ app: String?)
	func sleep(secs: Double)
	func doesAppExist(appstr: String) -> Bool
	//func evalAppleScript(code: String) //expose NSAppleScript?
	func loadAppScript(urlstr: String) -> JSValue? 
}

class AppScriptRuntime: NSObject, AppScriptExports  {
	var context = JSContext(virtualMachine: JSVirtualMachine())
	var delegate: JSValue
	
	var arguments: [AnyObject] { get { return NSProcessInfo.processInfo().arguments } }
	var environment: [NSObject:AnyObject] { get { return NSProcessInfo.processInfo().environment } }
	var appPath: String { get { return ( NSBundle.mainBundle().bundlePath ?? String() ) } }
	var resourcePath: String { get { return ( NSBundle.mainBundle().resourcePath ?? String() ) } }
	var hostname: String { get { return NSProcessInfo.processInfo().hostName } }
	var bundleID: String { get { return ( NSBundle.mainBundle().bundleIdentifier ?? String() ) } }

#if os(OSX)
	var name: String { get { return ( NSRunningApplication.currentApplication().localizedName ?? String() ) } }
	let platform = "OSX"
#elseif os(iOS)
	let platform = "iOS"
#endif
	
	// http://nshipster.com/swift-system-version-checking/
	var platformVersion: String { get { return NSProcessInfo.processInfo().operatingSystemVersionString } }

	var arches: [AnyObject]? { get { return NSBundle.mainBundle().executableArchitectures } } 
#if arch(i386)
	let architecture = "i386"
#elseif arch(x86_64)
	let architecture = "x86_64"
#elseif arch(arm)
	let architecture = "arm"
#elseif arch(arm64)
	let architecture = "arm64"
#endif

    override init() {
		context.name = "MacPin App JS"
		context.evaluateScript("$ = {};") //default global for our exports
		delegate = context.evaluateScript("{};")! //default property-less delegate obj
		context.objectForKeyedSubscript("$").setObject("", forKeyedSubscript: "launchedWithURL")
		context.objectForKeyedSubscript("$").setObject(WebViewController.self, forKeyedSubscript: "WebView") // `new $.WebView({})` WebView -> [object MacPin.WebViewControllerContructor]
		context.objectForKeyedSubscript("$").setObject(GlobalUserScripts, forKeyedSubscript: "globalUserScripts")

		// set console.log to NSBlock that will call warn()
		let logger: @objc_block String -> Void = { msg in warn(msg) }
		let dumper: @objc_block AnyObject -> Void = { obj in dump(obj) }
		context.evaluateScript("console = {};") // console global
		context.objectForKeyedSubscript("console").setObject(unsafeBitCast(logger, AnyObject.self), forKeyedSubscript: "log")
		context.objectForKeyedSubscript("console").setObject(unsafeBitCast(logger, AnyObject.self), forKeyedSubscript: "dump")

		super.init()
	}
	
	override var description: String { return "<\(reflect(self).summary)> [\(appPath)] `\(context.name)`" }
	
	func sleep(secs: Double) {
		let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(Double(NSEC_PER_SEC) * secs))
		dispatch_after(delayTime, dispatch_get_main_queue()){}
		//NSThread.sleepForTimeInterval(secs)
	}

/*
	func delay(delay:Double, closure:()->()) {
		dispatch_after(
			dispatch_time(
				DISPATCH_TIME_NOW,
				Int64(delay * Double(NSEC_PER_SEC))
			),
 		dispatch_get_main_queue(), closure)
	}
*/

	func loadSiteApp() {
		let app = (NSBundle.mainBundle().objectForInfoDictionaryKey("MacPin-AppScriptName") as? String) ?? "app"

		context.objectForKeyedSubscript("$").setObject(self, forKeyedSubscript: "osx") //FIXME: deprecate
		context.objectForKeyedSubscript("$").setObject(self, forKeyedSubscript: "app") //better nomenclature

		if let app_js = NSBundle.mainBundle().URLForResource(app, withExtension: "js") {

			// make thrown exceptions popup an nserror displaying the file name and error type
			// FIXME: doesn't print actual text of throwing code
			// Safari Web Inspector <-> JSContext seems to get an actual source-map
			context.exceptionHandler = { context, exception in
				let error = NSError(domain: "MacPin", code: 4, userInfo: [
					NSURLErrorKey: context.name,
					NSLocalizedDescriptionKey: "\(context.name) `\(exception)`" 
				])
				displayError(error) // would be nicer to pop up an inspector pane or tab to interactively debug this
				context.exception = exception //default in JSContext.mm
				return // gets returned to evaluateScript()?
			}

			if let jsval = loadAppScript(app_js.description) {
				if jsval.isObject() {
					warn("\(app_js) loaded as JSRuntime.delegate")
					delegate = jsval
					delegate.tryFunc("AppFinishedLaunching")
				}
			}
		}
	}
	
	func loadAppScript(urlstr: String) -> JSValue? {
		if let script_url = NSURL(string: urlstr) { // FIXME: script code could be loaded from anywhere, exploitable?
			let script = NSString(contentsOfURL: script_url, encoding: NSUTF8StringEncoding, error: nil)!
			warn("\(script_url) parsed")
			// if JSCheckScriptSyntax(ctx: context as JSContext!,
			// 	 script: JSStringCreateWithCFString(string: script as CFString).takeUnretainedValue() as JSString!,
			// 	 sourceURL: JSStringCreateWithCFString(string: script_url.absoluteString as CFString).takeUnretainedValue() as JSString!,
			// 	 startingLineNumber: Int32(0),
			// 	 exception: UnsafeMutablePointer<Unmanaged<JSValue>?>(nil)
			// ) { 
				context.name = "\(context.name) <\(urlstr)>"
				// FIXME: assumes last script loaded is the source file, not always true

			 	return context.evaluateScript(script as String, withSourceURL: script_url) // returns JSValue!
			// } else { /* alert panel */ } // or pop open the script source-code in a new tab and highlight the offender
		}
		return nil
	}

	func doesAppExist(appstr: String) -> Bool {
#if os(OSX)
		if LSCopyApplicationURLsForBundleIdentifier(appstr as CFString, nil) != nil { return true }
#elseif os(iOS)
		if let appurl = NSURL(string: "\(appstr)://") { // installed bundleids are usually (automatically?) usable as URL schemes in iOS
			if UIApplication.sharedApplication().canOpenURL(appurl) { return true }
		}
#endif
		return false
	}

	func openURL(urlstr: String, _ appid: String? = nil) {
		if let url = NSURL(string: urlstr) {
#if os(OSX)
			NSWorkspace.sharedWorkspace().openURLs([url], withAppBundleIdentifier: appid, options: .Default, additionalEventParamDescriptor: nil, launchIdentifiers: nil)
			//options: .Default .NewInstance .AndHideOthers
			// FIXME: need to force focus on appid too, already launched apps may not pop-up#elseif os (iOS)
#elseif os(iOS)
			// iOS doesn't allow directly launching apps, must use custom-scheme URLs and X-Callback-URL
			//  unless jailbroken http://stackoverflow.com/a/6821516/3878712
			if let urlp = NSURLComponents(URL: url, resolvingAgainstBaseURL: true) {
				if let appid = appid { urlp.scheme = appid } // assume bundle ID is a working scheme
				UIApplication.sharedApplication().openURL(urlp.URL!)
			}
#endif
		}
	}

	// func newTrayTab
	//  support opening a page as a NSStatusItem icon by the clock
	// https://github.com/phranck/CCNStatusItem

	func changeAppIcon(iconpath: String) {
#if os(OSX)
		/*
		switch (iconpath) {
			case let icon_url = NSBundle.mainBundle().URLForResource(iconpath, withExtension: "png"): fallthrough // path was to a local resource
			case let icon_url = NSURL(string: iconpath): // path was a url, local or remote
				NSApplication.sharedApplication().applicationIconImage = NSImage(contentsOfUrl: icon_url) 
			default:
				warn("invalid icon: \(iconpath)")
		}
		*/

		if let icon_url = NSBundle.mainBundle().URLForResource(iconpath, withExtension: "png") ?? NSURL(string: iconpath) {
			// path was a url, local or remote
			NSApplication.sharedApplication().applicationIconImage = NSImage(contentsOfURL: icon_url) 
		} else {
			warn("invalid icon: \(iconpath)")
		}
#endif
	}

	func registerURLScheme(scheme: String) {
		// there *could* be an API for this in WebKit, like Chrome & FF: https://bugs.webkit.org/show_bug.cgi?id=92749
		// https://developer.mozilla.org/en-US/docs/Web-based_protocol_handlers
#if os(OSX)
		LSSetDefaultHandlerForURLScheme(scheme, NSBundle.mainBundle().bundleIdentifier)
		warn("registered URL handler in OSX: \(scheme)")
		//NSApp.registerServicesMenuSendTypes(sendTypes:[.kUTTypeFileURL], returnTypes:nil)
		// http://stackoverflow.com/questions/20461351/how-do-i-enable-services-which-operate-on-selected-files-and-folders
#else
		// use Info.plist: CFBundleURLName = bundleid & CFBundleURLSchemes = [blah1, blah2]
		// on jailed iOS devices, there is no way to do this at runtime :-(
#endif
	}

	func postNotification(title: String, _ subtitle: String?, _ msg: String) {
		// there is an API for this in WebKit: http://playground.html5rocks.com/#simple_notifications
		//  https://developer.apple.com/library/iad/documentation/AppleApplications/Conceptual/SafariJSProgTopics/Articles/SendingNotifications.html
		//  but all my my WKWebView's report 2 (access denied) and won't display auth prompts
		//  https://github.com/WebKit/webkit/search?q=webnotificationprovider  no api delegates in WK2 for notifications or geoloc yet
		//  http://stackoverflow.com/questions/14237086/how-to-handle-html5-web-notifications-with-a-cocoa-webview
#if os(OSX)
		let note = NSUserNotification()
		note.title = title
		note.subtitle = subtitle ?? "" //empty strings wont be displayed
		note.informativeText = msg
		//note.contentImage = ?bubble pic?

		//note.hasReplyButton = true
		//note.hasActionButton = true
		//note.responsePlaceholder = "say something stupid"

		note.soundName = NSUserNotificationDefaultSoundName // something exotic?
		NSUserNotificationCenter.defaultUserNotificationCenter().deliverNotification(note)
		// these can be listened for by all: http://pagesofinterest.net/blog/2012/09/observing-all-nsnotifications-within-an-nsapp/
#elseif os(iOS)
		let note = UILocalNotification()
		note.alertTitle = title
		note.alertAction = "Open"
		note.alertBody = "\(subtitle ?? String()) \(msg)"
		note.fireDate = NSDate()
		UIApplication.sharedApplication().scheduleLocalNotification(note)
#endif
		//map passed-in blocks to notification responses?
		// http://thecodeninja.tumblr.com/post/90742435155/notifications-in-ios-8-part-2-using-swift-what
	}

	func REPL() {
		termiosREPL({ [unowned self] (line: String) -> Void in
			// delegate.tryFunc("termiosREPL", [line])
			println(self.context.evaluateScript(line))
		})
	}
}
