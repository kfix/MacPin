/// MacPin AppScript Runtime
///
/// Creates a singleton-instance of JavaScriptCore for intepreting javascript bundles controlling MacPin

#if os(OSX)
import AppKit
import OSAKit
#elseif os(iOS)
import UIKit
#endif

import Foundation
import JavaScriptCore // https://webkit.googlesource.com/WebKit/+/master/Source/JavaScriptCore/ChangeLog
import JavaScriptCorePrivates // https://github.com/WebKit/webkit/tree/master/Source/JavaScriptCore/API
// https://raw.githubusercontent.com/WebKit/webkit/master/Source/JavaScriptCore/ChangeLog
// https://developer.apple.com/videos/play/wwdc2013/615/
import WebKitPrivates
import UserNotificationPrivates

typealias PromiseThen = @convention(block) (JSValue) -> Void

func getResourceURL(_ urlstr: String, function: StaticString = #function, file: StaticString = #file, line: UInt = #line, column: UInt = #column) -> URL? {
	guard let fileURL = Bundle.main.url(forResource: urlstr, withExtension: nil) ??
	URL(string: urlstr)?.standardizedFileURL, fileURL.isFileURL else {
		// FIXME: script code could be loaded from any path, exploitable?
		warn("\(urlstr): could not be found", function: function, file: file, line: line, column: column)
		return nil
	}
	return fileURL
}

// FIXME: AppScript needs a HandlerMethods enum instead of just tryFunc("unsafe-string")s everywhere....
extension JSValue {
	@discardableResult
	func tryFunc (_ method: String, argv: [Any]) -> Bool {
		if self.isObject && self.hasProperty(method) {
			warn("this.\(method) <- \(argv)")
			let ret = self.invokeMethod(method, withArguments: argv)
			if ret == nil { return false }
			if let bool = ret?.toObject() as? Bool { return bool }
		}
		return false
		//FIXME: handle a passed-in closure so we can handle any ret-type instead of only bools ...
	}

	@discardableResult
	func tryFunc (_ method: String, _ args: AnyObject...) -> Bool { //variadic overload
		//warn("this.\(method) <- variadic AnyObject:\(args)")
		return self.tryFunc(method, argv: args)
	}

	@discardableResult
	func thisEval(_ code: String, sourceURL: String? = nil) -> JSValue {
		var excRef = JSValue().jsValueRef
		let js_code = JSStringCreateWithCFString(code as CFString)
		var source: JSStringRef? = nil
		let retValue: JSValue
		if let sourceURL = sourceURL { source = JSStringCreateWithCFString(sourceURL as CFString) }
		if let jsval = JSEvaluateScript(
			/*ctx:*/ context.jsGlobalContextRef,
			/*script:*/ js_code,
			/*thisObject:*/ JSValueToObject(context.jsGlobalContextRef, self.jsValueRef, nil),
			/*sourceURL:*/ source ?? nil, /*   this can be a module namespace identifier.... */
			/*startingLineNumber:*/ 1,
			/*exception:*/ &excRef
		) {
			retValue = JSValue(jsValueRef: jsval, in: context)
		} else if let excValue = JSValue(jsValueRef: excRef, in: context), excValue.hasProperty("sourceURL") { // "message"
			retValue = excValue
		} else {
			retValue = JSValue(nullIn: context) // exception
		}
		if source != nil { JSStringRelease(source) }
		JSStringRelease(js_code)
		return retValue
	}

}

@objc protocol AppScriptExports : JSExport { // '$.app'
	var appPath: String { get }
	var appURL: String { get }
	var resourcePath: String { get }
	var resourceURL: String { get }
	var arguments: [String] { get }
	var environment: [AnyHashable: Any] { get }
	var basename: String { get }
	var name: String { get }
	var bundleID: String { get }
	var groupID: String { get }
	var hostname: String { get }
	var architecture: String { get }
	var arches: [AnyObject]? { get }
	var platform: String { get }
	var platformVersion: String { get }
	var libraries: [String: Any] { get }

	// note that JSExported functions may _not_ use `throw`: http://openradar.appspot.com/48767173

	func registerURLScheme(_ scheme: String)
	//func registerMIMEType(scheme: String)
	func registerUTI(_ scheme: String)
	func changeAppIcon(_ iconpath: String)
	@objc(postNotification:::::) func postNotification(_ title: String?, subtitle: String?, msg: String?, id: String?, info: JSValue?)
	func postHTML5Notification(_ object: [String:AnyObject])
	func openURL(_ urlstr: String, _ app: String?)
	func doesAppExist(_ appstr: String) -> Bool

	func pathExists(_ path: String) -> Bool
	func loadAppScript(_ urlstr: String) -> JSValue?

	var localResourcePath: String { get }
	var localResourceURL: String { get }

#if DEBUG
	func evalJXA(_ script: String)
	func callJXALibrary(_ library: String, _ call: String, _ args: [AnyObject])
	@objc(reload) func loadMainScript() -> Bool
	func collectGarbage()
#endif

	@objc(eventCallbacks) var strEventCallbacks: [String: Array<JSValue>] { get } // app->js callbacks
	@objc(emit::) func strEmit(_ eventName: String, _ args: Any) -> [JSValue]
	func on(_ event: String, _ callback: JSValue) // installs handlers for app events
	var messageHandlers: [String: [JSValue]] { get set } // tab*app IPC callbacks
}

struct AppScriptGlobals {
	// global @convention(c) codes for using JavaScriptCore C-APIs
	// TODO: use dis moar so we can support Loonix without objc
	//  https://karhm.com/JavaScriptCore_C_API/
	/// https://forums.swift.org/t/what-is-the-plan-for-objc-on-non-darwin-platforms/12971
	//	https://github.com/tris-foundation/javascript/blob/master/Sources/

	// another way to do this, using JSContext.setObject w/ @convention(block)'d closures
	//    https://www.innoq.com/en/blog/ios-javascriptcore-polyfills/

	static let modSpace = "_nativeModules"

