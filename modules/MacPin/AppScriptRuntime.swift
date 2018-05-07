/// MacPin AppScript Runtime
///
/// Creates a singleton-instance of JavaScriptCore for intepreting bundled javascripts to control a MacPin app

// make a Globals struct with a member for each thing to expose under `$`: browser, app, WebView, etc..
	// ES6 mods enabled for STP v21? https://github.com/WebKit/webkit/commit/fd763768344f941863054d03968d78dd388b8d15

#if os(OSX)
import AppKit
import OSAKit
#elseif os(iOS)
import UIKit
#endif

import Foundation
import JavaScriptCore // https://github.com/WebKit/webkit/tree/master/Source/JavaScriptCore/API
// https://developer.apple.com/library/mac/documentation/General/Reference/APIDiffsMacOSX10_10SeedDiff/modules/JavaScriptCore.html
// https://github.com/WebKit/webkit/blob/master/Source/WebCore/bridge/objc/objc_class.mm

import XMLHTTPRequest // https://github.com/Lukas-Stuehrk/XMLHTTPRequest

#if arch(x86_64) || arch(i386)
import Prompt // https://github.com/neilpa/swift-libedit
#endif

import UserNotificationPrivates
import SSKeychain // https://github.com/soffes/sskeychain

/*

extension NSObject: JSExport {
	static func extend2js(mountObj: JSValue, helpers: String? = nil) { // for constructors
		let classinstance = JSValue(object: self.type, inContext: mountObj.context)
		if let helpers = helpers { classinstance.thisEval(helpers) }
		mountObj.setValue(classinstance, forProperty: className)
	}
}

*/

// FIXME: AppScript needs a HandlerMethods enum instead of just tryFunc("unsafe-string")s everywhere....
extension JSValue {
	func tryFunc (_ method: String, argv: [AnyObject]) -> Bool {
		if self.isObject && self.hasProperty(method) {
			warn("this.\(method) <- \(argv)")
			let ret = self.invokeMethod(method, withArguments: argv)
			if ret == nil { return false }
			if let bool = ret?.toObject() as? Bool { return bool }
		}
		return false
		//FIXME: handle a passed-in closure so we can handle any ret-type instead of only bools ...
	}

	func tryFunc (_ method: String, _ args: AnyObject...) -> Bool { //variadic overload
		return self.tryFunc(method, argv: args)
	}

	func thisEval(_ code: String, sourceURL: String? = nil, exception: JSValue = JSValue()) -> JSValue? {
		let source: JSStringRef?
		if let urlstr = sourceURL { source = JSStringCreateWithCFString(urlstr as CFString) } else { source = nil }
		/*guard*/ let jsval = JSEvaluateScript(
			/*ctx:*/ context.jsGlobalContextRef,
			/*script:*/ JSStringCreateWithCFString(code as CFString),
			/*thisObject:*/ nil,
			/*sourceURL:*/ source ?? nil,
			/*startingLineNumber:*/ Int32(1),
			/*exception:*/ UnsafeMutablePointer(exception.jsValueRef)
		) /*else { return nil }*/
		if jsval != nil { return JSValue(jsValueRef: jsval, in: context) }
		return nil
	}

}

@objc protocol AppScriptExports : JSExport { // '$.app'
	//func warn(msg: String)
	var appPath: String { get }
	var resourcePath: String { get }
	var arguments: [String] { get }
	var environment: [AnyHashable: Any] { get }
	var name: String { get }
	var bundleID: String { get }
	var hostname: String { get }
	var architecture: String { get }
	var arches: [AnyObject]? { get }
	var platform: String { get }
	var platformVersion: String { get }
	func registerURLScheme(_ scheme: String)
	//func registerMIMEType(scheme: String)
	func registerUTI(_ scheme: String)
	func changeAppIcon(_ iconpath: String)
	@objc(postNotification::::) func postNotification(_ title: String?, subtitle: String?, msg: String?, id: String?)
	func postHTML5Notification(_ object: [String:AnyObject])
	func openURL(_ urlstr: String, _ app: String?)
	func sleep(_ secs: Int)
	func doesAppExist(_ appstr: String) -> Bool
	func pathExists(_ path: String) -> Bool
	func loadAppScript(_ urlstr: String) -> JSValue?
	// static func // exported as global JS func
#if DEBUG
	func evalJXA(_ script: String)
	func callJXALibrary(_ library: String, _ call: String, _ args: [AnyObject])
#endif
}

