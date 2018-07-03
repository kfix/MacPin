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
import JavaScriptCore // https://github.com/WebKit/webkit/tree/master/Source/JavaScriptCore/API
import WebKitPrivates

import XMLHTTPRequest // https://github.com/Lukas-Stuehrk/XMLHTTPRequest

#if arch(x86_64) || arch(i386)
import Prompt // https://github.com/neilpa/swift-libedit
#endif

import UserNotificationPrivates
//import SSKeychain // https://github.com/soffes/sskeychain

/*

extension NSObject: JSExport {
	static func extend2js(mountObj: JSValue, helpers: String? = nil) { // for constructors
		let classinstance = JSValue(object: self.type, inContext: mountObj.context)
		if let helpers = helpers { classinstance.thisEval(helpers) }
		mountObj.setValue(classinstance, forProperty: className)
	}
}

*/

extension JSContext {
	func injectGlobal(property: String, function: JSObjectCallAsFunctionCallback!) {
		let globalObj = JSContextGetGlobalObject(self.jsGlobalContextRef)
		let jsfunc = JSObjectMakeFunctionWithCallback(self.jsGlobalContextRef, JSStringCreateWithCFString(property as CFString), function)
    	JSObjectSetProperty(self.jsGlobalContextRef, globalObj, JSStringCreateWithCFString(property as CFString), jsfunc, JSPropertyAttributes(kJSPropertyAttributeNone), nil)
	}

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
		var source: JSStringRef? = nil
		if let sourceURL = sourceURL { source = JSStringCreateWithCFString(sourceURL as CFString) }
		if let jsval = JSEvaluateScript(
			/*ctx:*/ context.jsGlobalContextRef,
			/*script:*/ JSStringCreateWithCFString(code as CFString),
			/*thisObject:*/ JSValueToObject(context.jsGlobalContextRef, self.jsValueRef, nil),
			/*sourceURL:*/ source ?? nil,
			/*startingLineNumber:*/ 1,
			/*exception:*/ &excRef
		) {
			return JSValue(jsValueRef: jsval, in: context)
		} else if let excValue = JSValue(jsValueRef: excRef, in: context), excValue.hasProperty("sourceURL") { // "message"
			return excValue
		}
		return JSValue(nullIn: context) // exception
	}

}

@objc protocol AppScriptConsoleExports: JSExport {
	func log(_ msg: String)
}

class AppScriptConsole: NSObject, AppScriptConsoleExports {
	static func extend(_ context: JSContext, _ natives: String) {
		// https://github.com/facebook/react-native/blob/d01ab66b47a173a62eef6261e2415f0619fefcbb/Libraries/Core/InitializeCore.js#L62
		// https://github.com/facebook/react-native/blob/d01ab66b47a173a62eef6261e2415f0619fefcbb/Libraries/Core/ExceptionsManager.js#L110
		// https://github.com/facebook/react-native/blob/d01ab66b47a173a62eef6261e2415f0619fefcbb/Libraries/Utilities/RCTLog.js
		context.evaluateScript("""
			console._logOriginal = console.log.bind(console);
			console.log = (...args) => {
				console._logOriginal.apply(console, args);
				\(natives).log(args);
			}
			console.log("\(natives) hooked");
		""")
	}

	func log(_ msg: String) {
		// https://github.com/facebook/react-native/blob/da7873563bff945086a70306cc25fa4c048bb84b/React/CxxBridge/RCTJSCHelpers.mm
		warn(msg)
		// console.log => undefined
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
	func loadCommonJSScript(_ urlstr: String) -> JSValue
	// static func // exported as global JS func
#if DEBUG
	func evalJXA(_ script: String)
	func callJXALibrary(_ library: String, _ call: String, _ args: [AnyObject])
	@objc(reload) func loadSiteApp() -> Bool
#endif
	@objc(eventCallbacks) var strEventCallbacks: [String: Array<JSValue>] { get } // app->js callbacks
	@objc(emit::) func strEmit(_ eventName: String, _ args: Any) -> [JSValue]
	func on(_ event: String, _ callback: JSValue) // installs handlers for app events
	var messageHandlers: [String: [JSValue]] { get } // tab*app IPC callbacks
}

struct AppScriptGlobals {
	// global codes for using JavaScriptCore C-APIs

