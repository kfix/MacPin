import JavaScriptCore
import AppKit

@objc protocol BrowserViewControllerJS: JSExport { // '$.browser' in app.js
	var defaultUserAgent: String? { get set } // full UA used for any new tab without explicit UA specified
	var isFullscreen: Bool { get set }
	var isToolbarShown: Bool { get set }
	var tabSelected: AnyObject? { get set }
    //var matchedAddressOptions: [String:String] { get set }
	var tabs: [MPWebView] { get set }
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
	func addShortcut(_ title: String, _ obj: AnyObject?)
	func extend(_ mountObj: JSValue)
	func unextend(_ mountObj: JSValue)
}

@objc protocol BrowserViewController: BrowserViewControllerJS {
	var view: View { get }
	var title: String? { get set }
#if os(OSX)
	var tabMenu: NSMenu { get } // FIXME: cross-plat menuitem enumerable
	var shortcutsMenu: NSMenu { get } // FIXME: cross-plat menuitem enumerable
#endif
	var childViewControllers: [ViewController] { get set }
}