class AppScriptRuntime: NSObject, AppScriptExports  {
	static let shared = AppScriptRuntime(global: "$") // create & export the singleton

	var context = JSContext(virtualMachine: JSVirtualMachine())
	var jsdelegate: JSValue
	let exports: JSValue

	var arguments: [String] { return ProcessInfo.processInfo.arguments }
	var environment: [AnyHashable: Any] { return ProcessInfo.processInfo.environment }
	var appPath: String { return Bundle.main.bundlePath }
	var resourcePath: String { return Bundle.main.resourcePath ?? String() }
	var hostname: String { return ProcessInfo.processInfo.hostName }
	var bundleID: String { return Bundle.main.bundleIdentifier ?? String() }

#if os(OSX)
	var name: String { return NSRunningApplication.current().localizedName ?? String() }
	let platform = "OSX"
#elseif os(iOS)
	var name: String { return Bundle.main.objectForInfoDictionaryKey("CFBundleDisplayName") as? String }
	let platform = "iOS"
#endif

	// http://nshipster.com/swift-system-version-checking/
	var platformVersion: String { return ProcessInfo.processInfo.operatingSystemVersionString }

	var arches: [AnyObject]? { return Bundle.main.executableArchitectures }
#if arch(i386)
	let architecture = "i386"
#elseif arch(x86_64)
	let architecture = "x86_64"
#elseif arch(arm)
	let architecture = "arm"
#elseif arch(arm64)
	let architecture = "arm64"
#endif

	//static func(extend: mountObj) { }

	init(global: String = "$") { // FIXME: ever heard of jQuery?
		context?.name = "AppScriptRuntime"
		jsdelegate = JSValue(newObjectIn: context) //default property-less delegate obj // FIXME: #11 make an App() from ES6 class
#if SAFARIDBG
		// https://github.com/WebKit/webkit/commit/e9f4a5ef360d47b719f7391fe02d28ff1e63fc7://github.com/WebKit/webkit/commit/e9f4a5ef360d47b719f7391fe02d28ff1e63fc7e
		// https://github.com/WebKit/webkit/blob/master/Source/JavaScriptCore/API/JSContextPrivate.h
		context?._remoteInspectionEnabled = true
		//context.logToSystemConsole = true
#else
		context?._remoteInspectionEnabled = false
		//context.logToSystemConsole = false
#endif
		//context._debuggerRunLoop = CFRunLoopRef // FIXME: make a new thread for REPL and Web Inspector console eval()s

		exports = JSValue(newObjectIn: context)
		exports.setObject("", forKeyedSubscript: "launchedWithURL" as NSString) // FIXME: use context.currentArguments ?
		//exports.setObject(GlobalUserScripts, forKeyedSubscript: "globalUserScripts")
		// FIXME: make .extend methods for all MacPin classes that want to export constructors?
		exports.setObject(MPWebView.self, forKeyedSubscript: "WebView" as NSString) // `new $.WebView({})` WebView -> [object MacPin.WebView]
		exports.setObject(SSKeychain.self, forKeyedSubscript: "keychain" as NSString)
		XMLHttpRequest().extend(context) // allows `new XMLHTTPRequest` for doing xHr's
		//FIXME: extend Fetch API instead: https://facebook.github.io/react-native/docs/network.html

		// set console.log to NSBlock that will call warn()
		let logger: @convention(block) (String) -> Void = { msg in warn(msg) }
		let console = JSValue(newObjectIn: context)
		console?.setObject(unsafeBitCast(logger, to: AnyObject.self), forKeyedSubscript: "log" as NSString)
		context?.globalObject.setObject(console, forKeyedSubscript: "console" as NSString) // overrides JSC's built-in

		// FIXME: imitate JSConsole or JSConsoleClient to intercept built-in console.* support instead of shimming blocks
		// https://github.com/WebKit/webkit/commits/master/Source/JavaScriptCore/runtime/ConsoleTypes.h
		// context.globalObject.consoleClient = bluh
		// let console: JSObject = context.globalObject.objectForKeyedSubscript("console")
		// console.invokeMethod("log", withArguments: ["hello console.log"])
		// console.objectForKeyedSubscript("log") == JSFunction

		context?.globalObject.setObject(exports, forKeyedSubscript: global as NSString)
		super.init()
	}