	@discardableResult
	static func loadCommonJSScript(urlstr: String, ctx: JSContextRef, cls: JSClassRef? = nil) -> JSValueRef {
		// loosely impl node-ish require(scriptname, ...state) -> module.exports
		// http://www.commonjs.org/specs/modules/1.0/
		// TODO: RequirJS mandates add'l define() http://requirejs.org/docs/commonjs.html

		// actually importing things from npm would require a lot of node shims
		// https://github.com/swittk/Node-JS-for-JavascriptCore/blob/master/Node/JSNodeEventEmitter.m
		// https://github.com/nodejs/node-v0.x-archive/issues/5132#issuecomment-15432598 CommonJS is ded

		if let scriptURL = NSURL(string: urlstr), let script = try? NSString(contentsOf: scriptURL as URL, encoding: String.Encoding.utf8.rawValue), let sourceURL = scriptURL.absoluteString {
			// FIXME: script code could be loaded from anywhere, exploitable?
			warn("\(scriptURL): read")

			let contextGroup = JSContextGetGroup(ctx)
			let jsurl = JSStringCreateWithCFString(urlstr as CFString)

			let jsErrorMsg = JSStringCreateWithCFString("" as CFString)
			var errorLine = Int32(0)
			let script = JSScriptCreateFromString(
				contextGroup,
				jsurl,
				/*startingLineNumber:*/ 1,
				/*script:*/ JSStringCreateWithCFString(script as CFString),
				/*errorMessage*/ UnsafeMutablePointer(jsErrorMsg),
				/*errorLine*/ &errorLine
			)

			if errorLine == 0 {
				warn("\(scriptURL): syntax checked ok")

				let contxt = JSGlobalContextCreateInGroup(contextGroup, cls)
				JSGlobalContextSetName(contxt, JSStringCreateWithCFString(urlstr as CFString))

				let globalObj = JSContextGetGlobalObject(contxt)
				var exception = JSValueMakeUndefined(contxt)

				// https://nodejs.org/api/modules.html#modules_module_exports
				// https://github.com/requirejs/requirejs/issues/89
				let module = JSObjectMake(contxt, nil, nil)
				let exports = JSObjectMake(contxt, nil, nil)
				JSObjectSetProperty(contxt, module, JSStringCreateWithCFString("exports" as CFString), exports, JSPropertyAttributes(kJSPropertyAttributeNone), nil)
				JSObjectSetProperty(contxt, module, JSStringCreateWithCFString("uri" as CFString), JSValueMakeString(contxt, jsurl), JSPropertyAttributes(kJSPropertyAttributeNone), nil)
				JSObjectSetProperty(contxt, globalObj, JSStringCreateWithCFString("module" as CFString), module, JSPropertyAttributes(kJSPropertyAttributeNone), nil)

				// https://nodejs.org/api/modules.html#modules_exports_shortcut
				JSEvaluateScript(contxt, JSStringCreateWithUTF8CString("""
					Object.defineProperty(this, "exports", {
						get: function () {
							return module.exports;
						}
					});
				"""), nil, nil, 1, nil)

				// `this === module.exports` per https://stackoverflow.com/a/30894970/3878712
				let this = JSValueToObject(contxt, exports, nil)

				if let ret = JSScriptEvaluate(contxt, script, this, &exception) {
					return JSObjectGetProperty(contxt, module, JSStringCreateWithCFString("exports" as CFString), nil)
				} else if !JSValueIsUndefined(contxt, exception) {
					return exception!
				}
			} else {
				warn("bad syntax: \(scriptURL) @ \(errorLine)")
				let errMessage = JSStringCopyCFString(kCFAllocatorDefault, jsErrorMsg) as String
				warn(errMessage)
			} // or pop open the script source-code in a new tab and highlight the offender
		}
		warn("\(urlstr): could not be read")
		return JSValueMakeNull(ctx)
	}

//ES6 async imports of .mjs?
// https://github.com/WebKit/webkit/blob/master/Source/JavaScriptCore/runtime/JSGlobalObjectFunctions.cpp#L782
// https://github.com/WebKit/webkit/blob/310778e7d2a10e8ba10b22a62b6949b9071f7415/Source/JavaScriptCore/runtime/JSGlobalObject.cpp#L779
// https://github.com/WebKit/webkit/blob/6e18e26e3a8dc8527949110b403bb943070a07bc/Source/JavaScriptCore/jsc.cpp#L786
// https://github.com/WebKit/webkit/blob/master/Source/JavaScriptCore/runtime/JSModuleLoader.cpp
// https://github.com/WebKit/webkit/blob/c340b151a8adc98e719539174aa13386d46e0851/Source/WebCore/bindings/js/ScriptModuleLoader.cpp
//  will need to reimpl ASG in a .cxx to expose those JSC:: goodies
//	https://github.com/tris-foundation/javascript/blob/master/Sources/CV8/c_v8.cpp
//	https://karhm.com/JavaScriptCore_C_API/
// could also require() in SystemJS.import: https://github.com/systemjs/systemjs/blob/master/docs/module-formats.md
//   would need a native-hooked transpile() func to babel out the import statements from the filetexts to require()ese
//      https://github.com/babel/babel/tree/master/packages/babel-parser