	@discardableResult
	static func loadCommonJSScript(urlstr: String, ctx: JSContextRef, cls: JSClassRef? = nil, mods: [String: AnyObject]? = nil, asMain: Bool = false) -> (JSScriptRef?, JSValueRef) {
		// loosely impl node-ish require(scriptname, ...state) -> module.exports
		let retVals: (JSScriptRef?, JSValueRef)
		// http://www.commonjs.org/specs/modules/1.0/
		// TODO: RequireJS mandates AMD define() http://requirejs.org/docs/commonjs.html

		// Note that importing unmodified packages from npm would require a lot of node shims
		//   https://github.com/swittk/Node-JS-for-JavascriptCore/blob/master/Node/JSNodeEventEmitter.m
		//   https://github.com/nodejs/node-v0.x-archive/issues/5132#issuecomment-15432598 CommonJS is ded
		//   https://github.com/node-app/Nodelike/blob/master/Nodelike/NLContext.m
		//   https://github.com/node-app/Nodelike/blob/master/Nodelike/NLFS.m
		//   https://github.com/node-app/Nodelike/blob/master/Nodelike/NLHTTPParser.m
		// might be best to bundle in node-jsc.dylib if we really want to load npm packages
		//   https://bugs.webkit.org/show_bug.cgi?id=189947
		//   https://github.com/mceSystems/node-jsc
		//		our AppSandbox definitions should be tuned to prevent _bad things_ by the node-contexts
		//       ! full fs access
		//       ! full remote net access
		//       + local unpriv port binds (node is gr8 for hosting webapps)
		//   this is basically what electron does: https://github.com/electron/node
		//   with an embedded node-jsc, we could bundle an Iodide.app ....

		// TODO: caching, loop-prevention
		// Ejecta ships a JS wrapper as require() to manage its module-space:
		//     https://github.com/phoboslab/Ejecta/blob/b3745f235a7aba6973d39a77990bb0f6eb02a413/Source/Ejecta/Ejecta.js#L136
		//			https://github.com/phoboslab/Ejecta/blob/6ff2424/Source/Ejecta/EJJavaScriptView.m#L274

		if let mods = mods, urlstr == "@MacPin" { // export our native objects & classes
			// JS module naming is BS: https://youtu.be/M3BM9TB-8yA?t=11m0s http://tinyclouds.org/jsconf2018.pdf
			//   maybe look for a custom macpin:// scheme? `macpin://natives`?
			let exports = JSObjectMake(ctx, nil, nil)!
			for (k, v) in mods {
				let modname = JSStringCreateWithCFString(k as CFString)
				if let jsv = v as? JSValue { // mod-obj is pre-bridged
					//warn("export of `\(k)`, pre-bridged type!")
					JSObjectSetProperty(ctx, exports, modname, jsv.jsValueRef, JSPropertyAttributes(kJSPropertyAttributeNone), nil)
				// TODO: check for simple-jack types havining dedicated JSValue(type:, in:)inits
				} else if v is JSExport, let bridged = JSValue(object: v, in: JSContext.current()) { // JSContext(jsGlobalContextRef: ctx)) {
					// AVAST: thar be crashes heere*. gARRRbage Collection run amuk!

					//JSValue.init(*, in:) already JSValueProtects itself ... so that's not it

					//let owned = JSManagedValue(value: bridged, andOwner: thisObject)! // let the call site be the owner
					// Erp, thisObject is not the caller, its thisfunc.bind(thisFunc) ...

					// BUG: doesn't seem to honor NS->Swift conversions for JSExported setters, props will get NSwhatever as inputs even if decl'd as swift-foundation types
					JSObjectSetProperty(ctx, exports, modname, bridged.jsValueRef, JSPropertyAttributes(kJSPropertyAttributeNone), nil)
					//JSObjectSetProperty(ctx, exports, JSStringCreateWithCFString(k as CFString), owned.value.jsValueRef, JSPropertyAttributes(kJSPropertyAttributeNone), nil)
					JSGlobalContextRetain(ctx) // protecc plz, we now hold a swift instance
				} else {
					warn("skipped export of `\(k)`, un-bridgable type!")
				}
				JSStringRelease(modname)
			}

// *: Instanciating bridged-JSValues/Contexts from @conv(c) funcs causes ARC faults indeterminately down the line (when JSC VM GC's??):
// Fixed? https://github.com/WebKit/webkit/commit/9be0bde9221db8c348511fa4bd10cbb2eaa607b7
/*
Exception Type:        EXC_BAD_ACCESS (SIGSEGV)
Exception Codes:       KERN_INVALID_ADDRESS at 0x000000000000001a
Exception Note:        EXC_CORPSE_NOTIFY
Termination Signal:    Segmentation fault: 11
Thread 0 Crashed:: Dispatch queue: com.apple.main-thread
0   com.apple.JavaScriptCore      	0x0000000101516aa9 JSC::JSLockHolder::JSLockHolder(JSC::ExecState*) + 25
1   com.apple.JavaScriptCore      	0x0000000101544419 JSGlobalContextRelease + 25
2   com.apple.JavaScriptCore      	0x000000010167222a -[JSContext dealloc] + 106
3   libobjc.A.dylib               	0x00007fff5c1a2087 (anonymous namespace)::AutoreleasePoolPage::pop(void*) + 817
4   com.apple.CoreFoundation      	0x00007fff34f77a56 _CFAutoreleasePoolPop + 22
5   com.apple.AppKit              	0x00007fff32545b11 -[NSApplication finishLaunching] + 352
6   com.apple.AppKit              	0x00007fff32545683 -[NSApplication run] + 250
7   com.github.kfix.MacPin.MacPin 	0x0000000101331267 main + 327 (main.swift:15)
8   libdyld.dylib                 	0x00007fff5cdc6015 start + 1
*/

			return (nil, exports)
		}

		// not a synthetic require, so going to source a real file
		let scriptTxt: String
		let scriptURL: String

		guard let sourceURL = getResourceURL(urlstr) else {
			warn("\(urlstr): could not be found", function: "loadCommonJSScript")
			return (nil, JSValueMakeNull(ctx))
		}

		if let source = try? String(contentsOf: sourceURL, encoding: .utf8) {
			scriptTxt = source
			scriptURL = sourceURL.absoluteString
		} else {
			warn("\(sourceURL): could not be read", function: "loadCommonJSScript")
			return (nil, JSValueMakeNull(ctx))
		}

		warn("\(scriptURL): read", function: "loadCommonJSScript")

		let contextGroup = JSContextGetGroup(ctx)
		let jsurl = JSStringCreateWithCFString(scriptURL as CFString)

		let jsErrorMsg = JSStringCreateWithCFString("" as CFString)
		var errorLine = Int32(0)
		let code = JSStringCreateWithCFString(scriptTxt as CFString)
		let script = JSScriptCreateFromString(
			contextGroup,
			jsurl, /* .sourceUrl, can also by module-namespace identifier */
			/*startingLineNumber:*/ 1,
			/*script:*/ code,
			/*errorMessage*/ UnsafeMutablePointer(jsErrorMsg),
			/*errorLine*/ &errorLine
		)

		if errorLine == 0 {
			warn("\(scriptURL): syntax checked ok", function: "loadCommonJSScript")

			// create new scope/context for the eval of the script
			let contxt = asMain ? ctx : JSGlobalContextCreateInGroup(contextGroup, cls)
			JSGlobalContextSetName(contxt, JSStringCreateWithCFString(urlstr as CFString))

			let globalObj = JSContextGetGlobalObject(contxt)
			var exception = JSValueMakeUndefined(contxt)

			// http://wiki.commonjs.org/wiki/Modules/1.1.1#Module_Context
			let module = JSObjectMake(contxt, nil, nil)
			let exports = JSObjectMake(contxt, nil, nil)
			JSObjectSetProperty(contxt, module, JSStringCreateWithCFString("exports" as CFString),
				exports, JSPropertyAttributes(kJSPropertyAttributeNone), nil)
			JSObjectSetProperty(contxt, module, JSStringCreateWithCFString("uri" as CFString), // cjs3.2
				JSValueMakeString(contxt, jsurl), JSPropertyAttributes(kJSPropertyAttributeNone), nil)

			// https://nodejs.org/api/modules.html#modules_module_filename
			let fpath = JSValueMakeString(contxt, JSStringCreateWithCFString(sourceURL.path as CFString))
			JSObjectSetProperty(contxt, module, JSStringCreateWithCFString("filename" as CFString),
				fpath, JSPropertyAttributes(kJSPropertyAttributeNone), nil)
			// https://nodejs.org/api/modules.html#modules_module_id cjs3.1
			JSObjectSetProperty(contxt, module, JSStringCreateWithCFString("id" as CFString),
				fpath, JSPropertyAttributes(kJSPropertyAttributeNone), nil)

			// https://nodejs.org/api/modules.html#modules_module_exports
			JSObjectSetProperty(contxt, globalObj, JSStringCreateWithCFString("module" as CFString),
				module, JSPropertyAttributes(kJSPropertyAttributeNone), nil)

			// https://nodejs.org/api/modules.html#modules_accessing_the_main_module
			let req = JSObjectGetProperty(contxt, globalObj, JSStringCreateWithCFString("require" as CFString), nil)
			if JSValueIsObject(contxt, req) {
				// https://nodejs.org/api/modules.html#modules_require_main
				JSObjectSetProperty(contxt, req, JSStringCreateWithCFString("main" as CFString),
					(asMain ? module : JSValueMakeUndefined(ctx)), JSPropertyAttributes(kJSPropertyAttributeNone), nil)
				// default can be undefined per https://nodejs.org/api/process.html#process_process_mainmodule
				//   not going to bother with storing the main.module ref and propagating it to all its sub-requires
			}

			// https://nodejs.org/api/modules.html#modules_exports_shortcut cjs2.
			JSEvaluateScript(contxt, JSStringCreateWithUTF8CString("""
				Object.defineProperty(this, "exports", {
					get: function () {
						return module.exports;
					}
				});
			"""), nil, nil, 1, nil) // nil this == [global] ?

			// https://nodejs.org/api/globals.html#globals_filename
			JSObjectSetProperty(contxt, globalObj, JSStringCreateWithCFString("__filename" as CFString),
				JSValueMakeString(contxt, JSStringCreateWithCFString(sourceURL.lastPathComponent as CFString)),
					JSPropertyAttributes(kJSPropertyAttributeNone), nil)

			// https://nodejs.org/api/globals.html#globals_dirname
			JSObjectSetProperty(contxt, globalObj, JSStringCreateWithCFString("__dirname" as CFString),
				JSValueMakeString(contxt, JSStringCreateWithCFString(sourceURL.pathComponents.dropLast().joined(separator: "/") as CFString)),
					JSPropertyAttributes(kJSPropertyAttributeNone), nil)

			// `this === module.exports` per https://stackoverflow.com/a/30894970/3878712
			let this = JSValueToObject(contxt, exports, nil)

			if let ret = JSScriptEvaluate(contxt, script, this, &exception) {
				retVals = (script, JSObjectGetProperty(contxt, module, JSStringCreateWithCFString("exports" as CFString), nil))
			} else if !JSValueIsUndefined(contxt, exception) {
				retVals = (nil, exception!)
			} else { //?
				retVals = (script, JSValueMakeNull(ctx)) // generates an exception if called via JS:require()
			}
		} else {
			warn("bad syntax: \(scriptURL) @ line \(errorLine)", function: "loadCommonJSScript")
			let errMessage = JSStringCopyCFString(kCFAllocatorDefault, jsErrorMsg) as String
			warn(errMessage)
			retVals = (script, JSValueMakeNull(ctx)) // generates an exception if called via JS:require()
		} // or pop open the script source-code in a new tab and highlight the offender

		JSStringRelease(code)
		JSStringRelease(jsurl)
		JSStringRelease(jsErrorMsg)
		return retVals
	}