	override var description: String { return "<\(type(of: self))> [\(appPath)] `\(context?.name)`" }

	func sleep(_ secs: Int) {
		let delayTime = DispatchTime.now() + DispatchTimeInterval.seconds(secs)
		DispatchQueue.main.asyncAfter(deadline: delayTime){}
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
		let app = (Bundle.main.object(forInfoDictionaryKey:"MacPin-AppScriptName") as? String) ?? "app"
		context?.objectForKeyedSubscript("$").setObject(self, forKeyedSubscript: "app" as NSString)

		if let app_js = Bundle.main.url(forResource: app, withExtension: "js") {

			// make thrown exceptions popup an nserror displaying the file name and error type
			// FIXME: doesn't print actual text of throwing code
			// Safari Web Inspector <-> JSContext seems to get an actual source-map
			context?.exceptionHandler = { context, exception in
				let line = exception?.forProperty("line").toNumber()
				let column = exception?.forProperty("column").toNumber()
				let stack = exception?.forProperty("stack").toString()
				let message = exception?.forProperty("message").toString()
				let error = NSError(domain: "MacPin", code: 4, userInfo: [
					NSURLErrorKey: context?.name as Any,
					NSLocalizedDescriptionKey: "JS Exception @ \(line):\(column): \(message)\n\(stack)"
					// exception seems to be Error.toString(). I want .message|line|column|stack too
				])
				displayError(error) // FIXME: would be nicer to pop up an inspector pane or tab to interactively debug this
				context?.exception = exception //default in JSContext.mm
				return // gets returned to evaluateScript()?
			}

			if let jsval = loadAppScript(app_js.description) {
				if jsval.isObject { // FIXME: #11 - if JSValueIsInstanceOfConstructor(context.JSGlobalContextRef, jsval.JSValueRef, context.objectForKeyedSubscript("App").JSValueRef, nil)
					warn("\(app_js) loaded as AppScriptRuntime.shared.jsdelegate")
					jsdelegate = jsval // TODO: issue #11 - make `this` the delegate in app scripts, not the return

				}
			}
		}
	}

