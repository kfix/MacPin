import JavaScriptCore
import AppKit

@objc protocol BrowserViewController: JSExport { // '$.browser' in app.js
	var view: View { get }
	var title: String? { get set }
	var tabMenu: NSMenu { get } // FIXME: cross-plat menuitem enumerable
	var shortcutsMenu: NSMenu { get } // FIXME: cross-plat menuitem enumerable
	var childViewControllers: [ViewController] { get set } // .push() doesn't work nor trigger property observer
	// ^^ FIXME: somehow exclude this stuff from JSExport ^^

	var defaultUserAgent: String? { get set } // full UA used for any new tab without explicit UA specified
	var isFullscreen: Bool { get set }
	var isToolbarShown: Bool { get set }
	//var tabs: [AnyObject] { get } // alias to childViewControllers
	var tabs: [MPWebView] { get set }
	var tabSelected: AnyObject? { get set }
    //var matchedAddressOptions: [String:String] { get set }
	func pushTab(webview: AnyObject) // JSExport does not seem to like signatures with custom types
	func close()
	func switchToNextTab()
	func switchToPreviousTab()
	func newTabPrompt()
	func newIsolatedTabPrompt()
	func newPrivateTabPrompt()
	func focusOnBrowser()
	func unhideApp()
	func bounceDock()
	func addShortcut(title: String, _ obj: AnyObject?)
}
