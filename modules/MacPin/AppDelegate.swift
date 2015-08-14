
#if os(OSX)
import AppKit
#elseif os(iOS)
import UIKit
#endif

import ObjectiveC
import WebKit
import WebKitPrivates
import Darwin

// common AppDelegate code sharable between OSX and iOS (not much)
class AppDelegate: NSObject {

  let webProcessPool = WKProcessPool() // all wkwebviews should share this
  //let browserController =

	override init() {
    // browserController.webProcessPool = WKProcessPool
		super.init()
	}

}