	// FIXME: ES6 modules? context.evaluateScript("import ...") or "System.load()";
	func loadAppScript(_ urlstr: String) -> JSValue? {
		if let scriptURL = NSURL(string: urlstr), let script = try? NSString(contentsOf: scriptURL as URL, encoding: String.Encoding.utf8.rawValue), let sourceURL = scriptURL.absoluteString {
			// FIXME: script code could be loaded from anywhere, exploitable?
			warn("\(scriptURL): read")

			// JSBase.h
			//func JSCheckScriptSyntax(ctx: JSContextRef, script: JSStringRef, sourceURL: JSStringRef, startingLineNumber: Int32, exception: UnsafeMutablePointer<JSValueRef>) -> Bool
			//func JSEvaluateScript(ctx: JSContextRef, script: JSStringRef, thisObject: JSObjectRef, sourceURL: JSStringRef, startingLineNumber: Int32, exception: UnsafeMutablePointer<JSValueRef>) -> JSValueRef
			// could make this == $ ...
			// https://github.com/facebook/react-native/blob/master/React/Executors/RCTContextExecutor.m#L304
			// https://github.com/facebook/react-native/blob/0fbe0913042e314345f6a033a3681372c741466b/React/Executors/RCTContextExecutor.m#L175

			let exception = JSValue()

			if JSCheckScriptSyntax(
				/*ctx:*/ context?.jsGlobalContextRef,
				/*script:*/ JSStringCreateWithCFString(script as CFString),
				/*sourceURL:*/ JSStringCreateWithCFString(sourceURL as CFString),
				/*startingLineNumber:*/ Int32(1),
				/*exception:*/ UnsafeMutablePointer(exception.jsValueRef)
			) {
				warn("\(scriptURL): syntax checked ok")
				context?.name = "\(context?.name) <\(urlstr)>"
				// FIXME: assumes last script loaded is the source file of *all* thrown errors, which is not always true
#if DEBUG
#else
				context?.evaluateScript("eval = null;") // Saaaaaaafe Plaaaaace
#endif
				//return jsdelegate.thisEval(script as String, sourceURL: scriptURL) // TODO: issue #11 - make `this` the delegate in app scripts, not the return
				return context?.evaluateScript(script as String, withSourceURL: scriptURL as URL!)
			} else {
				// hmm, using self.context for the syntax check seems to evaluate the contents anyways
				// need to make a throwaway dupe of it
				warn("bad syntax: \(scriptURL)")
				if exception.isObject { warn("got errObj") }
				// delegate.tryFunc("scriptLoadErrorHandler", JSValue(newErrorFromMessage: "exception", inContext: context))
				if exception.isString { warn(exception.toString()) }
				/*
				var errMessageJSC = JSValueToStringCopy(context.JSGlobalContextRef, exception.JSValueRef, UnsafeMutablePointer(nil))
				var errMessageCF = JSStringCopyCFString(kCFAllocatorDefault, errMessageJSC) //as String
				JSStringRelease(errMessageJSC)
				var errMessage = errMessageCF as String
				warn(errMessage)
				*/
			} // or pop open the script source-code in a new tab and highlight the offender
		}
		return nil
	}

	func doesAppExist(_ appstr: String) -> Bool {
#if os(OSX)
		if LSCopyApplicationURLsForBundleIdentifier(appstr as CFString, nil) != nil { return true }
#elseif os(iOS)
		if let appurl = NSURL(string: "\(appstr)://") { // installed bundleids are usually (automatically?) usable as URL schemes in iOS
			if UIApplication.sharedApplication().canOpenURL(appurl) { return true }
		}
#endif
		return false
	}

	func pathExists(_ path: String) -> Bool { return FileManager.default.fileExists(atPath: (path as NSString).expandingTildeInPath) }

