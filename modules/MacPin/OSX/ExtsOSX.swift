import AppKit
import WebKit
import WebKitPrivates

class MenuItem: NSMenuItem {
	convenience init(_ itemName: String?, _ anAction: String?, _ charCode: String? = nil, _ keyflags: [NSEventModifierFlags] = [], target aTarget: AnyObject? = nil, represents: AnyObject? = nil) {
		self.init(
			title: itemName ?? "",
			action: Selector(anAction!),
			keyEquivalent: charCode ?? ""
		)
		for keyflag in keyflags {
			keyEquivalentModifierMask |= Int(keyflag.rawValue)
			 // .[AlphaShift|Shift|Control|Alternate|Command|Numeric|Function|Help]KeyMask
		}
		target = aTarget
		representedObject = represents
		// menu item actions walk the responder chain if target == nil
		// https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/EventOverview/EventArchitecture/EventArchitecture.html#//apple_ref/doc/uid/10000060i-CH3-SW9
		// https://developer.apple.com/library/mac/releasenotes/AppKit/RN-AppKit/#10_10ViewController
		// ChildView -> ChildView ViewController -> ParentView -> ParentView's ViewController -> ParentView's ParentView -> Window -> Window's WindowController -> Window's Delegate -> NSApp -> App Delegate
	}
}

public extension NSPasteboard {
	func dump() {
		if let items = self.pasteboardItems {
			for item in items {
				warn("\n")
				if let types = item.types as? [NSString] {
					warn(types.description)
					for uti in types { // https://developer.apple.com/library/mac/documentation/MobileCoreServices/Reference/UTTypeRef/
						// http://arstechnica.com/apple/2005/04/macosx-10-4/11/ http://www.cocoanetics.com/2012/09/fun-with-uti/
						if !uti.description.isEmpty, let value = item.stringForType(uti.description) {
							if var cftype = UTTypeCopyDescription(uti as CFString) {
								var type = cftype.takeUnretainedValue() 
								warn("DnD: uti(\(uti)) [\(type)] = '\(value)'")
							} else if var cftag = UTTypeCopyPreferredTagWithClass(uti as CFString, kUTTagClassNSPboardType) {
								var tag = cftag.takeUnretainedValue()
								warn("DnD: uti(\(uti)) <\(tag)> = '\(value)'")
							} else if var cftag = UTTypeCopyPreferredTagWithClass(uti as CFString, kUTTagClassMIMEType) {
								var tag = cftag.takeUnretainedValue()
								warn("DnD: uti(\(uti)) {\(tag)} = '\(value)'")
							} else {
								warn("DnD: uti(\(uti)) = '\(value)'")
							} //O
						} //M
					} //G
				} //W
			} //T
		} //F
	} //PewPewDIE!@#$!$#!@

}

public extension WKView {
	//override public func draggingEntered(sender: NSDraggingInfo) -> NSDragOperation { return NSDragOperation.Every }

	/* overide func _registerForDraggedTypes() {
		// https://github.com/WebKit/webkit/blob/f72e25e3ba9d3d25d1c3a4276e8dffffa4fec4ae/Source/WebKit2/UIProcess/API/mac/WKView.mm#L3653
		self.registerForDraggedTypes([ // https://github.com/WebKit/webkit/blob/master/Source/WebKit2/Shared/mac/PasteboardTypes.mm [types]
			// < forEditing 
			WebArchivePboardType, NSHTMLPboardType, NSFilenamesPboardType, NSTIFFPboardType, NSPDFPboardType,
		    NSURLPboardType, NSRTFDPboardType, NSRTFPboardType, NSStringPboardType, NSColorPboardType, kUTTypePNG,
			// < forURL
			WebURLsWithTitlesPboardType, //webkit proprietary 
			NSURLPboardType, // single url from older apps and Chromium -> text/uri-list
			WebURLPboardType, //webkit proprietary: public.url
			WebURLNamePboardType, //webkit proprietary: public.url-name
			NSStringPboardType, // public.utf8-plain-text -> WKJS: text/plain
			NSFilenamesPboardType, // Finder -> text/uri-list & Files
		])
	} */

