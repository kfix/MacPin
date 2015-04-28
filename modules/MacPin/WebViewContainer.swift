/// MacPin WebViewContainer
///
/// Protocol for all conforming MacPin browsers

#if os(OSX)
import AppKit
#elseif os(iOS)
import UIKit
#endif

@objc protocol WebViewContainer {
	var transparent: Bool { get set }
	var tabSelected: AnyObject? { get set }
	func newTab(params: AnyObject?) -> WebViewController?
#if os(OSX)
	func addChildViewController(childViewController: NSViewController)
#elseif os(iOS)
	func addChildViewController(childViewController: UIViewController)
#endif
}
