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

var startTime = Date()

extension FileHandle: TextOutputStream {
	public func write(_ string: String) {
		guard let data = string.data(using: .utf8) else { return }
		self.write(data)
	}
}

extension TimeInterval {
    // builds string in app's labels format 00:00.0
    func stopwatch(invert: Bool = false) -> String {
		let ref = invert ? (self * -1) : self
        var miliseconds = (ref * 10).rounded() / 10
        let interval = Int(ref)
        let seconds = interval % 60
        let minutes = (interval / 60) % 60
        return String(format: "%02d:%02d.%03.f", minutes, seconds, miliseconds)
    }
}

class StandardErrorOutputStream {
	let stderr = OutputStream(toFileAtPath: "/dev/stderr", append: true)!

	func write(_ string: String) {
		guard let data = string.data(using: .utf8) else { return } // encoding failure
		if stderr.hasSpaceAvailable {
			stderr.write(string, maxLength: string.utf8.count)
			// stderr.streamError
		}
	}

	init() {
		stderr.open()
	}
}

let g_stdErr = StandardErrorOutputStream()

func warn(_ msg: String = String(), function: StaticString = #function, file: StaticString = #file, line: UInt = #line, column: UInt = #column) {
	// https://forums.swift.org/t/supplement-file-line-and-function-with-context/9505/2
	// https://github.com/swisspol/XLFacility ?

	var out = ""
	// [min:sec.ms] <codeloc> [fn] message
	if #available(OSX 10.12, iOS 10, *) {
		out = "[\(DateInterval(start: startTime, end: Date()).duration.stopwatch())] <\(file):\(line):\(column)> [\(function)] \(msg)"
	} else {
		out = "[\((startTime.timeIntervalSinceNow.stopwatch(invert: true)))] <\(file):\(line):\(column)> [\(function)] \(msg)"
	}

	g_stdErr.write("\r\(out)\n") // NSOutputStream.write is resilient to closed files, unlike NSFileHandle.write

#if WARN2NSLOG
	NSLog(out)
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

func warn(_ items: Any..., function: StaticString = #function, file: StaticString = #file, line: UInt = #line, column: UInt = #column) {
	var out = ""
	debugPrint(items, separator: " ", terminator: "", to: &out)
	warn(out, function: function, file: file, line: line, column: column)
}