	static let cjsrequire: JSObjectCallAsFunctionCallback = { ctx, function, thisObject, argc, args, exception in
		// https://developer.apple.com/documentation/javascriptcore/jsobjectcallasfunctioncallback
		// called as `thisObject.function(args);` within ctx

		if argc > 0 {
			if let args = args, JSValueIsString(ctx, args[0]) {
				let globalObjClass = JSClassCreate(&globalClassDef)
				let url = JSStringCopyCFString(kCFAllocatorDefault, JSValueToStringCopy(ctx, args[0], nil)) as String
				return loadCommonJSScript(urlstr: url, ctx: ctx!, cls: globalObjClass)
			}
		}

		return JSValueMakeNull(ctx) // generates an exception
	}

	static let nativeModules: [String: Any] = [
		"console":			AppScriptConsole(),
		//"fetch":			JSFetch.self,
		//"keychain":			SSKeychain.self,
		"launchedWithURL":	"",
		"WebView":			MPWebView.self,
	]
	static let modSpace = "_nativeModules"

	static let functions: [JSStaticFunction] = [
		JSStaticFunction(name: "require", callAsFunction: cjsrequire,
			attributes: JSPropertyAttributes(kJSPropertyAttributeReadOnly | kJSPropertyAttributeDontDelete)),
		JSStaticFunction(name: nil, callAsFunction: nil, attributes: 0) // req'd terminator
    ] // doesn't seem to identically mmap to C-array-of-structs ...

	static let values: [JSStaticValue] = [
		//JSStaticValue(name: "nativeModules", getProperty: nil, setProperty: nil, attributes: 0),
		JSStaticValue(name: nil, getProperty: nil, setProperty: nil, attributes: 0) // req'd terminator
    ]

	static let initialize: JSObjectInitializeCallback = { ctx, obj in
		warn("context created")
		let context = JSContext(jsGlobalContextRef: ctx)!
		// this[Symbol.toStringTag] = "app"; this => [object app]

		context.injectGlobal(property: "require", function: cjsrequire)
		context.globalObject.setObject(nativeModules, forKeyedSubscript: modSpace as NSString)
		AppScriptConsole.extend(context, "\(modSpace).console")
		// retain(obj)
	}

	static let finalize: JSObjectFinalizeCallback = { obj in
		warn("context freed")
		// release(obj)
	}

