/// MacPin Generics
///
/// Classless "generic" utility functions

import Foundation
import JavaScriptCore
import WebKit
import WebKitPrivates
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

func warn(msg: String = String(), function: StaticString = #function, file: StaticString = #file, line: UInt = #line, column: UInt = #column) {
	// https://github.com/swisspol/XLFacility ?
	NSFileHandle.fileHandleWithStandardError().writeData(("[\(NSDate())] <\(file):\(line):\(column)> [\(function)] \(msg)\n").dataUsingEncoding(NSUTF8StringEncoding)!)
#if WARN2NSLOG
	NSLog("<\(file):\(line):\(column)> [\(function)] \(msg)")
	//FIXME timestamp?
#endif
	// https://developer.apple.com/library/mac/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/LoggingErrorsAndWarnings.html
#if ASL
	// FIXME: we want to output to Console.app, preferrably toggled from GUI/NSUserDefaults/argv
	// https://gist.github.com/kristopherjohnson/0ded6cd153f61c627226
	// https://github.com/emaloney/CleanroomASL
#endif
#if SYSLOG
	// http://stackoverflow.com/questions/33194791/how-can-i-use-syslog-in-swift
#endif
}

/*
func assert(condition: @autoclosure () -> Bool, _ message: String = "",
	file: String = #file, line: Int = #line) {
		#if DEBUG
			if !condition() {
				println("assertion failed at \(file):\(line): \(message)")
				abort()
			}
		#endif
}
*/

// https://developer.apple.com/library/content/documentation/Tools/Conceptual/SafariExtensionGuide/InjectingScripts/InjectingScripts.html#//apple_ref/doc/uid/TP40009977-CH6-SW1
func loadUserScriptFromBundle(basename: String, webctl: WKUserContentController, inject: WKUserScriptInjectionTime, onlyForTop: Bool = true, error: NSErrorPointer? = nil) -> Bool {
	if let scriptUrl = NSBundle.mainBundle().URLForResource(basename, withExtension: "js") where !basename.isEmpty {
		warn("loading userscript: \(scriptUrl)")
		let script = WKUserScript(
			source: (try? NSString(contentsOfURL: scriptUrl, encoding: NSUTF8StringEncoding) as String) ?? "",
		    injectionTime: inject,
		    forMainFrameOnly: onlyForTop
		)

		// TODO: parse some of UserScript Metadata Block if present: https://wiki.greasespot.net/Metadata_Block
		// @include, @exclude, @description, @icon, @match, @name, @namespace, @frames, @noframes, @run-at
		// https://wiki.greasespot.net/Cross-browser_userscripting
		// https://github.com/kzys/greasekit
		// https://github.com/os0x/NinjaKit/blob/master/NinjaKit.safariextension/js/background.js
		// https://github.com/Tampermonkey/tampermonkey
		// http://www.opera.com/docs/userjs/using/#writingscripts
		// would have to have a per-controller cachedUserScripts: [WKUserScripts] that are pushed/popped from the contentController by navigation delegates depending on URL being visited

		// FIXME: break this out into its own func
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
		if let window = MacPinApp.sharedApplication().appDelegate?.window {
			window.presentError(error, modalForWindow: window, delegate: nil, didPresentSelector: nil, contextInfo: nil) // FIXME: iOS
		} else {
			MacPinApp.sharedApplication().presentError(error)
		}
		*/
		return false
	}
	return true
}

// https://developer.apple.com/library/content/documentation/Tools/Conceptual/SafariExtensionGuide/AddingStyles/AddingStyles.html#//apple_ref/doc/uid/TP40009977-CH7-SW3
// does WK2 support `@import: url("file://Path/To/Your/Stylesheet.css");` ??
func loadUserStyleSheetFromBundle(basename: String, webctl: WKUserContentController, onlyForTop: Bool = true, error: NSErrorPointer? = nil) -> Bool {
	if let cssUrl = NSBundle.mainBundle().URLForResource(basename, withExtension: "css") where !basename.isEmpty {
		warn("loading stylesheet: \(cssUrl)")
		let css = _WKUserStyleSheet(
			source: (try? NSString(contentsOfURL: cssUrl, encoding: NSUTF8StringEncoding) as String) ?? "",
		    forMainFrameOnly: onlyForTop
		    //legacyWhitelist
		    //legacyBlacklist
		    	//baseUrl
		    //userContentWorld
		)
		if webctl._userStyleSheets.filter({$0 == css}).count < 1 { // don't re-add identical sheets
			webctl._addUserStyleSheet(css)
		} else { warn("\(cssUrl) already loaded!"); return false }

	} else {
		let respath = NSBundle.mainBundle().resourcePath
		warn("couldn't find stylesheet: \(respath)/\(basename).css")
		if error != nil {
			error?.memory = NSError(domain: "MacPin", code: 3, userInfo: [
				NSFilePathErrorKey: basename + ".js",
				NSLocalizedDescriptionKey: "No stylesheet could be found named:\n\n\(respath)/\(basename).css"
			])
		}
		return false
	}
	return true
}

