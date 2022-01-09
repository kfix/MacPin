import JavaScriptCore
#if os(OSX)
import AppKit
#endif

// https://electronjs.org/docs/api/browser-window
@objc protocol BrowserViewControllerJS: JSExport { // '$.browser' in app.js
	init?(object: JSValue)
	var defaultUserAgent: String? { get set } // full UA used for any new tab without explicit UA specified
	var isFullscreen: Bool { get set }
	var isToolbarShown: Bool { get set }
	var tabSelected: AnyObject? { get set }
    //var matchedAddressOptions: [String:String] { get set }
	@objc(_tabs) var tabs: [MPWebView] { get set }
	// https://bugs.swift.org/browse/SR-6476 support $.browser[N] for accessing tabs?
	func close()
	func switchToNextTab()
	func switchToPreviousTab()
	func closeTab(_ tab: AnyObject?)
	func newTabPrompt()
	func newIsolatedTabPrompt()
	func newPrivateTabPrompt()
	func focusOnBrowser()
	func unhideApp()
	func bounceDock()
	func extend(_ mountObj: JSValue)
	func unextend(_ mountObj: JSValue)

	// shortcuts & menu surface in Electron is more fully featured but complex
	// https://github.com/electron/electron/blob/master/docs/api/global-shortcut.md
	// https://github.com/electron/electron/blob/master/docs/api/menu.md#notes-on-macos-application-menu
	func addShortcut(_ title: String, _ obj: AnyObject?, _ cb: JSValue?)

#if os(OSX)
	func presentBrowser() -> WindowController
#endif
}

@objc protocol BrowserViewController: BrowserViewControllerJS {
	var view: View { get }
	var title: String? { get set }
#if os(OSX)
	var tabMenu: NSMenu { get } // FIXME: cross-plat menuitem enumerable
	var shortcutsMenu: NSMenu { get } // FIXME: cross-plat menuitem enumerable
#endif
	//var children: [ViewController] { get set }
	static func exportSelf(_ mountObj: JSValue, _ name: String)
}

// this.tabs: Proxy wrapper actively assigns `fn()`s results back to their originating
	// properties so JSC<=>ObjC bridging can forward the changes to native classes' properties
let g_tabsHelperJS = """
	Object.defineProperty(this, 'tabs', {
		get: function () {
			let backer = "_tabs"; // the ObjC bridged native property's exported name
			return new Proxy(this[backer], {
				parent: this,
				getMutator: function (source, fn) {
					return new Proxy(source[fn], {
						apply: function(target, thisArg, args) {
							let mutant = source.slice(); // needs to be a copy
							let ret = mutant[fn].apply(mutant, args); // mutate the copy
							Reflect.set(thisArg, backer, mutant); // replace the source
							mutant = null; // allow GC on our copied refs
							return ret;
						}
					});
				},
				get: function(target, property, receiver) {
					if (property == "inspect") return () => target;

					// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/prototype#Mutator_methods
					if (["copyWithin", "fill", "pop", "push", "reverse", "shift", "sort", "splice", "unshift"].includes(property))
						return this.getMutator(target, property).bind(this.parent);

					return Reflect.get(...arguments); // passthru
				}
				/*
				set: function(target, property, value, receiver) {
					console.log(`Set [${property}] to ${value.inspect()}`);
					return Reflect.set(...arguments); // passthru
				}
				*/
			});
		}
	});
"""

func g_browserHelperJS(_ className: String) -> String {
	return """
		(class \(className) extends this {

			constructor(name) {
				//console.log(`constructing [${new.target}]!`)
				super()
				Object.setPrototypeOf(this, \(className).prototype) // WTF do I have to do this, Mr. Extends?
				//this.extend(this) // mixin .tabs
			}
			static doHicky(txt) { console.log(`doHicky: ${txt}`); }
			foo(txt) { console.log(`foo: ${txt}`); }
			//inspect(depth, options) { return this.__proto__; }
			//static get [Symbol.species]() { return this; }
			//get [Symbol.toStringTag]() { return "\(className)"; }
			//[util.inspect.custom](depth, options) {}

			get tabs() {
				let backerKey = "_tabs"; // the ObjC bridged native property's exported name
				return new Proxy(this[backerKey], {backerKey, instance: this, ...{ // ES7 obj-spread-merge FTW
					getMutator: function (source, fn) {
						return new Proxy(source[fn], {backerKey: this.backerKey, ...{
							apply: function(target, thisArg, args) {
								let mutant = source.slice(); // needs to be a copy
								let ret = mutant[fn].apply(mutant, args); // mutate the copy
								Reflect.set(thisArg, this.backerKey, mutant); // replace the source
								mutant = null; // allow GC on our copied refs
								return ret;
							}
						}});
					},
					get: function(target, property, receiver) {
						if (property == "inspect") return () => target;

						// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Array/prototype#Mutator_methods
						if (["copyWithin", "fill", "pop", "push", "reverse", "shift", "sort", "splice", "unshift"].includes(property))
							return this.getMutator(target, property).bind(this.instance);

						return Reflect.get(...arguments); // passthru
					}
					/*
					set: function(target, property, value, receiver) {
						console.log(`Set [${property}] to ${value.inspect()}`);
						return Reflect.set(...arguments); // passthru
					}
					*/
				}}); // Proxy({handler})
			} // get tabs

		})
	"""
}

#if os(OSX)
typealias BrowserController = BrowserViewControllerOSX
#elseif os(iOS)
typealias BrowserController = MobileBrowserViewController
#endif
