/*
	Joey Korkames (c)2015
	Special thanks to Google for its horrible Hangouts App on Chrome for OSX :-)
*/
// somehow get a JXA bridge working?
//  https://developer.apple.com/library/mac/releasenotes/InterapplicationCommunication/RN-JavaScriptForAutomation/index.html

let jsruntime = AppScriptRuntime() //singleton

import Cocoa
import JavaScriptCore //  https://github.com/WebKit/webkit/tree/master/Source/JavaScriptCore/API

public extension JSValue {
	func tryFunc (method: String, _ args: AnyObject...) -> Bool {
		if self.hasProperty(method) {
			var ret = self.invokeMethod(method, withArguments: args)
			if let bool = ret.toObject() as? Bool { return bool }
			// exec passed closure here?
		}
		return false
	}
}

@objc protocol OSXScriptExports : JSExport { // '$osx' in app.js
	var resourcePath: String { get }
	//func log(msg: String)
	func registerURLScheme(scheme: String)
	func postNotification(title: String, _ subtitle: String?, _ msg: String)
	func openURL(urlstr: String, _ app: String?)
	func sleep(secs: Double)
}

public class AppScriptRuntime: NSObject, OSXScriptExports  {

	var context = JSContext(virtualMachine: JSVirtualMachine())
	var delegate: JSValue

	var resourcePath: String { get { return ( NSBundle.mainBundle().resourcePath ?? String() ) } }

    override init() {
		delegate = context.evaluateScript("{};")! //default property-less delegate obj
		super.init()
	}

	//func log(msg: String) { }

	func sleep(secs: Double) {
		let delayTime = dispatch_time(DISPATCH_TIME_NOW, Int64(Double(NSEC_PER_SEC) * secs))
		dispatch_after(delayTime, dispatch_get_main_queue()){}
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
		if let app_js = NSBundle.mainBundle().URLForResource("app", withExtension: "js") {
			// https://bugs.webkit.org/show_bug.cgi?id=122763 -- allow evaluteScript to specify source URL
			// FIXME: pop up an alert panel on app.js errors?
			// or how about a TabVIewItem with a textview based JSConsole?
			context.exceptionHandler = { context, exception in
				//warn("\(context.name) <\(app_js)> (\(context.currentCallee)) \(context.currentThis): \(exception)")
				warn("\(app_js): `\(exception)`") // FIXME need a line number!
				//context.$browser.conlog(.....)
				context.exception = exception //default in JSContext.mm
				return // gets returned to evaluateScript()?
			} 
			warn("\(__FUNCTION__): \(app_js)")
			context.setObject(self, forKeyedSubscript: "$osx")
			//context.setObject(log, forKeyedSubscript: "log")
			// ^ pass in block that will also copy to $browser.conlog()
			if let jsobj = loadJSCoreScriptFromBundle("app") {
				delegate = jsobj
				// FIXME JSValue is very ambiguous, should confirm it it is a {}
				delegate.tryFunc("AppFinishedLaunching")
			}
		}
	}
	
	func loadJSCoreScriptFromBundle(basename: String) -> JSValue? {
		if let script_url = NSBundle.mainBundle().URLForResource(basename, withExtension: "js") {
			let script = NSString(contentsOfURL: script_url, encoding: NSUTF8StringEncoding, error: nil)!
			return context.evaluateScript(script, withSourceURL: script_url)
		}
		return nil
	}

	func openURL(urlstr: String, _ appid: String? = nil) {
		if let url = NSURL(string: urlstr) {
			NSWorkspace.sharedWorkspace().openURLs([url], withAppBundleIdentifier: appid, options: .AndHideOthers, additionalEventParamDescriptor: nil, launchIdentifiers: nil)
			//options: .Default .NewInstance .AndHideOthers
		}
	}

	// func newTrayTab
	//  support opening a page as a NSStatusItem icon by the clock
	// https://github.com/phranck/CCNStatusItem

	func registerURLScheme(scheme: String) {
		LSSetDefaultHandlerForURLScheme(scheme, NSBundle.mainBundle().bundleIdentifier)
		warn("registered URL handler in OSX: \(scheme)")

		//NSApp.registerServicesMenuSendTypes(sendTypes:[.kUTTypeFileURL], returnTypes:nil)
		// http://stackoverflow.com/questions/20461351/how-do-i-enable-services-which-operate-on-selected-files-and-folders
	}

	func postNotification(title: String, _ subtitle: String?, _ msg: String) {
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

}
