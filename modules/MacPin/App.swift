import Foundation

import MachO
// https://opensource.apple.com/source/dyld/dyld-519.2.2/include/mach-o/dyld.h.auto.html
// https://opensource.apple.com/source/dyld/dyld-519.2.2/dyld3/APIs.cpp.auto.html
// Mach-O dylib version numbers are encoded as 32-bit unsigned integers, with the major version in the high 16 bits, the minor version in bits 8 through 15, and the patch level in the low 8 bits

// https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/DisplayWebContent/Tasks/WebKitAvail.html#//apple_ref/doc/uid/20001846-171303

// https://github.com/WebKit/webkit/commits/master/Source/WebKit/Configurations/Version.xcconfig
//   olden hitory: https://github.com/WebKit/webkit/commits/4ccac179a8c9ea2a96d60f10e6cdb2f6a4fa0989/Source/WebKit2/Configurations/Version.xcconfig
// https://github.com/WebKit/webkit/commits/master/Source/JavaScriptCore/Configurations/Version.xcconfig
//  https://trac.webkit.org/browser/webkit/#tags < get svn-git-id from github for any given commit and see what safari tags it falls between
let WebKit_version: (major: Int, minor: Int, tiny: Int) = {
	let ver = NSVersionOfRunTimeLibrary("WebKit") // if os(OSX) || os(iOS)
	return ( Int(ver >> 16 & 0x0000FFFF), Int((ver >> 8) & 0xFF), Int(ver & 0xFF) )
}()

let JavaScriptCore_version: (major: Int, minor: Int, tiny: Int) = {
	let ver = NSVersionOfRunTimeLibrary("JavaScriptCore")
	return ( Int(ver >> 16 & 0x0000FFFF), Int((ver >> 8) & 0xFF), Int(ver & 0xFF) )
}()

// https://en.wikipedia.org/wiki/Safari_version_history#
// https://github.com/apple/swift-evolution/blob/master/proposals/0015-tuple-comparison-operators.md
let Safari_version: String = { v in switch true {
	case v>=(608, 1, 33):	return "13.0"	// STP87
	case v>=(608, 1, 16):	return "12.2"	// STP80
	case v>=(607, 2, 6):	return "12.1.1"	// osx10.14.5
	case v>=(607, 1, 40):	return "12.1"	// osx10.14.4
	case v>=(606, 3, 4):	return "12.0.2"	// osx10.14.2
	case v>=(606, 1, 25):	return "12.0"	// STP61
	case v>=(605, 3,  8):	return "11.1"
	case v>=(604, 1, 28):	return "11.0"
	// wk605.1.33 | osx10.11 | sf11.0
	case v>=(602, 1, 50):	return "10.0"
	default:				return "???"
} }( WebKit_version )

@objc(MacPinApp)
public class MacPinApp: Application {
	/*
	override static func shared() -> MacPinApp {
		let app = super.shared()
		return app as! MacPinApp
	}
	*/
	@objc override static public var shared: MacPinApp {
		get {
			return super.shared as! MacPinApp
		}
	}

	var appDelegate: MacPinAppDelegate? {
		get {
			return super.delegate as? MacPinAppDelegate
		}
		set {
			super.delegate = newValue as ApplicationDelegate?
		}
	}
}