	static let cjsrequire: JSObjectCallAsFunctionCallback = { ctx, function, thisObject, argc, args, exception in
		// https://developer.apple.com/documentation/javascriptcore/jsobjectcallasfunctioncallback
		// called as `thisObject.function(args);` within ctx

		if argc > 0 {
			if let args = args, JSValueIsString(ctx, args[0]) {
				let globalObjClass = JSClassCreate(&globalClassDef)
				let url = JSStringCopyCFString(kCFAllocatorDefault, JSValueToStringCopy(ctx, args[0], nil)) as String
				return loadCommonJSScript(urlstr: url, ctx: ctx!, cls: globalObjClass, mods: AppScriptRuntime.shared.nativeModules).1
				//	JSContext.current().nativeModules ?? globalObjClass.getProperty(modSpace)
			}
		}
		return JSValueMakeNull(ctx) // generates an exception
	}


	static let setTimeout: JSObjectCallAsFunctionCallback = { ctx, function, thisObject, argc, args, exception in
		// https://developer.mozilla.org/en-US/docs/Web/API/WindowOrWorkerGlobalScope/setTimeout
		// https://nodejs.org/en/docs/guides/timers-in-node/ https://github.com/electron/electron/issues/7079

		guard let args = args, argc > 1 else {
			return JSValueMakeUndefined(ctx)
		}

		let timeout = JSValueToNumber(ctx, args[1], exception)
		if timeout.isNaN { return JSValueMakeUndefined(ctx) }

		let gctx = JSContextGetGlobalContext(ctx) // get the global context, it should outlive us all

		var argv: [JSValueRef?] = [] // arguments: UnsafePointer<JSValueRef?>!
		for idx in 2..<(argc) {
			JSValueProtect(gctx, args[idx])
			argv.append(args[idx])
		}

		let callBack: JSObjectRef?

		if JSValueIsString(ctx, args[0]), let code = JSValueToStringCopy(ctx, args[0], exception) {  // accept stringified "functions"
			callBack = JSObjectMakeFunction(ctx, nil, 0, nil, code, nil, 0, exception)
			// FIXME: send in argv as a `arguments` named spread?
			//_ ctx: JSContextRef!, _ name: JSStringRef!, _ parameterCount: UInt32, _ parameterNames: UnsafePointer<JSStringRef?>!,
			//_ body: JSStringRef!, _ sourceURL: JSStringRef!, _ startingLineNumber: Int*32, _ exception: UnsafeMutablePointer<JSValueRef?>!
		} else if !JSValueIsNull(ctx, args[0]) && !JSValueIsUndefined(ctx, args[0]) {
			// if JSValueIsFunction(ctx, args[0]) // skips [CallbackFunction]s
			callBack = JSValueToObject(ctx, args[0], exception)
			// FIXME if callback is a property of a parent object, should parent be passed as callbackThis?
		} else {
			callBack = nil
		}

		guard let callback = callBack, JSObjectIsFunction(ctx, callback) else {
			warn("did not supply a function!", function: "setTimeout")
			return JSValueMakeUndefined(ctx)
		}

		// https://developer.mozilla.org/en-US/docs/Web/API/WindowOrWorkerGlobalScope/setInterval#The_this_problem
		//   per MDN, will *not* callback.bind(thisObj)

		//protecc any values passed into this FunctionCallback that will outlive its return to JS
		JSValueProtect(gctx, callback)

		let delayTime = DispatchTime.now() + JSValueToNumber(ctx, args[1], nil)
		warn("timeout scheduled @ \(delayTime.rawValue)", function: "setTimeout")

		DispatchQueue.main.asyncAfter(deadline: delayTime, qos: .userInteractive, flags: .enforceQoS) { [argv] in
			// https://developer.apple.com/videos/play/wwdc2015/718/?time=1380
			// WKWebView.evaluateJavascript schedules work on main thread, so we must be using it too

			warn("timeout call @ \(DispatchTime.now().rawValue)", function: "setTimeout:main")

			JSObjectCallAsFunction(gctx, callback, nil, argv.count, argv, nil)
			// FIXME calling func-properties of JSExported instances throws
			// `TypeError: self type check failed for Objective-C instance method`
			// can workaround by inst.bind(inst)ing or wrapping as an arrow/Function()

			JSValueUnprotect(gctx, callback) // kthxbai
			argv.forEach { JSValueUnprotect(gctx, $0) }
		}

		// https://developer.mozilla.org/en-US/docs/Web/API/WindowOrWorkerGlobalScope/setTimeout#Return_value
		return JSValueMakeUndefined(ctx) // FIXME: per ^ we should be returning a random number ...
		// ... but then we'd have to support cancelTimeout(timeoutID)
	}

	static let contrace: JSObjectCallAsFunctionCallback = { ctx, function, thisObject, argc, args, exception in
		//TODO: show current stack / call-site location in script
		let dump = JSContextCreateBacktrace(ctx, 5) // https://bugs.webkit.org/show_bug.cgi?id=64981
		warn("\n" + (JSStringCopyCFString(kCFAllocatorDefault, dump) as String), function: "contrace")
		return JSValueMakeUndefined(ctx) // ECMA spec for console.trace
	}

	static let conlog: JSObjectCallAsFunctionCallback = { ctx, function, thisObject, argc, args, exception in
		//TODO: colorize JS outputs

		if let args = args, argc > 0 {
			var strs: [String] = []
			for idx in (0..<argc) {
				// need to coerce to strings
				//strs.append(JSValue(jsValueRef: args[idx], in: JSContext(jsGlobalContextRef: ctx)).toString()) // reverse Objc-bridge
				//strs.append(JSValue(jsValueRef: args[idx], in: JSContext.current()).toString()) // reverse Objc-bridge
				strs.append(JSStringCopyCFString(kCFAllocatorDefault, JSValueToStringCopy(ctx, args[idx], exception)) as String)
			}
			if argc == 1 { warn(strs[0], function: "conlog"); } else { warn(strs.description, function: "conlog"); }
		} else {
			warn("", function: "conlog")
		}

		return JSValueMakeUndefined(ctx) // ECMA spec for console.log
	}

