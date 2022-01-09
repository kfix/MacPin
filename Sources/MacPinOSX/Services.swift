// implement a generic router for NSService calls on OSX

import AppKit

// http://nshipster.com/nsdatadetector/
// https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/SysServices/Articles/providing.html#//apple_ref/doc/uid/20000853-BABDICBI
// https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/SysServices/Articles/properties.html#//apple_ref/doc/uid/20000852-CHDJDFIC

@objc class ServiceOSX: NSObject {

	//Service Specification: must set "NSMessage" = handlePboard" in sites/Blah/Services.plist to get dispatched
	func handlePboard(_ pboard: NSPasteboard, userData: String, error: UnsafeMutablePointer<String>) {
		// should always defer to the app.js to handle the input
		// any error given is printed to Console/ASL
		warn()
	}

}
