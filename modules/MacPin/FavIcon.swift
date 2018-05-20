/// MacPin FavIcon
///
/// Asyncronously grabs and stores a KVO-able Image from an icon's URL

#if os(OSX)

import AppKit
typealias IconImage = NSImage

#elseif os(iOS)

import UIKit
typealias IconImage = UIImage
let NSImageNameApplicationIcon = "icon"

#endif

@objc class FavIcon: NSObject {
	@objc dynamic unowned var icon = IconImage(named: NSImage.Name.applicationIcon)!
#if os(OSX)
	//need 24 & 36px**2 representations of the NSImage for bigger grid views
	@objc dynamic unowned var icon16 = IconImage(named: NSImage.Name.statusNone)! {
		willSet {
			newValue.size = NSSize(width: 16, height: 16)
		}
	}
#endif

	var data: NSData? = nil {
		didSet {
			if let data = data, let img = IconImage(data: data as Data) {
				self.icon = img
#if os(OSX)
				self.icon16 = img
#endif
			}
		}
	}
	@objc dynamic var url: NSURL? = nil {
		didSet {
			if let url = url {
				warn("setting favicon.icon to = \(url)")
				FavIcon.grabFavIcon(url) { [unowned self] (data) in
					self.data = data
				}
			}
		}
	}

	static func grabFavIcon(_ url: NSURL, completion: @escaping ((NSData) -> Void)) {
		// http://stackoverflow.com/a/26540173/3878712
		// http://jamesonquave.com/blog/developing-ios-apps-using-swift-part-5-async-image-loading-and-caching/
		DispatchQueue.global(qos: .default).async(execute: { // [unowned self]
			if let data = NSData(contentsOf: url as URL) { // downloaded from background thread. HTTP error should return nil...
				DispatchQueue.main.async(execute: { () -> Void in // return to UI thread to update icon
					completion(data)
				})
			}
		})
	}

	override var description: String { return "<\(type(of: self))> `\(url?.absoluteString ?? "")`" }
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