func warn(obj: Any?, function: StaticString = #function, file: StaticString = #file, line: UInt = #line, column: UInt = #column) {
	// handles chunky objdumps
	var out = ""
	guard let obj = obj else { warn("nil"); return } //force unwrap obj
	dump(obj, to: &out, name: nil, indent: 0, maxDepth: Int.max, maxItems: Int.max) // a nil further down the tree will cause a seg!
	warn(out, function: function, file: file, line: line, column: column)
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
func loadUserScriptFromBundle(_ basename: String, webctl: WKUserContentController, inject: WKUserScriptInjectionTime, onlyForTop: Bool = true, error: NSErrorPointer = nil) -> Bool {
	if let scriptUrl = Bundle.main.url(forResource: basename, withExtension: "js"), !basename.isEmpty {
		warn("loading userscript: \(scriptUrl)")
		let script = WKUserScript(
			source: (try? NSString(contentsOf: scriptUrl, encoding: String.Encoding.utf8.rawValue) as String) ?? "",
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
			//webctl.addUserScriptImmediately(script) // https://github.com/WebKit/webkit/commit/9509d7a48a026d9dc9fd229b13eabf7346cd77aa
		} else { warn("\(scriptUrl) already loaded!"); return false }

	} else {
		let respath = Bundle.main.resourcePath
		warn("couldn't find userscript: \(respath)/\(basename).js")
		if error != nil {
			/* error?.memory = NSError(domain: "MacPin", code: 3, userInfo: [
				NSFilePathErrorKey: basename + ".js",
				NSLocalizedDescriptionKey: "No userscript could be found named:\n\n\(respath ?? "?no-path?")/\(basename).js"
			]) */
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
func loadUserStyleSheetFromBundle(_ basename: String, webctl: WKUserContentController, onlyForTop: Bool = true, error: NSErrorPointer = nil) -> Bool {
	if let cssUrl = Bundle.main.url(forResource: basename, withExtension: "css"), !basename.isEmpty {
		warn("loading stylesheet: \(cssUrl)")
		let css = _WKUserStyleSheet(
			source: (try? NSString(contentsOf: cssUrl, encoding: String.Encoding.utf8.rawValue) as String) ?? "",
		    forMainFrameOnly: onlyForTop
		    //legacyWhitelist
		    //legacyBlacklist
		    	//baseUrl
		    //userContentWorld
		)
		if webctl._userStyleSheets.filter({$0 == css}).count < 1 { // don't re-add identical sheets
			webctl._add(css)
		} else { warn("\(cssUrl) already loaded!"); return false }

	} else {
		let respath = Bundle.main.resourcePath
		warn("couldn't find stylesheet: \(respath)/\(basename).css")
		if error != nil {
			/* error?.memory = NSError(domain: "MacPin", code: 3, userInfo: [
				NSFilePathErrorKey: basename + ".js",
				NSLocalizedDescriptionKey: "No stylesheet could be found named:\n\n\(respath)/\(basename).css"
			]) */
		}
		return false
	}
	return true
}

// https://github.com/dequin-cl/WKContentRuleExample/blob/master/Filtering%20WkView/ViewController.swift#L49
@available(OSX 10.13, iOS 11, *)
func loadUserBlockListFromBundle(_ basename: String, webctl: WKUserContentController, onlyForTop: Bool = true, error: NSErrorPointer = nil) -> Bool {
	if let jsonUrl = Bundle.main.url(forResource: basename, withExtension: "json"), !basename.isEmpty {
		warn("loading block list: \(jsonUrl)")
		WKContentRuleListStore.default().compileContentRuleList(
			forIdentifier: basename,
			encodedContentRuleList: (try? NSString(contentsOf: jsonUrl, encoding: String.Encoding.utf8.rawValue) as String) ?? ""
		) { (ruleList, error) in // https://stackoverflow.com/a/48084455/3878712
			if let ruleList = ruleList {
				webctl.add(ruleList)
			} else if let error = error {
				return
			}
		}
	} else {
		return false
	}
	return true
}


func validateURL(_ urlstr: String, fallback: ((String) -> URL?)? = nil) -> URL? {
	// apply fuzzy logic like WK1: https://github.com/WebKit/webkit/blob/master/Source/WebKit/ios/Misc/WebNSStringExtrasIOS.m
	// or firefox-ios: https://github.com/mozilla/firefox-ios/commit/6cab24f7152c2e56e864a9d75f4762b2fbdc6890
	// CFURL parser: https://opensource.apple.com/source/CF/CF-1153.18/CFURL.inc.h.auto.html
	// FIXME: handle javascript: urls
	if urlstr.isEmpty { return nil }

	// handle file:s
	schemehandler: if urlstr.hasPrefix("file:") || urlstr.hasPrefix("/") || urlstr.hasPrefix("~/") || urlstr.hasPrefix("./") {
		warn("validating file: url: \(urlstr)")
		let urlp = NSURLComponents()
		var path = urlstr
		urlp.scheme = "file"
		if path.hasPrefix("file:") { path.removeFirst(5) }
		if path.hasPrefix("///") { path.removeFirst(2) }
		if path.isEmpty { warn("no filepath!"); return nil }
		urlp.path = path

		//if var upath = path.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLPathAllowedCharacterSet()) {
		//	urlp.path = upath
		//	warn("urlescaped \(upath) -> \(urlp.path)")
		//}

		if path.hasPrefix("./") { // consider this == Resources/, then == CWD/
			path.replaceSubrange(path.startIndex..<path.index(path.startIndex, offsetBy: 1),
				with: Bundle.main.resourcePath ?? FileManager().currentDirectoryPath)
			// TODO: handle spaces
			urlp.path = path
		}

		// TODO: handle ~/

		if let url = urlp.url?.standardizedFileURL, FileManager.default.fileExists(atPath: path) {
			return url // this file is confirmed to exist, lets use it
			// BUG: this is accepting all folders, should only do that if index.html exists
		} else {
			warn("\(path) not found - request was for \(urlstr)")
			return nil
		}
	} else if let urlp = NSURLComponents(string: urlstr), !urlstr.hasPrefix("?") {
		// handle networked urls
		if urlp.scheme == "about" { return urlp.url }
		barehttp: if let path = urlp.path, !path.isEmpty && !urlstr.contains(" ") && (urlp.scheme ?? "").isEmpty && (urlp.host ?? "").isEmpty && urlstr.contains(".") { // 'example.com' & 'example.com/foobar'
			if let _ = Int(path) { break barehttp; } //FIXME: ensure not all numbers. RFC952 & 1123 differ on this, but inet_ does weird stuff regardless
			urlp.scheme = "http"
			if !urlstr.contains("/") { // example.com
				urlp.host = urlp.path
				urlp.path = nil
			} else { // example.com/foobar
				warn("slashy!")
				let pcomps = urlstr.split(separator: "/")
				urlp.host = String(pcomps[0])
				urlp.path = String("/" + pcomps[1...].joined(separator: "/"))
			}
		}

		//do preemptive nslookup on urlp.host
		warn(urlp.description)
		if let url = urlp.url, let host = urlp.host, (urlp.scheme == "http" || urlp.scheme == "https"),
			!host.isEmpty,
			(host.rangeOfCharacter(from: CharacterSet(charactersIn: "!$&'()*+,;=_~").symmetricDifference(CharacterSet.urlHostAllowed).inverted) != nil ) {
// my dumper says urlHostAllowed == !$&'()*+,-.0123456789:;=ABCDEFGHIJKLMNOPQRSTUVWXYZ[]_abcdefghijklmnopqrstuvwxyz~
/// that is really wrong....  https://opensource.apple.com/source/CF/CF-1153.18/CFCharacterSet.h.auto.html
			warn("preflighting \(host)")
			if let chost = host.cString(using: String.Encoding.utf8) {
				if let hp = gethostbyname2(chost, AF_INET), hp.hashValue > 0 {
					warn("IPV4 preflight succeeded")
					return url // hostname preflighted, so use let WK try this url
				} else if let hp = gethostbyname2(chost, AF_INET6), hp.hashValue > 0 {
					warn("IPV6 preflight suceeded")
					return url // hostname preflighted, so use let WK try this url
				} else {
					warn("preflighting failed")
					break schemehandler // try the fallback
				}
			}

			// what if lookup failed because internet offline? should call jsdelegate.networkIsOffline ??
			// FIXME use higher level APIs for NAT64 - NSURLConnection.canHandleRequest()

		} else if !((urlp.scheme ?? "").isEmpty) {
			// we were force-fed a (custom?) scheme...
			// I have no idea how to preflight those so follow thru with the URL
			warn(urlp.description)
			return urlp.url
		}
	}

	if let fallback = fallback {
		// caller provided a failure handler
		return fallback(urlstr)
	} else {
		return nil
	}
}

func searchForKeywords(_ str: String) -> URL? {
	// return a URL that will search the given keyword string

	// maybe its a search query? check if blank and reformat it
	if !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
		let query = str.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
		let search = URL(string: "https://duckduckgo.com/?q=\(query)") { // FIXME: JS setter
			return search
		}
	// FIXME: support OpenSearch to search current site on-the-fly https://en.wikipedia.org/wiki/OpenSearch
		// https://developer.mozilla.org/en-US/Add-ons/Creating_OpenSearch_plugins_for_Firefox
	return nil
}

//@objc protocol JS2NSArray: JSExport { func push2(obj: AnyObject) -> NSArray }
//extension NSArray: JS2NSArray { func push2(obj: AnyObject) -> NSArray { warn(obj.description); return arrayByAddingObject(obj) } }

//@objc protocol JSArray: JSExport { func push(newElement: AnyObject) }
//extension ContiguousArray: JSArray { mutating func push(newElement: T) { append(newElement) } }

// https://stackoverflow.com/a/49588446/3878712
#if swift(>=4.2)
#else
public protocol CaseIterable {
    associatedtype AllCases: Collection where AllCases.Element == Self
    static var allCases: AllCases { get }
}
extension CaseIterable where Self: Hashable {
    static var allCases: [Self] {
        return [Self](AnySequence { () -> AnyIterator<Self> in
            var raw = 0
            return AnyIterator {
                let current = withUnsafeBytes(of: &raw) { $0.load(as: Self.self) }
                guard current.hashValue == raw else {
                    return nil
                }
                raw += 1
                return current
            }
        })
    }
}
#endif