	// https://developer.apple.com/documentation/javascriptcore/jsclassdefinition
	static var globalClassDef = JSClassDefinition(
		version: 0, attributes: JSClassAttributes(kJSClassAttributeNoAutomaticPrototype), // shows all Object.protos but not my custom func
		//version: 0, attributes: JSClassAttributes(kJSClassAttributeNone), // only shows my custom func in the proto, none from Object
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
	static let shared = AppScriptRuntime(global: AppScriptRuntime.legacyGlobal) // create & export the singleton

	var contextGroup = JSContextGroupCreate()
	var context: JSContext
	var jsdelegate: JSValue
	let exports: JSValue

	var arguments: [String] { return ProcessInfo.processInfo.arguments }
	var environment: [AnyHashable: Any] { return ProcessInfo.processInfo.environment }
	var appPath: String { return Bundle.main.bundlePath }
	var resourcePath: String { return Bundle.main.resourcePath ?? String() }
	var hostname: String { return ProcessInfo.processInfo.hostName }
	var bundleID: String { return Bundle.main.bundleIdentifier ?? String() }

#if os(OSX)
	var name: String { return NSRunningApplication.current.localizedName ?? String() }
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

	let globalObjClass = JSClassCreate(&AppScriptGlobals.globalClassDef)

	init(global: String = AppScriptRuntime.legacyGlobal) {
		//AppScriptGlobals.ptrFunctions.initialize(from: AppScriptGlobals.functions)
		//AppScriptGlobals.ptrValues.initialize(from: AppScriptGlobals.values)

		// lets create the global context with a custom-classed globalObj
		// all app-scripts and cjs-mods will get their own contexts when evaluated, but within the same context-group
		//  app-scripts will also have the `$.app` namespace mounted for run-time checks ($.app.platform)
		context = JSContext(jsGlobalContextRef: JSGlobalContextCreateInGroup(contextGroup, globalObjClass))

		jsdelegate = JSValue(newObjectIn: context) //default property-less delegate obj

#if SAFARIDBG
		// https://github.com/WebKit/webkit/commit/e9f4a5ef360d47b719f7391fe02d28ff1e63fc7://github.com/WebKit/webkit/commit/e9f4a5ef360d47b719f7391fe02d28ff1e63fc7e
		// https://github.com/WebKit/webkit/blob/master/Source/JavaScriptCore/API/JSContextPrivate.h
		context._remoteInspectionEnabled = true
		// http://asciiwwdc.com/2014/sessions/512  https://developer.apple.com/videos/play/wwdc2014/512/
		//context.logToSystemConsole = true // console.*(...) => `CONSOLE LOG ...`
#else
		context._remoteInspectionEnabled = false
		//context.logToSystemConsole = false
#endif
		//context._debuggerRunLoop = CFRunLoopRef // FIXME: make a new thread for REPL and Web Inspector console eval()s
		JSRemoteInspectorSetLogToSystemConsole(false)

		exports = JSValue(newObjectIn: context)
		context.globalObject.setObject(exports, forKeyedSubscript: global as NSString)
		XMLHttpRequest().extend(context) // allows `new XMLHTTPRequest` for doing xHr's
		//FIXME: extend Fetch API instead: https://facebook.github.io/react-native/docs/network.html

		super.init()
		context.name = "\(self.name) \(self.description)"

		context.evaluateScript("""
			Object.assign(\(global), {
				launchedWithURL: \(AppScriptGlobals.modSpace).launchedWithURL
				, WebView: \(AppScriptGlobals.modSpace).WebView
			});
			let window = this; // https://github.com/nodejs/node/issues/1043
			let global = this; // https://github.com/browserify/insert-module-globals/pull/48#issuecomment-186291413
			// \(AppScriptGlobals.modSpace).WebView.prototype.toString = function() { return this.description; };
			Object.assign(this, {
				WebView: \(AppScriptGlobals.modSpace).WebView
			});
		""")
		// customize the __proto__.toString() for the exported JS WebViews:
		// https://github.com/WebKit/webkit/blob/master/Source/JavaScriptCore/API/JSWrapperMap.mm#L138 JSObject *objectWithCustomBrand
		// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Object/toString

		//JSFetch.provideToContext(context: self.context!, hostURL: "")
	}

	override var description: String { return "<\(type(of: self))> [\(appPath)]" }

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

	@objc func loadSiteApp() -> Bool {
		let app = (Bundle.main.object(forInfoDictionaryKey:"MacPin-AppScriptName") as? String) ?? AppScriptRuntime.legacyAppFile
		guard let gblExport = context.objectForKeyedSubscript(AppScriptRuntime.legacyGlobal) else { return false; }
		let appExport = gblExport.objectForKeyedSubscript(AppScriptRuntime.legacyAppGlobal)
		if let appExport = appExport, !appExport.isUndefined && !appExport.isNull {
			// don't re-export if $.app is already exported
		} else {
			gblExport.setObject(self, forKeyedSubscript: AppScriptRuntime.legacyAppGlobal as NSString)
			// https://bugs.swift.org/browse/SR-6476 can't do appExport = self
		}
		//appExport.setObject(context.globalObject.loadCommonJSScript, forKeyedSubscript: "loadCommonJSScript" as NSString)

		context.evaluateScript("""
			window.addEventListener =
				\(AppScriptRuntime.legacyGlobal).\(AppScriptRuntime.legacyAppGlobal).on.bind(\(AppScriptRuntime.legacyGlobal).\(AppScriptRuntime.legacyAppGlobal));
		""")

		if let app_js = Bundle.main.url(forResource: app, withExtension: "js") {
			if let jsval = loadAppScript(app_js.description) {
				if jsval.isObject { // FIXME: #11 - if JSValueIsInstanceOfConstructor(context.jsGlobalContextRef, jsval.JSValueRef, context.objectForKeyedSubscript("App").JSValueRef, nil)
					warn("\(app_js) loaded as AppScriptRuntime.shared.jsdelegate")
					jsdelegate = jsval // TODO: issue #11 - make `this` the delegate in app scripts, not the return
					return true
				}
			}
		}

		return false
	}

	@discardableResult
	func loadAppScript(_ urlstr: String) -> JSValue? {
		if let scriptURL = NSURL(string: urlstr), let script = try? NSString(contentsOf: scriptURL as URL, encoding: String.Encoding.utf8.rawValue), let sourceURL = scriptURL.absoluteString {
			// FIXME: script code could be loaded from anywhere, exploitable?
			warn("\(scriptURL): read")

			var exception = JSValue()

			if JSCheckScriptSyntax(
				/*ctx:*/ context.jsGlobalContextRef,
				/*script:*/ JSStringCreateWithCFString(script as CFString),
				/*sourceURL:*/ JSStringCreateWithCFString(sourceURL as CFString),
				/*startingLineNumber:*/ 1,
				/*exception:*/ UnsafeMutablePointer(exception.jsValueRef)
			) {
				warn("\(scriptURL): syntax checked ok")
				//context.name = "\(context.name ?? "js(??)") <\(urlstr)>"

				//return jsdelegate.thisEval(script as String, sourceURL: scriptURL) // TODO: issue #11 - make `this` the delegate in app scripts, not the return
				// or somehow implement ES6's `export` to allow explicit designation of objects to be exposed into the parent/requiring namespace
				//   export is bound-in as an NSBlock to a new JSContext we'll evaluate the scriptFile within
				//   the block will buffer up exported JSValues to a native dict-var
				//     JSValue.name will define the key for exposure to parent
				//   when evaluate completes, the dict can be merged/Object.assign()d into the globalContext
				//     can JSValues be copied between JSContexts like that?
				//       as long as the contexts have the same VM, yes
				//     https://github.com/pojala/electrino/pull/5/files
				return context.evaluateScript(script as String, withSourceURL: scriptURL as URL?)
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

	@discardableResult
	func loadCommonJSScript(_ urlstr: String) -> JSValue {
		// just a bridgeable-wrapper for JSContext.loadCommonJSScript
		return JSValue(jsValueRef: AppScriptGlobals.loadCommonJSScript(urlstr: urlstr, ctx: context.jsGlobalContextRef, cls: globalObjClass), in: context)
	}

	func resetStates() {
		jsdelegate = JSValue(nullIn: context)
		eventCallbacks = [:] // FIXME: retain printToREPL ?
		messageHandlers = [:]
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
				NSWorkspace.shared.open([url as URL], withAppBundleIdentifier: appid, options: .default, additionalEventParamDescriptor: nil, launchIdentifiers: nil)
			} else {
				NSWorkspace.shared.open(url as URL)
			}
			//options: .Default .NewInstance .AndHideOthers
			// FIXME: need to force focus on appid too, already launched apps may not pop-up#elseif os (iOS)
#elseif os(iOS)
			// iOS doesn't allow directly launching apps, must use custom-scheme URLs and X-Callback-URL
			//  unless jailbroken http://stackoverflow.com/a/6821516/3878712
			if let urlp = NSURLComponents(URL: url, resolvingAgainstBaseURL: true) {
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

		if let icon_url = Bundle.main.url(forResource: iconpath, withExtension: "png") ?? URL(string: iconpath) {
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
		//  https://developer.apple.com/library/iad/documentation/AppleApplications/Conceptual/SafariJSProgTopics/Articles/SendingNotifications.html
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
				let val = self.context.evaluateScript(line)

				if self.context.exception != nil {
					if let str = self.context.exception.toString()
					, let typ = self.context.exception.forProperty("name").toString()
					, let msg = self.context.exception.forProperty("message").toString()
					, let det = self.context.exception.toDictionary() {
						print("\(str)")
						//warn(obj: det) // stack of error
						//if str == "SyntaxError: Unexpected end of script" => Prompt.readNextLine?
					}
					self.context.exception = nil // we've handled this
				}

				if let rets = self.emit(.printToREPL, val as Any, true) { //handler, expression, colorize
					rets.forEach { ret in
						if let retstr = ret?.toString() { print(retstr) }
					}
				} else if let val = val as? JSValue { // no REPLprint handler, just eval and dump
					// FIXME: instead of waiting on the events returns, expose a repl object to the runtime that can be replaced
					//  if replaced with a callable func, we will print(`repl.writer(result)`)
					//   https://nodejs.org/dist/latest/docs/api/repl.html#repl_customizing_repl_output
					//	 https://nodejs.org/dist/latest/docs/api/repl.html#repl_custom_evaluation_functions
					print(val)
					// !val.isUndefined, self.context.assigntoKey("_", val)
						// https://nodejs.org/dist/latest/docs/api/repl.html#repl_assignment_of_the_underscore_variable
					// return val??  then abort(val) could do something special?
				} else {
					// TODO: support multi-line input
					//	https://nodejs.org/dist/latest/docs/api/repl.html#repl_recoverable_errors
					print("null [not-bridged]")
				}
			},
			ps1: #file,
			ps2: #function,
			abort: { () -> Void in
				// EOF'd by Ctrl-D
#if os(OSX)
				warn("got EOF from stdin, stopping app")
				//NSProcessInfo.processInfo().enableAutomaticTermination("REPL")
				ProcessInfo.processInfo.enableSuddenTermination()
				NSApp.reply(toApplicationShouldTerminate: true) // now close App if this was deferring a terminate()
				// FIXME: make sure prompter is deinit'd
				prompter = nil
				NSApplication.shared.terminate(self)
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
		eventCallbacks[ev, default: []] += [callback]
		warn(eventCallbacks[ev, default: []].description)
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
	func emit(_ event: AppScriptEvent, _ args: [Any]) -> [JSValue?]? {
		if let cbs = eventCallbacks[event] {
			return cbs.map { cb in cb.call(withArguments: args) }
		} else if self.jsdelegate.isObject && self.jsdelegate.hasProperty(event.rawValue) {
			self.jsdelegate.tryFunc(event.rawValue, argv: args) //compat with old stuff
			return []
		} else {
			return nil
		}
	}

	var messageHandlers: [String: [JSValue]] = [:]
}

enum AppScriptEvent: String, CustomStringConvertible {
	var description: String { return "\(type(of: self)).\(self.rawValue)" }

	case /* legacy MacPin event names */
		launchURL, // url
		networkIsOffline, //url, tab
		handleClickedNotification, // title, subtitle, message, idstr
		handleDragAndDroppedURLs, // urls -> Bool
		decideNavigationForMIME, // mime, url, webview -> Bool
		AppWillFinishLaunching, // app, url?
		AppFinishedLaunching, // app, url?
		printToREPL // result

// TOIMPL: https://electronjs.org/docs/api/app#events
}
