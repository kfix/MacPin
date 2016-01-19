/// MacPin CocoaShims
///
/// Gracefully-degraded Cocoa(Touch) subclasses for shared UI code
#if os(OSX)

import AppKit

//class ViewController: NSViewController {
	// some sugar to facilitate NIB-less & programmatic instanciation
	//required init?(coder: NSCoder) { super.init(coder: coder) } // required by NSCoding protocol
	//override init!(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) { super.init(nibName:nil, bundle:nil) } //calls loadView
	//    override failable init?(nibName:) with an implicitly-unwrapped init!(nibName:) to allow `let vc: ViewController = ViewController(nil, bundle:nil)`

	// ViewController subclasses can now implement convenience initializers like:
	//    convenience init() { self.init(nibName: nil, bundle: nil) }
	//    convenience init(withFoo: AnyObject) { self.init(); doSomething(withFoo) }
	// or do this: http://sketchytech.blogspot.com/2014/09/swift-rules-of-being-required-xcode-6-gm.html
	//  also, must assign .view from loadView() override: `override func loadView() { view = withFoo }`
//}

typealias View = NSView
typealias ViewController = NSViewController
typealias Image = NSImage
typealias Window = NSWindow
typealias Application = NSApplication
typealias ApplicationDelegate = NSApplicationDelegate
typealias MacPinAppDelegatePlatform = MacPinAppDelegateOSX

#elseif os(iOS)

// adapt OSX AppKit class conventions to iOS UIKit classes
//   ala Chameleon (only this is a reverse implementation)

import UIKit

typealias View = UIView
typealias ViewController = UIViewController

typealias Image = UIImage

class Window: UIWindow {	
	func setFrame() { } // UIWindows are always size of UIScreen. They only handle focus and z-depth (level)
}

typealias Application = UIApplication
typealias ApplicationDelegate = UIApplicationDelegate
typealias MacPinAppDelegatePlatform = MacPinAppDelegateIOS

#endif