	static let conerr: JSObjectCallAsFunctionCallback = { ctx, function, thisObject, argc, args, exception in
		//TODO: colorize JS outputs

		if let args = args, argc > 0 {
			var strs: [String] = []
			for idx in (0..<argc) {
				// need to coerce to strings
				//strs.append(JSValue(jsValueRef: args[idx], in: JSContext(jsGlobalContextRef: ctx)).toString()) // reverse Objc-bridge
				//strs.append(JSValue(jsValueRef: args[idx], in: JSContext.current()).toString()) // reverse Objc-bridge
				strs.append(JSStringCopyCFString(kCFAllocatorDefault, JSValueToStringCopy(ctx, args[idx], exception)) as String)
			}

			if argc == 1 { warn(strs[0], function: "conerr"); } else { warn(strs.description, function: "conerr"); }
	        let error = NSError(domain: "MacPin", code: 4, userInfo: [ NSURLErrorKey: "JavaScript console.error",
					NSLocalizedDescriptionKey: strs.joined(separator:", ") ])
			displayError(error)
		} else {
			warn("", function: "conerr")
		}

		return JSValueMakeUndefined(ctx) // ECMA spec for console.err
	}

	static let functions: [JSStaticFunction] = [
		JSStaticFunction(name: "require", callAsFunction: cjsrequire,
			attributes: JSPropertyAttributes(kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete)),
		JSStaticFunction(name: nil, callAsFunction: nil, attributes: 0) // req'd terminator
    ] // doesn't seem to identically mmap to C-array-of-structs ...

	static let values: [JSStaticValue] = [
		//JSStaticValue(name: modSpace, getProperty: nil, setProperty: nil, attributes: 0),
		JSStaticValue(name: nil, getProperty: nil, setProperty: nil, attributes: 0) // req'd terminator
    ]

	static func injectGlobal(ctx: JSContextRef, property: String, value: JSValueRef, attrs: JSPropertyAttributes = JSPropertyAttributes(kJSPropertyAttributeNone) ) {
		let globalObj = JSContextGetGlobalObject(ctx)
		JSObjectSetProperty(ctx, globalObj, JSStringCreateWithCFString(property as CFString), value, attrs, nil)
	}

	@discardableResult
	static func injectGlobal(ctx: JSContextRef, property: String, function: JSObjectCallAsFunctionCallback!, attrs: JSPropertyAttributes = JSPropertyAttributes(kJSPropertyAttributeNone) ) -> JSObjectRef! {
		let jsfunc = JSObjectMakeFunctionWithCallback(ctx, JSStringCreateWithCFString(property as CFString), function)!
		injectGlobal(ctx: ctx, property: property, value: jsfunc, attrs: attrs)
		return jsfunc
	}

	static let initialize: JSObjectInitializeCallback = { ctx, obj in
		// this[Symbol.toStringTag] = "app"; this => [object app]

		injectGlobal(ctx: ctx!, property: "require", function: cjsrequire) // workaround for &[JSStaticFunction] uselessness
		injectGlobal(ctx: ctx!, property: "setTimeout", function: setTimeout)

		// set up our logging muxer, makes console.log print to stderr and to attached Safari Inspectors' consoles
		// https://developer.mozilla.org/en-US/docs/Web/API/console
		// https://github.com/facebook/react-native/blob/d01ab66b47a173a62eef6261e2415f0619fefcbb/Libraries/Core/InitializeCore.js#L62
		// https://github.com/facebook/react-native/blob/d01ab66b47a173a62eef6261e2415f0619fefcbb/Libraries/Core/ExceptionsManager.js#L110
		// https://github.com/facebook/react-native/blob/d01ab66b47a173a62eef6261e2415f0619fefcbb/Libraries/Utilities/RCTLog.js
		JSEvaluateScript(ctx, JSStringCreateWithCFString("""
		((conlog) => { // protecc the namespace
			const _logOriginal = console.log.bind(console);
			// decl makes sure our new .log is .name=="log"
			const log = (...args) => {
				_logOriginal.apply(console, args);
				conlog(args);
			}
			console.log = log;
			//console.log("conlog hooked");
		})(this);
		""" as CFString), JSObjectMakeFunctionWithCallback(ctx!, nil, conlog)!, nil, 1, nil)

		JSEvaluateScript(ctx, JSStringCreateWithCFString("""
		((conerr) => { // protecc the namespace
			const _errOriginal = console.err.bind(console);
			const err = (...args) => {
				_errOriginal.apply(console, args);
				conerr(args);
			}
			console.err = err;
		})(this);
		""" as CFString), JSObjectMakeFunctionWithCallback(ctx!, nil, conerr)!, nil, 1, nil)


		JSEvaluateScript(ctx, JSStringCreateWithCFString("""
		((contrace) => { // protecc the namespace
			const _traceOriginal = console.trace.bind(console);
			const trace = (...args) => {
				_traceOriginal.apply(console, args);
				contrace(args);
			}
			console.trace = trace;
		})(this);
		""" as CFString), JSObjectMakeFunctionWithCallback(ctx!, nil, contrace)!, nil, 1, nil)

		//context.globalObject.setObject(nativeModules, forKeyedSubscript: modSpace as NSString) // copied values-by-ref, but the array is stale!
		// retain(obj)
		warn("", function: "initialize")
	}

	static let finalize: JSObjectFinalizeCallback = { obj in
		// release(obj)
		warn("", function: "finalize")
	}

	// https://developer.apple.com/documentation/javascriptcore/jsclassdefinition
	static var globalClassDef = JSClassDefinition(
		version: 0, attributes: JSClassAttributes(kJSClassAttributeNoAutomaticPrototype), // shows all Object.protos but not my custom func
		//version: 0, attributes: JSClassAttributes(kJSClassAttributeNone), // only shows my custom func in the proto, none from Object
		//version: 0, attributes: JSClassAttributes(), // MPGlobalObject.__proto__: MPGlobalObject
		className: "MPGlobalObject", parentClass: nil, // nil==Object()
		//staticValues: values.withUnsafeBufferPointer { $0.baseAddress }, // works *sometimes*
		staticValues: nil, /* BUG: cannot get consistently working pointer */
		//staticFunctions: functions.withUnsafeBufferPointer { $0.baseAddress }, // works *sometimes*
		//staticFunctions: UnsafeBufferPointer(start: functions, count: functions.count).baseAddress, // never works
		//staticFunctions: functions, // is supposed to work
		staticFunctions: nil,
		/* callbacks: nil==Object.<callback> */
		initialize: initialize, finalize: finalize,
		hasProperty: nil, getProperty: nil, setProperty: nil, deleteProperty: nil,
		getPropertyNames: nil, callAsFunction: nil, callAsConstructor: nil,
		hasInstance: nil, convertToType: nil
	)
}

class AppScriptRuntime: NSObject, AppScriptExports  {
	static let legacyGlobal = "$" //sorry JQuery ...
	static let legacyAppGlobal = "app" // => $.app
	static let legacyAppFile = "app" // => site/app.js
	static let mainScriptFile = "main" // => site/main.js
	static let shared = AppScriptRuntime() //global: AppScriptRuntime.legacyGlobal) // create & export the singleton

	enum ScriptStates {
		case Unloaded, Promised, Evaluated, Errored
	}

	var scriptState: ScriptStates = .Unloaded

	var contextGroup = JSContextGroupCreate()
	var context: JSContext
	var jsdelegate: JSValue
	let exports: JSValue

