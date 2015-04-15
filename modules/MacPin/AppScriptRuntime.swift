// somehow get a JXA bridge working?
//  https://developer.apple.com/library/mac/releasenotes/InterapplicationCommunication/RN-JavaScriptForAutomation/index.html

let JSRuntime = AppScriptRuntime() //singleton

import Cocoa
import JavaScriptCore // https://github.com/WebKit/webkit/tree/master/Source/JavaScriptCore/API
import Prompt // https://github.com/neilpa/swift-libedit

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

@objc protocol OSXScriptExports : JSExport { // '$osx' in app.js
	//func warn(msg: String)
	var resourcePath: String { get }
	func registerURLScheme(scheme: String)
	func postNotification(title: String, _ subtitle: String?, _ msg: String)
	func openURL(urlstr: String, _ app: String?)
	func sleep(secs: Double)
	func doesAppExist(appstr: String) -> Bool
	//func evalAppleScript(code: String) //expose NSAppleScript?
	func loadAppScript(basename: String) -> JSValue? 
}

public class AppScriptRuntime: NSObject, OSXScriptExports  {
	var context = JSContext(virtualMachine: JSVirtualMachine())
	var delegate: JSValue
	var resourcePath: String { get { return ( NSBundle.mainBundle().resourcePath ?? String() ) } }

    override init() {
		context.evaluateScript("$ = {};") //default global for our exports
		delegate = context.evaluateScript("{};")! //default property-less delegate obj
		context.setObject("", forKeyedSubscript: "$launchedWithURL")
		context.objectForKeyedSubscript("$").setObject("", forKeyedSubscript: "launchedWithURL")
		context.objectForKeyedSubscript("$").setObject(WebViewController.self, forKeyedSubscript: "WebView") // $.browser.tabs[WebView] & $.WebView.createWithObj()
		context.setObject(WebViewController.self, forKeyedSubscript: "WebView") // [object MacPin.WebViewControllerContructor] `new WebView()`
		context.objectForKeyedSubscript("$").setObject(GlobalUserScripts, forKeyedSubscript: "globalUserScripts")
		super.init()
	}

	//func log(msg: String) { }
	
