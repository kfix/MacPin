/// MacPin Generics
///
/// Classless "generic" utility functions

import Foundation
import JavaScriptCore
import WebKit
import Darwin

#if os(OSX)
import AppKit
#elseif os (iOS)
import UIKit
#endif

#if arch(x86_64) || arch(i386)
import Async // https://github.com/duemunk/Async
import Prompt // https://github.com/neilpa/swift-libedit
var prompter: Async? = nil
#endif

func warn(msg: String = String(), function: StaticString = __FUNCTION__, file: StaticString = __FILE__, line: UInt = __LINE__, column: UInt = __COLUMN__) {
	// https://github.com/swisspol/XLFacility ?
	NSFileHandle.fileHandleWithStandardError().writeData(("[\(NSDate())] <\(file):\(line):\(column)> [\(function)] \(msg)\n").dataUsingEncoding(NSUTF8StringEncoding)!)
#if WARN2NSLOG
	NSLog("<\(file):\(line):\(column)> [\(function)] \(msg)")
	//FIXME timestamp?
#endif
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
	if let scriptUrl = NSBundle.mainBundle().URLForResource(basename, withExtension: "js") where !basename.isEmpty {
		warn("loading userscript: \(scriptUrl)")
		let script = WKUserScript(
			source: (try? NSString(contentsOfURL: scriptUrl, encoding: NSUTF8StringEncoding) as String) ?? "",
		    injectionTime: inject,
		    forMainFrameOnly: onlyForTop
		)
		if webctl.userScripts.filter({$0 == script}).count < 1 { // don't re-add identical userscripts
		//if (find(webctl.userScripts, script) ?? -1) < 0 { // don't re-add identical userscripts
			webctl.addUserScript(script)
		} else { warn("\(scriptUrl) already loaded!"); return false }

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

func validateURL(urlstr: String, fallback: (String -> NSURL?)? = nil) -> NSURL? {
	// https://github.com/WebKit/webkit/blob/master/Source/WebKit/ios/Misc/WebNSStringExtrasIOS.m
	if urlstr.isEmpty { return nil }
	if let urlp = NSURLComponents(string: urlstr) where !urlstr.characters.contains(" ") && !urlstr.hasPrefix("?") {
		if urlstr.hasPrefix("/") || urlstr.hasPrefix("~/") { urlp.scheme = "file" } // FIXME: check if bare filepath points to actual file/dir
		if !((urlp.path ?? "").isEmpty) && (urlp.scheme ?? "").isEmpty && (urlp.host ?? "").isEmpty { // 'example.com' & 'example.com/foobar'
			urlp.scheme = "http"
			urlp.host = urlp.path
			urlp.path = nil
		}
		if let url = urlp.URL, host = urlp.host {
			//do preemptive nslookup on urlp.host
			let chost = host.cStringUsingEncoding(NSUTF8StringEncoding)!
			// FIXME use higher level APIs for NAT64
			if gethostbyname2(chost, AF_INET).hashValue > 0 || gethostbyname2(chost, AF_INET6).hashValue > 0 { // failed lookups return null pointer
				return url // hostname resolved, so use this url
			}
		}
	}

	if let url = fallback?(urlstr) { return url } // caller provided a failure mode which returned the url
	else if AppScriptRuntime.shared.jsdelegate.tryFunc("handleUserInputtedInvalidURL", urlstr) { return nil } // compat with generic JS handler method
	else {
		// maybe its a search query? check if blank and reformat it
		// FIXME: this should get refactored to a browserController/OmniBoxController closure thats passed as fallback?
		if !urlstr.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()).isEmpty,
		let query = urlstr.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding),
		let search = NSURL(string: "https://duckduckgo.com/?q=\(query)") {
			return search
		}
		// as a fallback, could forcibly change OmniBox stringValue to raw search terms
		// FIXME: support OpenSearch to search current site on-the-fly https://en.wikipedia.org/wiki/OpenSearch
		// https://developer.mozilla.org/en-US/Add-ons/Creating_OpenSearch_plugins_for_Firefox

		return nil
	}
}

func termiosREPL(eval:((String)->Void)? = nil, ps1: StaticString = __FILE__, ps2: StaticString = __FUNCTION__, abort:(()->Void)? = nil) {
#if arch(x86_64) || arch(i386)
	prompter = Async.background {
		let prompt = Prompt(argv0: Process.unsafeArgv[0], prompt: "\(ps1)[\(ps2)]:> ")
		while (true) {
		    if let line = prompt.gets() { // R: blocks here until Enter pressed
				if !line.hasPrefix("\n") {
					print("| ") // result prefix
					eval?(line) // E:, P:
					//println() //newline
				}
		    } else { // stdin closed or EOF'd
				if let abort = abort { abort() }
				else { print("\(ps1): got EOF from stdin, stopping \(ps2)") }
				break
			}
			// L: command dispatched, restart loop
		}
		// prompt loop killed, dealloc'd?
	}
#else
	print("Prompt() not available on this device.")
#endif
}


//@objc protocol JS2NSArray: JSExport { func push2(obj: AnyObject) -> NSArray }
//extension NSArray: JS2NSArray { func push2(obj: AnyObject) -> NSArray { warn(obj.description); return arrayByAddingObject(obj) } }

//@objc protocol JSArray: JSExport { func push(newElement: AnyObject) }
//extension ContiguousArray: JSArray { mutating func push(newElement: T) { append(newElement) } }