func validateURL(urlstr: String, fallback: (String -> NSURL?)? = nil) -> NSURL? {
	// apply fuzzy logic like WK1: https://github.com/WebKit/webkit/blob/master/Source/WebKit/ios/Misc/WebNSStringExtrasIOS.m
	// or firefox-ios: https://github.com/mozilla/firefox-ios/commit/6cab24f7152c2e56e864a9d75f4762b2fbdc6890
	// FIXME: handle javascript: urls
	if urlstr.isEmpty { return nil }
	if let urlp = NSURLComponents(string: urlstr) where !urlstr.hasPrefix("?") {
		// FIXME: ^ urlp doesn't handle unescaped spaces in filenames
		if urlp.scheme == "file" || urlstr.hasPrefix("/") || urlstr.hasPrefix("~/") || urlstr.hasPrefix("./") {
			urlp.scheme = "file"
			guard var path = urlp.path else { warn("no filepath!"); return nil }
			if path.hasPrefix("./") { // consider this == Resources/, then == CWD/
				path.replaceRange(path.startIndex..<path.startIndex.advancedBy(1),
					with: NSBundle.mainBundle().resourcePath ?? NSFileManager().currentDirectoryPath)
				urlp.path = path
			}

			if let url = urlp.URL?.URLByStandardizingPath where NSFileManager.defaultManager().fileExistsAtPath(url.path ?? String()) {
				return url
			} else {
				warn("\(path) not found - request was for \(urlstr)")
				return nil
			}
		}
		if urlp.scheme == "about" { return urlp.URL }
		barehttp: if let path = urlp.path where !path.isEmpty && !urlstr.characters.contains(" ") && (urlp.scheme ?? "").isEmpty && (urlp.host ?? "").isEmpty { // 'example.com' & 'example.com/foobar'
			if let _ = Int(path) { break barehttp; } //FIXME: ensure not all numbers. RFC952 & 1123 differ on this, but inet_ does weird stuff regardless
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

	if let fallback = fallback {
		// caller provided a failure handler
		return fallback(urlstr)
	} else {
		return nil
	}
}

func searchForKeywords(str: String) -> NSURL? {
	// return a URL that will search the given keyword string

	// maybe its a search query? check if blank and reformat it
	if !str.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceAndNewlineCharacterSet()).isEmpty,
		let query = str.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding),
		let search = NSURL(string: "https://duckduckgo.com/?q=\(query)") { // FIXME: JS setter
			return search
		}
	// FIXME: support OpenSearch to search current site on-the-fly https://en.wikipedia.org/wiki/OpenSearch
		// https://developer.mozilla.org/en-US/Add-ons/Creating_OpenSearch_plugins_for_Firefox
	return nil
}

// TODO: exposing a websocketREPL would also be neat: https://github.com/siuying/IGJavaScriptConsole https://github.com/zwopple/PocketSocket
func termiosREPL(eval:((String)->Void)? = nil, ps1: StaticString = #file, ps2: StaticString = #function, abort:(()->Void)? = nil) {
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
		NSApp.replyToApplicationShouldTerminate(true) // now close App if this was deferring a terminate()
	}
#else
	print("Prompt() not available on this device.")
#endif
}


//@objc protocol JS2NSArray: JSExport { func push2(obj: AnyObject) -> NSArray }
//extension NSArray: JS2NSArray { func push2(obj: AnyObject) -> NSArray { warn(obj.description); return arrayByAddingObject(obj) } }

//@objc protocol JSArray: JSExport { func push(newElement: AnyObject) }
//extension ContiguousArray: JSArray { mutating func push(newElement: T) { append(newElement) } }