	func doesAppExist(appstr: String) -> Bool {
		if LSCopyApplicationURLsForBundleIdentifier(appstr as CFString, nil) != nil { return true }
		return false
	}

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
		if let app_js = NSBundle.mainBundle().URLForResource(app, withExtension: "js") {
			context.exceptionHandler = { context, exception in
				let error = NSError(domain: "MacPin", code: 4, userInfo: [
					NSURLErrorKey: app_js,
					NSLocalizedDescriptionKey: "<\(app_js)> `\(exception)`" // FIXME need more script context, or a source-map to the script file
				])
				if let window = NSApplication.sharedApplication().mainWindow {
					window.presentError(error, modalForWindow: window, delegate: nil, didPresentSelector: nil, contextInfo: nil)
				} else {
					NSApplication.sharedApplication().presentError(error)
					// would be nicer to pop up an inspector tab to gracefully present this
				}
				//context.$browser.conlog(.....)
				context.exception = exception //default in JSContext.mm
				return // gets returned to evaluateScript()?
			} 
			context.setObject(self, forKeyedSubscript: "$osx")
			context.objectForKeyedSubscript("$").setObject(self, forKeyedSubscript: "osx")
			context.objectForKeyedSubscript("$").setObject(self, forKeyedSubscript: "app") //better nomenclature
			let logger: @objc_block String -> Void = { msg in warn(msg) }
			context.evaluateScript("console = {};") // console global
			context.objectForKeyedSubscript("console").setObject(unsafeBitCast(logger, AnyObject.self), forKeyedSubscript: "log")
			context.setObject(unsafeBitCast(logger, AnyObject.self), forKeyedSubscript: "warn")
			// ^ pass in block that will also copy to $browser.conlog()
			if let jsval = loadAppScript(app) {
				if jsval.isObject() {
					warn("\(app_js) loaded as JSRuntime.delegate")
					delegate = jsval
					delegate.tryFunc("AppFinishedLaunching")
				}
			}
		}
	}
	
	func loadAppScript(basename: String) -> JSValue? {
		if let script_url = NSBundle.mainBundle().URLForResource(basename, withExtension: "js") {
			let script = NSString(contentsOfURL: script_url, encoding: NSUTF8StringEncoding, error: nil)!
			warn("\(script_url) parsed")
			// if JSCheckScriptSyntax(ctx: context as JSContext!,
			// 	 script: JSStringCreateWithCFString(string: script as CFString).takeUnretainedValue() as JSString!,
			// 	 sourceURL: JSStringCreateWithCFString(string: script_url.absoluteString as CFString).takeUnretainedValue() as JSString!,
			// 	 startingLineNumber: Int32(0),
			// 	 exception: UnsafeMutablePointer<Unmanaged<JSValue>?>(nil)
			// ) { 
			 	return context.evaluateScript(script as String, withSourceURL: script_url) // returns JSValue!
			// } else { /* alert panel */ } // or pop open the script source-code in a new tab and highlight the offender
		}
		return nil
	}

	func openURL(urlstr: String, _ appid: String? = nil) {
		if let url = NSURL(string: urlstr) {
			NSWorkspace.sharedWorkspace().openURLs([url], withAppBundleIdentifier: appid, options: .Default, additionalEventParamDescriptor: nil, launchIdentifiers: nil)
			//options: .Default .NewInstance .AndHideOthers
			// FIXME: need to force focus on appid too, already launched apps may not pop-up
		}
	}

	// func newTrayTab
	//  support opening a page as a NSStatusItem icon by the clock
	// https://github.com/phranck/CCNStatusItem

	func registerURLScheme(scheme: String) {
		// there *could* be an API for this in WebKit, like Chrome & FF: https://bugs.webkit.org/show_bug.cgi?id=92749
		// https://developer.mozilla.org/en-US/docs/Web-based_protocol_handlers
		LSSetDefaultHandlerForURLScheme(scheme, NSBundle.mainBundle().bundleIdentifier)
		warn("registered URL handler in OSX: \(scheme)")

		//NSApp.registerServicesMenuSendTypes(sendTypes:[.kUTTypeFileURL], returnTypes:nil)
		// http://stackoverflow.com/questions/20461351/how-do-i-enable-services-which-operate-on-selected-files-and-folders
	}

	func postNotification(title: String, _ subtitle: String?, _ msg: String) {
		// there is an API for this in WebKit: http://playground.html5rocks.com/#simple_notifications
		//  https://developer.apple.com/library/iad/documentation/AppleApplications/Conceptual/SafariJSProgTopics/Articles/SendingNotifications.html
		//  but all my my WKWebView's report 2 (access denied) and won't display auth prompts
		//  https://github.com/WebKit/webkit/search?q=webnotificationprovider  no api delegates in WK2 for notifications or geoloc yet
		//  http://stackoverflow.com/questions/14237086/how-to-handle-html5-web-notifications-with-a-cocoa-webview
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
	}

	func termiosREPL() {
		context.exceptionHandler = { context, exception in
			// override the default GUI alerter to display solely on console
			println("Exception: \(exception)")
		}
		// https://github.com/WebKit/webkit/blob/616e7b59aec7a8dbd04eb5405faaf4758117a2cd/Source/JavaScriptCore/jsc.cpp#L1301
		let backgroundQueue = dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0)
		dispatch_async(backgroundQueue, {
			let prompt = Prompt(argv0: Process.unsafeArgv[0])
			// if isatty(0) == 1 && isatty(1) == 1 // should only use Prompt loop if tty is interactive, else just grab it
			while (true) {
			    if let line = prompt.gets() {
					dispatch_async(dispatch_get_main_queue(), { () -> Void in
						println(self.context.evaluateScript(line))
					})
			    } else {
					dispatch_async(dispatch_get_main_queue(), { () -> Void in
						println("Got EOF from stdin, closing REPL!")
					})
					break
				}
			}
			NSApplication.sharedApplication().terminate(JSRuntime)
		})
	}

}
