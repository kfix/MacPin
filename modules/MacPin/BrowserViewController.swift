import JavaScriptCore
import AppKit

// https://github.com/alibaba/weex/blob/dev/ios/sdk/WeexSDK/Sources/View/WXRootView.m

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
	var tabMenu: NSMenu { get } // FIXME: cross-plat menuitem enumerable
	var shortcutsMenu: NSMenu { get } // FIXME: cross-plat menuitem enumerable
#endif
	var childViewControllers: [ViewController] { get set }
}