	// http://stackoverflow.com/a/25114813/3878712
	func shimmedPerformDragOperation(sender: NSDraggingInfo) -> Bool {
		if sender.draggingSource() == nil { //dragged from external application
			var pboard = sender.draggingPasteboard()
			pboard.dump()

			if var urls = WebURLsWithTitles.URLsFromPasteboard(pboard) { //drops from Safari
				warn("DnD: WebKit URL array: \(urls)")
			} else if var file = pboard.dataForType("public.file-url") { //drops from Finder
				warn("DnD: files from Finder")
			} else if var zip = pboard.dataForType("org.chromium.drag-dummy-type") ?? pboard.dataForType("org.chromium.image-html") { //Chromium
				// http://src.chromium.org/viewvc/chrome/trunk/src/content/browser/web_contents/web_drag_source_mac.mm
				// http://src.chromium.org/viewvc/chrome/trunk/src/ui/base/dragdrop/cocoa_dnd_util.mm
			//} else if "public.url" != (pboard.availableTypeFromArray(["public.url"]) ?? "") { //Chromium missing public-url

				// Chromium pastes need some massage for WebView to seamlessly open them, so imitate a Safari drag
				// https://github.com/WebKit/webkit/blob/master/Source/WebKit/mac/Misc/WebNSPasteboardExtras.mm#L118 conform to _web_bestURL()

				var apsfctype = pboard.dataForType("com.apple.pasteboard.promised-file-content-type")
				var apsfurl = pboard.dataForType("com.apple.pasteboard.promised-file-url")

				if let url = NSURL(fromPasteboard: pboard) { // NSURLPBoardType
					// https://github.com/WebKit/webkit/blob/53e0a1506a7b2408e86caa9f510477b5ee283487/Source/WebKit2/UIProcess/API/mac/WKView.mm#L3330 drag out
					// https://github.com/WebKit/webkit/search?q=datatransfer

					pboard.clearContents() // have to wipe it clean in order to modify

					pboard.addTypes(["WebURLsWithTitlesPboardType"], owner: nil)
					WebURLsWithTitles.writeURLs([url], andTitles: nil, toPasteboard: pboard)
					// https://github.com/WebKit/webkit/blob/master/Source/WebKit/mac/History/WebURLsWithTitles.h

					//pboard.addTypes([NSURLPboardType], owner: nil) // Apple URL pasteboard type -> text/url-list
					//url.writeToPasteboard(pboard) //deprecated from 10.6+
					// https://github.com/WebKit/webkit/blob/fb77811f2b8164ce4c34fc63b496519be15f55ca/Source/WebCore/platform/mac/PasteboardMac.mm#L543

					pboard.addTypes(["public.url"], owner: nil) // *WebURLPboardType http://uti.schwa.io/identifier/public.url
					pboard.setString(url.description, forType:"public.url") // -> public.url

					pboard.setString(url.description, forType:NSStringPboardType) // -> text/plain
					// https://github.com/WebKit/webkit/blob/fb77811f2b8164ce4c34fc63b496519be15f55ca/Source/WebCore/platform/mac/PasteboardMac.mm#L539

					if let ctype = apsfctype {
						pboard.addTypes(["com.apple.pasteboard.promised-file-content-type"], owner: nil)
						pboard.setData(ctype, forType:"com.apple.pasteboard.promised-file-content-type")
					}
					if let url = apsfurl {
						pboard.addTypes(["com.apple.pasteboard.promised-file-url"], owner: nil)
						pboard.setData(url, forType:"com.apple.pasteboard.promised-file-url")
					}

					//pboard.writeObjects([url])

					pboard.dump()
				}
			}
		}
		return self.shimmedPerformDragOperation(sender) //return pre-swizzled method		
	}
}
