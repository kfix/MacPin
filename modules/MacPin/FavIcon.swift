/// MacPin FavIcon
///
/// Asyncronously grabs and stores an [NS|UI]Image from a URL and accepts KVO bindings to them

// https://code.google.com/p/cocoalicious/source/browse/trunk/cocoalicious/Utilities/SFHFFaviconCache.m

#if os(OSX)

import AppKit
typealias IconImage = NSImage

#elseif os(iOS)

import UIKit
typealias IconImage = UIImage
let NSImageNameApplicationIcon = "icon"

#endif

@objc class FavIcon: NSObject {
	dynamic unowned var icon = IconImage(named: NSImageNameApplicationIcon)!
#if os(OSX)
	dynamic unowned var icon16 = IconImage(named: NSImageNameStatusNone)! {
		willSet {
			newValue.size = NSSize(width: 16, height: 16)
		}
	}
#endif

	var data: NSData? = nil
		//need 24 & 36px**2 representations for the NSImage for bigger grid views
		// https://developer.apple.com/library/ios/documentation/AppleApplications/Reference/SafariWebContent/ConfiguringWebApplications/ConfiguringWebApplications.html
		// just C, no Cocoa API yet: WKIconDatabaseCopyIconURLForPageURL(icodb, url) WKIconDatabaseCopyIconDataForPageURL(icodb, url)
		// also https://github.com/WebKit/webkit/commit/660d1e55c2d1ee19ece4a7565d8df8cab2e15125
		// OSX has libxml2 built-in https://developer.apple.com/library/mac/samplecode/LinkedImageFetcher/Listings/Read_Me_About_LinkedImageFetcher_txt.html

	var url: NSURL? = nil {
		didSet {
			if let url = url {
				warn("setting favicon.icon to = \(url)")
				FavIcon.grabFavIcon(url) { [unowned self] (data) in
					self.data = data
					if let img = IconImage(data: data) {
						self.icon = img
#if os(OSX)
						self.icon16 = img
#endif
					}
				}
			}
		}
	}

	static func grabFavIcon(url: NSURL, completion: (NSData -> Void)) {
		// http://stackoverflow.com/a/26540173/3878712
		// http://jamesonquave.com/blog/developing-ios-apps-using-swift-part-5-async-image-loading-and-caching/
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), { //[unowned self]
			if let data = NSData(contentsOfURL: url) { // downloaded from background thread. HTTP error should return nil...
				dispatch_async(dispatch_get_main_queue(), { () -> Void in // return to UI thread to update icon
					completion(data)
				})
			}
		})
	}

	override var description: String { return "<\(self.dynamicType)> `\(url)`" }
	//deinit { warn(description) }
/*
	convenience init(url: NSURL) {
		self.init()
		FavIcon.grabFavIcon(url) { (data) in
			self.data = data
			self.url = url // prop observers don't work from init....
			if let img = IconImage(data: data) { self.icon = img }
		}
	}

	convenience init?(icon: String) {
		if let url = NSURL(string: icon) where !icon.isEmpty {
			self.init(url: url)
		} else {
			return nil
		}
	}
*/
}