	func openURL(_ urlstr: String, _ appid: String? = nil) {
		if let url = NSURL(string: urlstr) {
#if os(OSX)
			if let appid = appid, appid != "undefined" {
				NSWorkspace.shared().open([url as URL], withAppBundleIdentifier: appid, options: .default, additionalEventParamDescriptor: nil, launchIdentifiers: nil)
			} else {
				NSWorkspace.shared().open(url as URL)
			}
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

	func changeAppIcon(_ iconpath: String) {
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

		if let icon_url = Bundle.main.url(forResource: iconpath, withExtension: "png") ?? URL(string: iconpath) {
			// path was a url, local or remote
			Application.shared().applicationIconImage = NSImage(contentsOf: icon_url)
		} else {
			warn("invalid icon: \(iconpath)")
		}
#endif
	}

	func registerURLScheme(_ scheme: String) {
		// there *could* be an API for this in WebKit, like Chrome & FF: https://bugs.webkit.org/show_bug.cgi?id=92749
		// https://developer.mozilla.org/en-US/docs/Web-based_protocol_handlers
#if os(OSX)
		LSSetDefaultHandlerForURLScheme(scheme as CFString, Bundle.main.bundleIdentifier! as CFString)
		warn("registered URL handler in OSX: \(scheme)")
		//NSApp.registerServicesMenuSendTypes(sendTypes:[.kUTTypeFileURL], returnTypes:nil)
		// http://stackoverflow.com/questions/20461351/how-do-i-enable-services-which-operate-on-selected-files-and-folders
#else
		// use Info.plist: CFBundleURLName = bundleid & CFBundleURLSchemes = [blah1, blah2]
		// on jailed iOS devices, there is no way to do this at runtime :-(
#endif
	}

	//func registerExtension(ext: String) {
		// FIXME: there is an algo for deriving the dyn.* UTI from any given '.ext' .....
		//registerUTI(uti)
	//}

	func registerUTI(_ uti: String) {
#if os(OSX)
		LSSetDefaultRoleHandlerForContentType(uti as CFString, .all,  Bundle.main.bundleIdentifier! as CFString) //kLSRolesNone|Viewer|Editor|Shell|All
		warn("registered UTI handler in OSX: \(uti)")
#endif
	}

	@objc(postNotification::::) func postNotification(_ title: String?, subtitle: String?, msg: String?, id: String?) {
#if os(OSX)
		let note = NSUserNotification()
		note.title = title ?? ""
		note.subtitle = subtitle ?? "" //empty strings wont be displayed
		note.informativeText = msg ?? ""
		//note.contentImage = ?bubble pic?
		if let id = id { note.identifier = id }
		//note.hasReplyButton = true
		//note.hasActionButton = true
		//note.responsePlaceholder = "say something stupid"

		note.soundName = NSUserNotificationDefaultSoundName // something exotic?
		NSUserNotificationCenter.default.deliver(note)
		// these can be listened for by all: http://pagesofinterest.net/blog/2012/09/observing-all-nsnotifications-within-an-nsapp/
#elseif os(iOS)
		let note = UILocalNotification()
		note.alertTitle = title ?? ""
		note.alertAction = "Open"
		note.alertBody = "\(subtitle ?? String()) \(msg ?? String())"
		note.fireDate = NSDate()
		if let id = id { note.userInfo = [ "identifier" : id ] }
		UIApplication.sharedApplication().scheduleLocalNotification(note)
#endif
		//map passed-in blocks to notification responses?
		// http://thecodeninja.tumblr.com/post/90742435155/notifications-in-ios-8-part-2-using-swift-what
	}

/*
	func promptToSaveFile(filename: String? = nil, mimetype: String? = nil, callback: (String)? = nil) {
		let saveDialog = NSSavePanel();
		saveDialog.canCreateDirectories = true
		//saveDialog.allowedFileTypes = [mimetypeUTI]
		if let filename = filename { saveDialog.nameFieldStringValue = filename }
		if let window = self.window {
			saveDialog.beginSheetModalForWindow(window) { (result: Int) -> Void in
				if let url = saveDialog.URL, path = url.path where result == NSFileHandlingPanelOKButton {
					NSFileManager.defaultManager().createFileAtPath(path, contents: data, attributes: nil)
					if let callback = callback { callback(path); }
				}
			}
		}
	}
*/

	func postHTML5Notification(_ object: [String:AnyObject]) {
		// object's keys conforming to:
		//   https://developer.mozilla.org/en-US/docs/Web/API/notification/Notification

		// there is an API for this in WebKit: http://playground.html5rocks.com/#simple_notifications
		//  https://developer.apple.com/library/iad/documentation/AppleApplications/Conceptual/SafariJSProgTopics/Articles/SendingNotifications.html
		//  but all my my WKWebView's report 2 (access denied) and won't display auth prompts
		//  https://github.com/WebKit/webkit/search?q=webnotificationprovider  no api delegates in WK2 for notifications or geoloc yet
		//  http://stackoverflow.com/questions/14237086/how-to-handle-html5-web-notifications-with-a-cocoa-webview
#if os(OSX)
		let note = NSUserNotification()
		for (key, value) in object {
			switch value {
				case let title as String where key == "title": note.title = title
				case let subtitle as String where key == "subtitle": note.subtitle = subtitle // not-spec
				case let body as String where key == "body": note.informativeText = body
				case let tag as String where key == "tag": note.identifier = tag
				case let icon as String where key == "icon":
					if let url = NSURL(string: icon), let img = NSImage(contentsOf: url as URL) {
						note._identityImage = img // left-side iTunes-ish http://stackoverflow.com/a/22586980/3878712
						//note._imageURL = url //must be a file:// URL
					}
				case let image as String where key == "image": //not-spec
					if let url = NSURL(string: image), let img = NSImage(contentsOf: url as URL) {
						note.contentImage = img // right-side embed
					}
				default: warn("unhandled param: `\(key): \(value)`")
			}
		}
		note.soundName = NSUserNotificationDefaultSoundName // something exotic?
		NSUserNotificationCenter.default.deliver(note)
#elseif os(iOS)
		let note = UILocalNotification()
		note.alertAction = "Open"
		note.fireDate = NSDate()
		for (key, value) in object {
			switch value {
				case let title as String where key == "title": note.alertTitle = title
				case let body as String where key == "body": note.alertBody = body
				case let tag as String where key == "tag": note.userInfo = [ "identifier" : tag ]
				//case let icon as String where key == "icon": loadIcon(icon)
				default: warn("unhandled param: `\(key): \(value)`")
			}
		}
		UIApplication.sharedApplication().scheduleLocalNotification(note)
#endif
	}


	func REPL() {
#if os(OSX)
		//NSProcessInfo.processInfo().disableSuddenTermination()
		//NSProcessInfo.processInfo().disableAutomaticTermination("REPL")
#endif
		termiosREPL(
			{ [unowned self] (line: String) -> Void in
				let val = self.context?.evaluateScript(line)
				if self.jsdelegate.isObject && self.jsdelegate.hasProperty("REPLprint") { // app.js will customize output
					if let ret = self.jsdelegate.invokeMethod("REPLprint", withArguments: [val as Any]).toString() {
						print(ret)
					}
				} else { // no REPLprint handler, just eval and dump
					print(val as Any)
				}
			},
			ps1: #file,
			ps2: #function,
			abort: { () -> Void in
				// EOF'd by Ctrl-D
#if os(OSX)
				//NSProcessInfo.processInfo().enableAutomaticTermination("REPL")
				ProcessInfo.processInfo.enableSuddenTermination()
				NSApp.reply(toApplicationShouldTerminate: true) // now close App if this was deferring a terminate()
				// FIXME: make sure prompter is deinit'd
				prompter = nil
				NSApplication.shared().terminate(self)
#endif
			}
		)
	}

	func evalJXA(_ script: String) {
		// FIXME: force a confirmation panel with printout of script and func+args to be called.....
#if os(OSX)
		var error: NSDictionary?
		let osa = OSAScript(source: script, language: OSALanguage(forName: "JavaScript"))
		if let output = osa.executeAndReturnError(&error) {
			warn(output.description)
		} else if (error != nil) {
			warn("error: \(error)")
		}
#endif
	}

	func callJXALibrary(_ library: String, _ call: String, _ args: [AnyObject]) {
		// FIXME: force a confirmation panel with link to library path and func+args to be called.....
#if os(OSX)
#if DEBUG
		let script = "function run() { return Library('\(library)').\(call).apply(this, arguments); }"
#else
		let script = "eval = null; function run() { return Library('\(library)').\(call).apply(this, arguments); }"
#endif
		var error: NSDictionary?
		let osa = OSAScript(source: script, language: OSALanguage(forName: "JavaScript"))
		if let output: NSAppleEventDescriptor = osa.executeHandler(withName: "run", arguments: args, error: &error) {
			// does this interpreter persist? http://lists.apple.com/archives/applescript-users/2015/Jan/msg00164.html
			warn(output.description) // FIXME: use https://bitbucket.org/hhas/swiftae to introspect?
		} else if (error != nil) {
			warn("error: \(error)")
		}
#endif
	}

}
