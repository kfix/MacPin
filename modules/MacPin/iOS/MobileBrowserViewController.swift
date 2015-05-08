/// MacPin MobileBrowserViewController
///
/// A tabbed rootViewController for iOS

import UIKit
import JavaScriptCore
/*
http://stackoverflow.com/a/28612260/3878712
http://www.appcoda.com/webkit-framework-intro/
*/

// need to freeze this
@objc protocol MobileBrowserScriptExports : JSExport { // '$browser' in app.js
	var defaultUserAgent: String? { get set } // full UA used for any new tab without explicit UA specified
	var tabs: [MPWebView] { get }
	var tabSelected: AnyObject? { get set }
	func addTab(webview: MPWebView)
	func newTabPrompt()
	func addShortcut(title: String, _ obj: AnyObject?)
}

class MobileBrowserViewController: UIViewController, MobileBrowserScriptExports {
	override func loadView() { view = UIView() }

	var defaultUserAgent: String? = nil

	var tabs: [MPWebView] { return childViewControllers.filter({ $0 is WebViewControllerIOS }).map({ ($0 as! WebViewControllerIOS).webview }) }

	var transparent: Bool = false {
		didSet {
		}
	}

	// UITabBarController:selectedViewController
	var tabSelected: AnyObject? = nil

	func newTabPrompt() {
		//tabSelected = MPWebView(url: NSURL(string: "about:blank")!)
		//revealOmniBox()
		warn()
	}

	func addTab(wv: MPWebView) { addChildViewController(WebViewControllerIOS(webview: wv)) }

	func addShortcut(title: String, _ obj: AnyObject?) {}

	override var description: String { return "<\(reflect(self).summary)> `\(title ?? String())`" }
}
