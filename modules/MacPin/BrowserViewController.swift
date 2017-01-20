import JavaScriptCore
import AppKit

// RN: make this a RCTViewManager so it can be richly maninpulated from app.js
// https://hashrocket.com/blog/posts/tips-and-tricks-from-integrating-react-native-with-existing-native-apps#custom-native-views-as-components
// a template/*/chrome.js would do the actual mounting of toolbar and tabview and can be substituted for adding sidebar, statusbar, etc. etc.

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
	func closeTab(tab: AnyObject?)
	func newTabPrompt()
	func newIsolatedTabPrompt()
	func newPrivateTabPrompt()
	func focusOnBrowser()
	func unhideApp()
	func bounceDock()
	func addShortcut(title: String, _ obj: AnyObject?)
	func extend(mountObj: JSValue)
	func unextend(mountObj: JSValue)
}

@objc protocol BrowserViewController: BrowserViewControllerJS {
	var view: View { get }
	var title: String? { get set }
#if os(OSX)
	var tabMenu: NSMenu { get } // FIXME: cross-plat menuitem enumerable // RN: expose
	var shortcutsMenu: NSMenu { get } // FIXME: cross-plat menuitem enumerable // RN: expose
#endif
	var childViewControllers: [ViewController] { get set } // RN: expose

	// expose many paradigms for native widgets to aid navigation
	//RN: sidebar
	//RN: toolbar
	//RN: statusbar
	//RN: hud
	//RN: grid
	//RN: console -- mirrors the tty REPL
}
