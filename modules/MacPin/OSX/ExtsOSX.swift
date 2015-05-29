/// MacPin ExtsOSX
///
/// Global-scope utility functions for OSX

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
	//func validateMenuItem(menuItem: NSMenuItem) -> Bool { return true }
}

extension NSPasteboard {
	func dump() {
		if let items = self.pasteboardItems {
			for item in items {
				warn("\n")
				if let types = item.types as? [NSString] {
					warn(types.description)
					for uti in types { // https://developer.apple.com/library/mac/documentation/MobileCoreServices/Reference/UTTypeRef/
						// https://developer.apple.com/library/mac/documentation/Miscellaneous/Reference/UTIRef/Articles/System-DeclaredUniformTypeIdentifiers.html
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

extension WKView {
	//override func draggingEntered(sender: NSDraggingInfo) -> NSDragOperation { return NSDragOperation.Every }

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

	// try to accept DnD'd links from other browsers more gracefully than default WebKit behavior
	// this mess ain't funny: https://hsivonen.fi/kesakoodi/clipboard/
	func shimmedPerformDragOperation(sender: NSDraggingInfo) -> Bool {
		if sender.draggingSource() == nil { //dragged from external application
			var pboard = sender.draggingPasteboard()
			pboard.dump()

			if var urls = WebURLsWithTitles.URLsFromPasteboard(pboard) { //drops from Safari
				warn("DnD: WebKit URL array: \(urls)")
			} else if var file = pboard.stringForType(kUTTypeFileURL as String) { //drops from Finder
				warn("DnD: file from Finder: \(file)")
			} else if var zip = pboard.dataForType("org.chromium.drag-dummy-type") ?? pboard.dataForType("org.chromium.image-html") //Chromium
				where kUTTypeURL as String != (pboard.availableTypeFromArray([kUTTypeURL as String]) ?? "") { // image or href link drops don't have URL UTIs?!
				// Chromium uses "promises" NSPasteboard API:
				//   http://www.cocoabuilder.com/archive/cocoa/314303-fwd-nspasteboarditem-kpasteboardtypefileurlpromise.html#314303
				//   https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/DragandDrop/Tasks/DraggingFiles.html#//apple_ref/doc/uid/20001288-102943
				// let's add a standard URL uti to this drag's pasteboard

				// http://src.chromium.org/viewvc/chrome/trunk/src/content/browser/web_contents/web_drag_source_mac.mm
				// http://src.chromium.org/viewvc/chrome/trunk/src/ui/base/dragdrop/cocoa_dnd_util.mm

				// Chromium pastes need some massage for WebView to seamlessly open them, so imitate a Safari drag
				// https://github.com/WebKit/webkit/blob/master/Source/WebKit/mac/Misc/WebNSPasteboardExtras.mm#L118 conform to _web_bestURL()

				var apsfctype = pboard.dataForType(kPasteboardTypeFilePromiseContent as String) //"com.apple.pasteboard.promised-file-content-type")
				var apsfurl = pboard.dataForType(kPasteboardTypeFileURLPromise as String) //"com.apple.pasteboard.promised-file-url")

				// get the pre-Lion, pre-UTI URL that Chromium *does* supply
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

					pboard.addTypes([kUTTypeURL], owner: nil) // *WebURLPboardType http://uti.schwa.io/identifier/public.url
					pboard.setString(url.description, forType: kUTTypeURL as String) // -> public.url

					pboard.setString(url.description, forType: NSStringPboardType as String) // -> text/plain
					// https://github.com/WebKit/webkit/blob/fb77811f2b8164ce4c34fc63b496519be15f55ca/Source/WebCore/platform/mac/PasteboardMac.mm#L539

					// re-add the promises UTIs
					if let ctype = apsfctype {
						pboard.addTypes([kPasteboardTypeFilePromiseContent as String], owner: nil)
						pboard.setData(ctype, forType: kPasteboardTypeFilePromiseContent as String)
					}
					if let url = apsfurl {
						pboard.addTypes([kPasteboardTypeFileURLPromise as String], owner: nil)
						pboard.setData(url, forType: kPasteboardTypeFileURLPromise as String)
					}

					//pboard.writeObjects([url])

					pboard.dump()
				}
			} else if let url = NSURL(fromPasteboard: pboard) { // NSURLPBoardType
				warn("DnD: pre-Lion pre-UTI URL drag: \(url)")
			}
			// text/x-moz-url seems to be used for inter-tab link drags in Chrome and FF
			// https://hg.mozilla.org/mozilla-central/file/tip/dom/base/nsContentAreaDragDrop.cpp
			// https://hg.mozilla.org/mozilla-central/file/tip/widget/cocoa/nsDragService.mm
			// https://hg.mozilla.org/mozilla-central/file/tip/widget/cocoa/nsClipboard.mm

			if let urls = pboard.readObjectsForClasses([NSURL.self], options: nil) {
				if AppScriptRuntime.shared.jsdelegate.tryFunc("handleDragAndDroppedURLs", urls.map({$0.description})) { return true } // app.js indicated it will handle drag itself
			}

		} // -from external app

		return self.shimmedPerformDragOperation(sender) //return pre-swizzled method from WKWebView
		// if current page doesn't have HTML5 DnD event observers, webview will just navigate to URL dropped in
	}
}

// show an NSError to the user, attaching it to any given view
func displayError(error: NSError, _ vc: NSViewController? = nil) {
	warn("`\(error.localizedDescription)` [\(error.domain)] [\(error.code)] `\(error.localizedFailureReason ?? String())` : \(error.userInfo)")
	if let window = vc?.view.window {
		// display it as a NSPanel sheet
		vc?.view.presentError(error, modalForWindow: window, delegate: nil, didPresentSelector: nil, contextInfo: nil)
	} else if let window = NSApplication.sharedApplication().mainWindow {
		window.presentError(error, modalForWindow: window, delegate: nil, didPresentSelector: nil, contextInfo: nil)
	} else {
		NSApplication.sharedApplication().presentError(error)
	}
}

func askToOpenURL(url: NSURL?) {
	let app = NSApplication.sharedApplication()
	let window = app.mainWindow
	app.unhide(nil)
	if let url = url, window = window, opener = NSWorkspace.sharedWorkspace().URLForApplicationToOpenURL(url) {
		if opener == NSBundle.mainBundle().bundleURL {
			// macpin is already the registered handler for this (probably custom) url scheme, so just open it
			NSWorkspace.sharedWorkspace().openURL(url)
			return
		}
		warn("[\(url)]")
		let alert = NSAlert()
		alert.messageText = "Open using App:\n\(opener)"
		alert.addButtonWithTitle("OK")
		alert.addButtonWithTitle("Cancel")
		alert.informativeText = url.description
		alert.icon = NSWorkspace.sharedWorkspace().iconForFile(opener.path!)
		alert.beginSheetModalForWindow(window, completionHandler:{(response:NSModalResponse) -> Void in
			if response == NSAlertFirstButtonReturn { NSWorkspace.sharedWorkspace().openURL(url) }
 		})
		return
	}

	// if no opener, present app picker like Finder's "Open With" -> "Choose Application"?  http://stackoverflow.com/a/2876805/3878712
	// http://www.cocoabuilder.com/archive/cocoa/288002-how-to-filter-the-nsopenpanel-with-recommended-applications.html

	// all else has failed, complain to user
	let error = NSError(domain: "MacPin", code: 2, userInfo: [
		//NSURLErrorKey: url?,
		NSLocalizedDescriptionKey: "No program present on this system is registered to open this non-browser URL.\n\n\(url?.description)"
	])
	displayError(error, nil)
}
