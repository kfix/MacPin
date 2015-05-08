/// MacPin Extensions
///
/// Global-scope utility functions 

import Foundation
import JavaScriptCore
import WebKit

#if os(OSX)
import AppKit
#elseif os (iOS)
import UIKit
#endif

#if arch(x86_64) || arch(i386)
import Prompt // https://github.com/neilpa/swift-libedit
#endif

func warn(_ msg: String = String(), function: StaticString = __FUNCTION__, file: StaticString = __FILE__, line: UWord = __LINE__, column: UWord = __COLUMN__) {
	NSFileHandle.fileHandleWithStandardError().writeData(("<\(file):\(line):\(column)> [\(function)] \(msg)\n").dataUsingEncoding(NSUTF8StringEncoding)!)
}



/*
func assert(condition: @autoclosure () -> Bool, _ message: String = "",
	file: String = __FILE__, line: Int = __LINE__) {
		#if DEBUG
			if !condition() {
				println("assertion failed at \(file):\(line): \(message)")
				abort()
			}
		#endif
}
*/

func loadUserScriptFromBundle(basename: String, webctl: WKUserContentController, inject: WKUserScriptInjectionTime, onlyForTop: Bool = true, error: NSErrorPointer? = nil) -> Bool {
	if let script_url = NSBundle.mainBundle().URLForResource(basename, withExtension: "js") {
		warn("loading userscript: \(script_url)")
		var script = WKUserScript(
			source: NSString(contentsOfURL: script_url, encoding: NSUTF8StringEncoding, error: nil) as! String,
		    injectionTime: inject,
		    forMainFrameOnly: onlyForTop
		)
		webctl.addUserScript(script)
	} else {
		let respath = NSBundle.mainBundle().resourcePath
		warn("couldn't find userscript: \(respath)/\(basename).js")
		if error != nil {
			error?.memory = NSError(domain: "MacPin", code: 3, userInfo: [
				NSFilePathErrorKey: basename + ".js",
				NSLocalizedDescriptionKey: "No userscript could be found named:\n\n\(respath)/\(basename).js"
			])
		}
		/*
		if let window = NSApplication.sharedApplication().mainWindow { // FIXMEios UIKit.UIApplication.sharedApplication()
			window.presentError(error, modalForWindow: window, delegate: nil, didPresentSelector: nil, contextInfo: nil)
		} else {
			NSApplication.sharedApplication().presentError(error)
		}
		*/
		return false
	}
	return true
}

func validateURL(urlstr: String) -> NSURL? {
	// https://github.com/WebKit/webkit/blob/master/Source/WebKit/ios/Misc/WebNSStringExtrasIOS.m
	if urlstr.isEmpty { return nil }
	if let urlp = NSURLComponents(string: urlstr) {
		if urlstr.hasPrefix("/") || urlstr.hasPrefix("~/") { urlp.scheme = "file" } // FIXME: check if bare filepath points to actual file/dir
		if !((urlp.path ?? "").isEmpty) && (urlp.scheme ?? "").isEmpty && (urlp.host ?? "").isEmpty { // 'example.com' & 'example.com/foobar'
			urlp.scheme = "http"
			urlp.host = urlp.path
			urlp.path = nil
		}
		if let url = urlp.URL { return url }
	}

	if JSRuntime.jsdelegate.tryFunc("handleUserInputtedInvalidURL", urlstr) { return nil } // the delegate function will open url directly

	// maybe its a search query? check if blank and reformat it
	if !urlstr.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()).isEmpty,
		let query = urlstr.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding), 
		let search = NSURL(string: "https://duckduckgo.com/?q=\(query)") {
			return search
		}

	return nil 
}

func termiosREPL(_ eval:((String)->Void)? = nil, ps1: StaticString = __FILE__, ps2: StaticString = __FUNCTION__, abort:(()->Void)? = nil) {
#if arch(x86_64) || arch(i386)
	let backgroundQueue = dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0)
	dispatch_async(backgroundQueue, { // console ops in background thread
		let prompt = Prompt(argv0: Process.unsafeArgv[0]) // should make this a singleton, so the AppDel termination can kill it
		while (true) {
			print("\(ps1): ") // prompt prefix
		    if let line = prompt.gets() { // R: blocks here until Enter pressed
				print("\(ps2): ") // result prefix
				dispatch_async(dispatch_get_main_queue(), { () -> Void in //return to main thread to evaluate code
					eval?(line) // E:, P:
				})
		    } else { // stdin closed
				dispatch_async(dispatch_get_main_queue(), { () -> Void in
					if let abort = abort { abort() }
						else { println("Got EOF from stdin, closing REPL!") }
				})
				break
			}
			// L: command completed, restart loop
			println() //newline
		}
#if os(OSX)
		NSApplication.sharedApplication().terminate(nil)
#elseif os(iOS)
		//UIApplication.sharedApplication().terminateWithSuccess() // http://blog.ib-soft.net/2013/01/programmatically-terminate-ios.html
#endif
	})
#else
	println("Prompt() not available on this device.")
#endif
}


//@objc protocol JS2NSArray: JSExport { func push2(obj: AnyObject) -> NSArray }
//extension NSArray: JS2NSArray { func push2(obj: AnyObject) -> NSArray { warn(obj.description); return arrayByAddingObject(obj) } }

//@objc protocol JSArray: JSExport { func push(newElement: AnyObject) }
//extension ContiguousArray: JSArray { mutating func push(newElement: T) { append(newElement) } }
