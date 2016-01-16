import JavaScriptCore
import AppKit

@objc protocol BrowserViewController: JSExport { // '$.browser' in app.js
	var view: NSView { get } 
	var title: String? { get set }
	var tabMenu: NSMenu { get }
	var shortcutsMenu: NSMenu { get }
	var defaultUserAgent: String? { get set } // full UA used for any new tab without explicit UA specified
	var isFullscreen: Bool { get set }
	var isToolbarShown: Bool { get set }
	//var tabs: [AnyObject] { get } // alias to childViewControllers
	var tabs: [MPWebView] { get set }
	var childViewControllers: [ViewController] { get set } // .push() doesn't work nor trigger property observer
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