	var arguments: [String] { return ProcessInfo.processInfo.arguments }
	var environment: [AnyHashable: Any] { return ProcessInfo.processInfo.environment }
	var appPath: String { return Bundle.main.bundlePath }
	var appURL: String { return Bundle.main.bundleURL.absoluteString }
	var resourcePath: String { return Bundle.main.resourcePath ?? String() }
	var resourceURL: String { return Bundle.main.resourceURL?.absoluteString ?? String() }
	var hostname: String { return ProcessInfo.processInfo.hostName }
	var bundleID: String { return Bundle.main.bundleIdentifier ?? String() }

#if os(OSX)
	var name: String { return NSRunningApplication.current.localizedName ?? String() }
	let platform = "OSX"
#elseif os(iOS)
	var name: String { return Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? String() }
	let platform = "iOS"
#endif

	var basename: String { return Bundle.main.object(forInfoDictionaryKey: "CFBundleExecutable") as? String ?? String() }

	var groupID: String {
		if self.bundleID.hasSuffix(".\(self.basename)") {
			return String(self.bundleID.dropLast(self.basename.count + 1))
	    }
	    return String()
	}

	var localResourceURL: String {
		if !self.groupID.isEmpty {
			if let localURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: self.groupID) {
				// https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_security_application-groups
				// print("\(sharedURL)") // could load self-modified, user customized, main.js's from here
				return localURL.absoluteString
				// would need to make sure require() & injectCSS/JS's will also use this overlay
			}
		}
	    return String()
	}

	var localResourcePath: String {
		if !self.groupID.isEmpty {
			if let localURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: self.groupID) {
				// https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_security_application-groups
				// print("\(sharedURL)") // could load self-modified, user customized, main.js's from here
				return localURL.path
				// would need to make sure require() & injectCSS/JS's will also use this overlay
			}
		}
	    return String()
	}

	// http://nshipster.com/swift-system-version-checking/
	var platformVersion: String { return ProcessInfo.processInfo.operatingSystemVersionString }

	var libraries: [String: Any] {
		var infos: [String: Any] = [:]
		for bun in ["com.apple.WebKit", "com.apple.JavaScriptCore", "com.github.kfix.MacPin.MacPin"] {
			if let bunDict = Bundle(identifier: bun)?.infoDictionary { infos[bun] = bunDict }
		}
		infos["WebKit.dylib"] = "\(WebKit_version)"
		infos["JavaScriptCore.dylib"] = "\(JavaScriptCore_version)"
		infos["Safari.app"] = "\(Safari_version)"
		return infos
	}

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

	var nativeModules: [String: AnyObject] = [:] // : JSExport & JSValue

	let globalObjClass = JSClassCreate(&AppScriptGlobals.globalClassDef)

	override init() {

		if JavaScriptCore_version >= (603, 1, 30) {
			/* Safari 10.1 == WK/JSC 603.1.30 first version for ES6 support */
		} else {
			assertionFailure("""
			JSC \(JavaScriptCore_version) < 603.1.30
			**********************************************************************************************
			System's JavaScriptCore.framework is obsolete. Minimum requirement is satisfied by Safari 10.1
			Downloads are available through Software Update:
			  https://www.jamf.com/jamf-nation/third-party-products/598/safari-for-yosemite?view=info
			  https://www.jamf.com/jamf-nation/third-party-products/599/safari-for-el-capitan?view=info
			  https://www.jamf.com/jamf-nation/third-party-products/660/safari-for-sierra?view=info
			  https://www.jamf.com/jamf-nation/third-party-products/131/safari?view=info
			See https://support.apple.com/en-us/HT207921 for its release notes.
			**********************************************************************************************

			""")
		}

		// lets create the global context with a custom-classed globalObj
		// all app-scripts and cjs-mods will get their own contexts when evaluated, but within the same context-group
		context = JSContext(jsGlobalContextRef: JSGlobalContextCreateInGroup(contextGroup, globalObjClass))

		jsdelegate = JSValue(newObjectIn: context) //default property-less delegate obj

#if SAFARIDBG
		// https://github.com/WebKit/webkit/commit/e9f4a5ef360d47b719f7391fe02d28ff1e63fc7://github.com/WebKit/webkit/commit/e9f4a5ef360d47b719f7391fe02d28ff1e63fc7e
		// https://github.com/WebKit/webkit/blob/master/Source/JavaScriptCore/API/JSContextPrivate.h
		context._remoteInspectionEnabled = true
		// http://asciiwwdc.com/2014/sessions/512  https://developer.apple.com/videos/play/wwdc2014/512/
		//context.logToSystemConsole = true // console.*(...) => `CONSOLE LOG ...`
#else //if os(OSX)
		context._remoteInspectionEnabled = false
		//context.logToSystemConsole = false
#endif
		// make thrown exceptions popup an nserror displaying the file name and error type,
		//   which will be shunted to console.log
		context.exceptionHandler = { context, exception in
			let errstr = exception?.toString()
			let line = exception?.forProperty("line").toNumber()
			let column = exception?.forProperty("column").toNumber()
			let source = exception?.forProperty("sourceURL").toString()
			let stack = exception?.forProperty("stack").toString()
			let message = exception?.forProperty("message").toString()
			let type = exception?.forProperty("name").toString()
			let error = NSError(domain: "MacPin", code: 4, userInfo: [
				NSURLErrorKey: context?.name as Any,
				NSLocalizedDescriptionKey: "<\(source ?? ""):\(line ?? -1):\(column ?? -1)> \(type ?? "noType"): \(message ?? "?")\n\(stack ?? "?")"
				// exception seems to be Error.toString(). I want .message|line|column|stack too
			])
			//if !WKInspectorIsConnected(inspectorRef) how do I get inspectorref of a JSContext ??
			displayError(error) // FIXME: would be nicer to pop up an inspector pane or tab to interactively debug this
			context?.exception = exception //default in JSContext.mm
			return // gets returned to evaluateScript()?
		}
		// JSC will always pass exceptions to console.* so they can bubble up to any RemoteInspectors (Safari->Develop)

		//context._debuggerRunLoop = CFRunLoopRef // FIXME: make a new thread for REPL and Web Inspector console eval()s
		JSRemoteInspectorSetLogToSystemConsole(false)

		exports = JSValue(newObjectIn: context)

		super.init() // all undef'd props assigned, now we can be an NSObject
		context.name = "\(self.name) \(self.description)"

		if #available(macOS 10.14.5, *, iOS 13) {
			if JavaScriptCore_version >= (608, 1, 8) {
				context.moduleLoaderDelegate = self // `import`
			}
		}

		// aggregate our exposable classes & instances for `require("@MacPin")`
		// TODO: use the Reflection to find all .wrapSelf()s
		// for k in exportedTypes {}; for k in wrappedTypes {}
		nativeModules = [
			// https://electronjs.org/docs/api/app
			"app":				JSValue(object: self, in: context)
			//,"app2":			self // crash bandicoot (because of JSC GC?)s
			// https://electronjs.org/docs/api/browser-window
			,"BrowserWindow":	BrowserController.self.wrapSelf(context)
			// https://electronjs.org/docs/api/browser-view
			,"WebView":			JSValue(object: MPWebView.self, in: context)
		]

		context.globalObject.thisEval("""
			let window = this; // https://github.com/nodejs/node/issues/1043
			let global = this; // https://github.com/browserify/insert-module-globals/pull/48#issuecomment-186291413
		""")
	}

	override var description: String { return "<\(type(of: self))> [\(appPath)]" }

	// run app.js under v1 MacPin appscript namespace ($.*)
	@objc func loadSiteApp() -> Bool {
		let app = (Bundle.main.object(forInfoDictionaryKey:"MacPin-AppScriptName") as? String) ?? AppScriptRuntime.legacyAppFile

		//  app-scripts will also have the `$.app` namespace mounted for run-time checks ($.app.platform)
		context.globalObject.setObject(exports, forKeyedSubscript: AppScriptRuntime.legacyGlobal as NSString)

		let appExport = exports.objectForKeyedSubscript(AppScriptRuntime.legacyAppGlobal as NSString)
		if let appExport = appExport, !appExport.isUndefined && !appExport.isNull {
			// don't re-export if $.app is already exported
		} else {
			exports.setObject(self, forKeyedSubscript: AppScriptRuntime.legacyAppGlobal as NSString) // because legacy
			// https://bugs.swift.org/browse/SR-6476 can't do appExport = self
			// http://rbereski.info/2015/05/15/java-script-core/
		}

		if let app_js = Bundle.main.url(forResource: app, withExtension: "js") {
			if let jsval = loadAppScript(app_js.description) {
				if jsval.isObject {
					// use legacy API convention
					warn("\(app_js) loaded as AppScriptGlobals.shared.jsdelegate")
					jsdelegate = jsval
					scriptState = .Evaluated
					return true
				}
				warn("failed to execute app.js!")
				scriptState = .Errored
			}
		}

		warn("failed to load app.js!")
		return false
	}

	// run main.js under v2 MacPin appscript namespace (* = require(@MacPin))
	@objc func loadMainScript() -> Bool {
		var jsval: JSValue

		let app = (Bundle.main.object(forInfoDictionaryKey:"MacPin-MainScriptName") as? String) ?? AppScriptRuntime.mainScriptFile
		// allows packager to override the script's basename away from .mainScriptFile("app")

		let local_app_js = URL(fileURLWithPath: "\(self.localResourcePath)/\(self.basename)/\(AppScriptRuntime.mainScriptFile).js")

		if #available(macOS 10.14.5, *, iOS 13), false {
			// false-blocking since we don't have import.meta injections implemented for JSContext yet.
			// is still letting iOS (sim) 12.4 thru!!

			guard JavaScriptCore_version >= (608, 1, 8) else { return false }
			/*
				https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Statements/import.meta
				node docs also say they impl'd import.meta: https://nodejs.org/api/esm.html#esm_import_meta
					The import.meta metaproperty is an Object that contains the following property:
						url <string> The absolute file: URL of the module.
				despite their admonition, should add some njs legacy back too:
					const __filename = fileURLToPath(import.meta.url);
					const __dirname = dirname(__filename);
			*/

			if (try? local_app_js.checkResourceIsReachable()) ?? false { // try overridden name
				(_, jsval) = importJSScript(local_app_js.absoluteString, asMain: true, asModule: true)
			} else if let app_js = Bundle.main.url(forResource: app, withExtension: "js") {
			    warn("loading esm")
				(_, jsval) = importJSScript(app_js.absoluteString, asMain: true, asModule: true)
				// never gets returned to here?!!
			} else {
				warn("failed to load main.js!")
				return false
			}

			guard jsval.isObject, !jsval.hasProperty("exception") else {
				// TODO: dump exception
				scriptState = .Errored
				warn("failed to import(main.js)!")
				return false
			}

			scriptState = .Promised //jsval should be a Promise object (asModule:true)

			jsval.invokeMethod("then", withArguments: [
				{ module in
					warn("import(main.js) resolved!")
					self.scriptState = .Evaluated
					//  asMain:true should have put all module state into main scope,
					//   don't need to destructure module's exports explicitly here
				} as PromiseThen,
				{ error in
					warn(error)
					warn("import(main.js) failed to resolve!")
					self.scriptState = .Errored
				} as PromiseThen
			])

			return true
			// AppDelegate will have to keep checking for !Promised to be set
			//   by our PromiseThen....
		}

		if (try? local_app_js.checkResourceIsReachable()) ?? false {
			(_, jsval) = importCommonJSScript(local_app_js.absoluteString, asMain: true)
		} else if let app_js = Bundle.main.url(forResource: app, withExtension: "js") {
			(_, jsval) = importCommonJSScript(app_js.absoluteString, asMain: true)
		} else {
			warn("failed to load main.js!")
			return false
		}

		guard jsval.isObject, !jsval.hasProperty("exception") else {
			// TODO: dump exception
			scriptState = .Errored
			warn("failed to execute main.js!")
			return false
		}

		jsdelegate = JSValue(nullIn: self.context)
		warn("main.js executed!")
		scriptState = .Evaluated
		return true
	}

	@discardableResult
	@available(macOS 10.14.5, *, iOS 13) // ensures we only weakly link to JSC::JSScript symbols
	// this is still throwing in the 12.4 simulator ...
	func loadAppJSScript(_ urlstr: String) -> JSValue? {
		let jsval: JSValue

		guard let sourceURL = getResourceURL(urlstr) else {
			warn("\(urlstr): could not be found", function: "loadAppJSScript")
			return nil
		}

		if (try? sourceURL.checkResourceIsReachable()) ?? false {
			(_, jsval) = importJSScript(sourceURL.absoluteString, asMain: true, asModule: true)
		} else {
			return nil
		}

		// check for error
        if jsval.isObject && !jsval.hasProperty("exception") {
			jsdelegate = jsval
			return jsval
		}

		return nil
	}

	@discardableResult
	func loadAppScript(_ urlstr: String) -> JSValue? {
		guard let sourceURL = getResourceURL(urlstr) else {
			warn("\(urlstr): could not be found", function: "loadAppScript")
			return nil
		}

		guard let source = try? String(contentsOf: sourceURL, encoding: .utf8) else {
			warn("\(sourceURL): could not be read", function: "loadAppScript")
			return nil
		}

		warn("\(sourceURL): read")

		let jsurl = JSStringCreateWithCFString(sourceURL.absoluteString as CFString)
		let jsErrorMsg = JSStringCreateWithCFString("" as CFString)
		var errorLine = Int32(0)
		let script = JSScriptCreateFromString(
			/*group*/ contextGroup,
			/*url*/ jsurl,
			/*startingLineNumber:*/ 1,
			/*script:*/ JSStringCreateWithCFString(source as CFString),
			/*errorMessage*/ UnsafeMutablePointer(jsErrorMsg),
			/*errorLine*/ &errorLine
		)

		if errorLine != 0 {
			warn("bad syntax: \(sourceURL) @ line \(errorLine)")
			let errMessage = JSStringCopyCFString(kCFAllocatorDefault, jsErrorMsg) as String
			warn(errMessage) // WISH: pop open the script source-code in a new tab and highlight the offender
			return nil
		}

		warn("\(sourceURL): syntax checked ok")

		let contxt = context.jsGlobalContextRef // want to share scope with console & inspectors

		let globalObj = JSContextGetGlobalObject(contxt)
		var exception = JSValueMakeUndefined(contxt)

		// `this` === module.exports in node.js, in electron main.js this==[[main-process]].window
		let this = globalObj //JSValueToObject(contxt, exports, nil)

		if let ret = JSScriptEvaluate(contxt, script, this, &exception) {
			return JSValue(jsValueRef: ret, in: context)
		} else if !JSValueIsUndefined(contxt, exception) {
			return JSValue(jsValueRef: exception!, in: context)
		}

		return nil
	}

	@discardableResult
	@objc func loadCommonJSScript(_ urlstr: String, asMain: Bool = false) -> JSValue {
		// just a bridgeable-wrapper for JSContext.loadCommonJSScript
		return JSValue(
			jsValueRef: AppScriptGlobals.loadCommonJSScript(urlstr: urlstr, ctx: context.jsGlobalContextRef,
						cls: globalObjClass, mods: nativeModules, asMain: asMain).1,
			in: context
		)
	}

	@discardableResult
	@nonobjc func importCommonJSScript(_ urlstr: String, asMain: Bool = false) -> (JSScriptRef?, JSValue) {
		let (script, value) = AppScriptGlobals.loadCommonJSScript(urlstr: urlstr, ctx: context.jsGlobalContextRef,
									cls: globalObjClass, mods: nativeModules, asMain: asMain)
		warn("loaded \(urlstr) script - main-scope:\(asMain)")
		return ( script, JSValue(jsValueRef: value, in: context) )
	}

	@discardableResult
	@available(macOS 10.14.5, *, iOS 13) // ensures we only weakly link to JSC::JSScript symbols
	@nonobjc func importJSScript(_ urlstr: String, asMain: Bool = false, asModule: Bool = false) -> (JSScript?, JSValue) {
/*
		if JavaScriptCore_version >= (608, 3, 10) {
			// Safari 13 == JSC supports esm import
		} else {
			assertionFailure("""
			JSC \(JavaScriptCore_version) < 608.3.10
			**********************************************************************************************
			This app's JavaScriptCore.framework cannot import *.esm. Minimum requirement is satisfied by Safari 13
			""")
		}
*/

		guard let sourceURL = getResourceURL(urlstr) else {
			warn("\(urlstr): could not be found")
			return (nil, JSValue(nullIn: self.context) )
		}

		guard let source = try? String(contentsOf: sourceURL, encoding: .utf8) else {
			warn("\(sourceURL): could not be read")
			return (nil, JSValue(nullIn: self.context) )
		}

		guard let script = try? JSScript(
			of: (asModule) ? .module : .program,
			// .module returns a Promise, just like a dynamic `import('./foo.js')`
			//    it also enables the import keyword within the script
			// dynamic `import()` is available for any kind of JSScript/JSContext
			withSource: source,
			andSourceURL: sourceURL,
			andBytecodeCache: nil,
			in: self.context.virtualMachine
		) else {
			warn("script \(urlstr) failed to load or compile!")
			return (nil, JSValue(nullIn: self.context) )
		}

		let contxt = (asMain) ? self.context : JSContext(virtualMachine: self.context.virtualMachine)!

		guard let value = contxt.evaluateJSScript(script) else {
			return (script, JSValue(nullIn: self.context) )
		}

		warn("loaded \(urlstr) script - main-scope:\(asMain) - module:\(asModule)")
		// if asModule, should have another defer:false option so we can return the Promised value?
		// asModule:true doesn't seem to finish the return ....
		//return ( script, value )
			return (script, JSValue(nullIn: self.context) )
	}

	func resetStates() {
		jsdelegate = JSValue(nullIn: context)
		eventCallbacks = eventCallbacks.filter { $0.0 == .printToREPL }
		messageHandlers = [:]
	}

	func doesAppExist(_ appstr: String) -> Bool {
#if os(OSX)
		if LSCopyApplicationURLsForBundleIdentifier(appstr as CFString, nil) != nil { return true }
#elseif os(iOS)
	// https://www.hackingwithswift.com/example-code/system/how-to-check-whether-your-other-apps-are-installed
	// https://medium.com/@guanshanliu/lsapplicationqueriesschemes-4f5fa9c7d240
		if let appurl = NSURL(string: "\(appstr)://") { // installed bundleids are usually (automatically?) usable as URL schemes in iOS
			if UIApplication.shared.canOpenURL(appurl as URL) { return true }
		}
#endif
		return false
	}

	func pathExists(_ path: String) -> Bool { return FileManager.default.fileExists(atPath: (path as NSString).expandingTildeInPath) }

	func openURL(_ urlstr: String, _ appid: String? = nil) {
		if let url = NSURL(string: urlstr) {
#if os(OSX)
			if let appid = appid, appid != "undefined" {
				NSWorkspace.shared.open([url as URL], withAppBundleIdentifier: appid, options: .default, additionalEventParamDescriptor: nil, launchIdentifiers: nil)
			} else {
				NSWorkspace.shared.open(url as URL)
			}
			//options: .Default .NewInstance .AndHideOthers
			// FIXME: need to force focus on appid too, already launched apps may not pop-up#elseif os (iOS)
#elseif os(iOS)
			// iOS doesn't allow directly launching apps, must use custom-scheme URLs and X-Callback-URL
			//  unless jailbroken http://stackoverflow.com/a/6821516/3878712
			if let urlp = NSURLComponents(url: url as URL, resolvingAgainstBaseURL: true) {
				if let appid = appid { urlp.scheme = appid } // assume bundle ID is a working scheme
				UIApplication.shared.openURL(urlp.url!)
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

		if let icon_url = getResourceURL(iconpath) {
			// path was a url, local or remote
			Application.shared.applicationIconImage = NSImage(contentsOf: icon_url)
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

	// TOIMPL: https://electronjs.org/docs/api/notification extend a Notification() shim
	@objc(postNotification:::::) func postNotification(_ title: String?, subtitle: String?, msg: String?, id: String?, info: JSValue?) {

		var infoDict: [String: Any] = [:]
		if let object = info, object.isObject, let jsdict = object.toDictionary() as? [String: Any] {
			infoDict = jsdict
		}

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
		note.userInfo = infoDict
		NSUserNotificationCenter.default.deliver(note)
		// these can be listened for by all: http://pagesofinterest.net/blog/2012/09/observing-all-nsnotifications-within-an-nsapp/
#elseif os(iOS)
		let note = UILocalNotification()
		note.alertTitle = title ?? ""
		note.alertAction = "Open"
		note.alertBody = "\(subtitle ?? String()) \(msg ?? String())"
		note.fireDate = Date()
		if let id = id { note.userInfo = [ "identifier" : id ] }
		UIApplication.shared.scheduleLocalNotification(note)
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
		//  https://developer.apple.com/library/iad/documentation/AppleApplications/Conceptual/SafariJSProgTopics/Articles/SendingNotifications.html
#if os(OSX)
		var infoDict: [String: Any] = [:]
		let note = NSUserNotification()
		for (key, value) in object {
			switch value {
				case let title as String where key == "title": note.title = title // minimum requirement
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
				default:
					warn("extra info: `\(key): \(value)`")
					infoDict[key] = value
			}
		}
		warn(obj: infoDict)
		note.userInfo = infoDict
		note.soundName = NSUserNotificationDefaultSoundName // something exotic?
		NSUserNotificationCenter.default.deliver(note)
#elseif os(iOS)
		let note = UILocalNotification()
		note.alertAction = "Open"
		note.fireDate = Date()
		for (key, value) in object {
			switch value {
				case let title as String where key == "title": note.alertTitle = title
				case let body as String where key == "body": note.alertBody = body
				case let tag as String where key == "tag": note.userInfo = [ "identifier" : tag ]
				//case let icon as String where key == "icon": loadIcon(icon)
				default: warn("unhandled param: `\(key): \(value)`")
			}
		}
		UIApplication.shared.scheduleLocalNotification(note)
#endif
	}

	func allowNotificationsFor(_ urlstr: String) {
		/* WebNotifier.shared.authorize_origin(URL(string: urlstr)) */
	}

	func REPL() -> Prompter? {
#if os(OSX)
		ProcessInfo.processInfo.disableSuddenTermination() // ensure closed window won't kill this prompter if still active
#endif
		var stderr = FileHandle.standardError
		// ^ stderr is unbuffered and is where warn() prints too

		return Prompter.termiosREPL(
			{ [unowned self] (line: String) -> Void in
				let val = self.context.evaluateScript(line)
				if self.context.exception != nil {
					if let str = self.context.exception.toString()
					, let typ = self.context.exception.forProperty("name").toString()
					, let msg = self.context.exception.forProperty("message").toString()
					, let det = self.context.exception.toDictionary() {
						print("\(str)", to: &stderr)
						//warn(obj: det) // stack of error
						//if str == "SyntaxError: Unexpected end of script" => Prompt.readNextLine?
					}
					self.context.exception = nil // we've handled this
				}

				if let rets = self.emit(.printToREPL, val as Any, true) { //handler, expression, colorize
					rets.forEach { ret in
						if let retstr = ret?.toString() { print(retstr, to: &stderr) }
					}
				} else if let val = val as? JSValue { // no REPLprint handler, just eval and dump
					// FIXME: instead of waiting on the events returns, expose a repl object to the runtime that can be replaced
					//  if replaced with a callable func, we will print(`repl.writer(result)`)
					//   https://nodejs.org/dist/latest/docs/api/repl.html#repl_customizing_repl_output
					//	 https://nodejs.org/dist/latest/docs/api/repl.html#repl_custom_evaluation_functions
					print(val, to: &stderr)
					// !val.isUndefined, self.context.assigntoKey("_", val)
						// https://nodejs.org/dist/latest/docs/api/repl.html#repl_assignment_of_the_underscore_variable
					// return val??  then abort(val) could do something special?
				} else {
					// TODO: support multi-line input
					//	https://nodejs.org/dist/latest/docs/api/repl.html#repl_recoverable_errors
					print("null [not-bridged]", to: &stderr)
				}
			},
			ps1: #file,
			ps2: #function,
			abort: { () -> (()->Void)? in
				// EOF'd by Ctrl-D
#if os(OSX)
				return {
					// this final closure is run by the invoker (termiosREPL) right after it tears down the prompter/TTY
					stderr.closeFile()
					ProcessInfo.processInfo.enableSuddenTermination()
					warn("got EOF from stdin")

					NSApp.reply(toApplicationShouldTerminate: true) // now close App if this was deferring a pre-existing UI terminate()

					if isatty(0) == 1 {
						// an interactive-stdin TTY is in use, so the EOF came from a user
						warn("stopping interactive app")
						NSApplication.shared.terminate(self) // effectively nonreturning!
					}
				}
#endif
				return nil
			}
		) //termiosREPL
	} //REPL

	func collectGarbage() {
		JSGarbageCollect(context.jsGlobalContextRef)
	}

	func evalJXA(_ script: String) {
		// FIXME: force a confirmation panel with printout of script and func+args to be called.....
#if os(OSX)
		var error: NSDictionary?
		let osa = OSAScript(source: script, language: OSALanguage(forName: "JavaScript"))
		if let output = osa.executeAndReturnError(&error) {
			warn(output.description)
		} else if (error != nil) {
			warn("error: \(error ?? [:])")
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

	var eventCallbacks: [AppScriptEvent: Array<JSValue>] = [:]
	var strEventCallbacks: [String: Array<JSValue>] {
		get {
			return Dictionary(uniqueKeysWithValues:
				zip(
					eventCallbacks.keys.map({$0.rawValue}),
					eventCallbacks.values
				)
			)
		}
	}

	@discardableResult
	// addEventListener is functionally the same
	func on(_ eventName: String, _ callback: JSValue) { // installs handlers for app events
		guard let ev = AppScriptEvent(rawValue: eventName),
			!callback.isNull && !callback.isUndefined &&
			!eventCallbacks[ev, default: []].contains(callback) && callback.hasProperty("call") else {
				warn("invalid event name or uncallable object supplied")
				return
		}
		warn(ev.description)

		// ensure callback can be garbage collected by JS after self.deinit
		// let ownedCB = JSManagedValue(mangaged: callback)
		// JSContext.current.virtualMachine.addManagedReference(ownedCB, withOwner: self)

		eventCallbacks[ev, default: []] += [callback] // [ownedCB]
		//warn(eventCallbacks[ev, default: []].description)
	}

	@discardableResult
	func strEmit(_ eventName: String, _ args: Any) -> [JSValue] {
		guard let event = AppScriptEvent(rawValue: eventName) else { return [] } // ignore invalid event names
		guard let ret = emit(event, args)?.flatMap({$0 as? JSValue}) else { return [] }
		//warn("\(event) <- \(args) -> \(ret)")
		return ret
	}

	@discardableResult
	func emit(_ event: AppScriptEvent, _ args: Any...) -> [JSValue?]? { //varargs
		return emit(event, args)
	}

	@discardableResult
	func emit(_ event: AppScriptEvent, _ args: [Any] = []) -> [JSValue?]? {
		if let cbs = eventCallbacks[event] {
			return cbs.map { cb in cb.call(withArguments: args) }
		} else if self.jsdelegate.isObject && self.jsdelegate.hasProperty(event.rawValue) {
			return [ JSValue(bool: self.jsdelegate.tryFunc(event.rawValue, argv: args), in: context) ] //compat with old stuff
		} else {
			return nil
		}
	}

	func anyHandled(_ event: AppScriptEvent, _ args: Any...) -> Bool { // needs cmp arg
		// see if any of the event callbacks returned a trueish object
		return !(
			emit(event, args)?.filter( { $0?.toBool() ?? false } ) ?? []
		).isEmpty
	}

	var messageHandlers: [String: [JSValue]] = [:]
}

enum AppScriptReactions: CustomStringConvertible {
	var description: String { return "\(type(of: self)).\(self)" }
	// TODO: how to describe allowed arguments?
	// cases can be tuples: https://github.com/OAuthSwift/OAuthSwift/blob/master/Sources/OAuthWebViewController.swift#L64
	//   each declared event is like an anon-struct
	//     case launchURL(url: URL); case printToREPL(result: Any)
	// but then the emit() implementation has to have a specific case for all events to unpack their specific tuples for the call into JS
	//   case launchURL(let url):
	//		AppScriptRuntime.shared.eventHandlers[event.rawValue].callAsFunction(args: [url])
	//	any way to spread the tuple comps generically?
	//		eventArgs = Mirror(reflecting: event).children.allValues // makes [Any]
	//		AppScriptRuntime.shared.eventHandlers[event.rawValue].callAsFunction(args: eventArgs)

	case launchURL(url: URL)
	case printToREPL(result: Any)
	case printToHTMLREPL(result: Any)
}

enum AppScriptEvent: String, CustomStringConvertible, CaseIterable {
	var description: String { return "\(type(of: self)).\(self.rawValue)" }

	case /* legacy MacPin event names */
		launchURL, // url
		handleClickedNotification, // title, subtitle, message, idstr
		postedDesktopNotification, // note, tab
		handleDragAndDroppedURLs, // urls -> Bool
		AppWillFinishLaunching, // AppUI
		AppFinishedLaunching, // url...
		printToREPL, // result
		printToHTMLREPL, // result
		tabTransparencyToggled, // transparent, tab
		AppShouldTerminate, // AppUI
		handleUserInputtedInvalidURL, // urlstr, tab
		handleUserInputtedKeywords, // urlstr, tab

		// TODO: these should be in BrowsingEvents
		// WKNavigationDelegate, WebViewDelegates
		networkIsOffline, //url, tab
		decideNavigationForURL, // url, tab, targetIsMainFrame
		decideNavigationForClickedURL, // url, tab, targetIsMainFrame
		receivedRedirectionToURL, // url, tab
		decideNavigationForMIME, // mime, url, webview -> Bool
		receivedCookie, // tab, cookieName, cookieValue
		handleUnrenderableMIME, // mime, url, filename, tab
		decideWindowOpenForURL, // url, tab
		didWindowOpenForURL, // url, newTab, tab
		didWindowClose // tab


// TOIMPL: https://electronjs.org/docs/api/app#events
}

@objc extension AppScriptRuntime: JSModuleLoaderDelegate {
	// TODO: support file://**.mjs imports
	func context(_ context: JSContext!, fetchModuleForIdentifier identifier: JSValue!, withResolveHandler resolve: JSValue!, andRejectHandler reject: JSValue!) {
		warn(identifier)
		// https://github.com/WebKit/webkit/blob/master/Source/JavaScriptCore/API/tests/testapi.mm JSContextFetchDelegate
		// JSScript v1 https://github.com/WebKit/webkit/commit/16bf7415addce141c0c5bfe91d53d8bea3929fa9
		// JSScript v2 https://github.com/WebKit/webkit/commit/105499e40a416befe631f0897c5d8047db195fff
		// https://trac.webkit.org/changeset/247403/webkit
	}

	func willEvaluateModule(_ url: NSURL) { warn(url); }
	func didEvaluateModule(_ url: NSURL) { warn(url); }
}
