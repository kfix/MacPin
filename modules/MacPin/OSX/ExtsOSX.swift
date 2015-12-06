/// MacPin ExtsOSX
///
/// Global-scope utility functions for OSX

import AppKit
import WebKit
import WebKitPrivates
import UTIKit
import Darwin

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
				warn(item.types.description)
				for uti in item.types { // https://developer.apple.com/library/mac/documentation/MobileCoreServices/Reference/UTTypeRef/
					// https://developer.apple.com/library/mac/documentation/Miscellaneous/Reference/UTIRef/Articles/System-DeclaredUniformTypeIdentifiers.html
					// http://arstechnica.com/apple/2005/04/macosx-10-4/11/ http://www.cocoanetics.com/2012/09/fun-with-uti/
					if !uti.isEmpty, let value = item.stringForType(uti) {
				 		if let cfdesc = UTTypeCopyDescription(uti as CFString), let cfmime = UTTypeCopyPreferredTagWithClass(uti as CFString, kUTTagClassMIMEType) {
							let desc = cfdesc.takeUnretainedValue()
							let mime = cfmime.takeUnretainedValue()
							warn("DnD: uti(\(uti)) `\(desc)` => types['\(mime)'] = '\(value)'")
						} else if let cftype = UTTypeCopyDescription(uti as CFString) {
							let type = cftype.takeUnretainedValue()
							warn("DnD: uti(\(uti)) [\(type)] = '\(value)'")
						} else {
							warn("DnD: uti(\(uti)) = '\(value)'")
							//might be a dynamic UTI: http://alastairs-place.net/blog/2012/06/06/utis-are-better-than-you-think-and-heres-why/
						} //O
					} //M
				} //G
			} //W
		} //T
	} //F !! PewPewDIE! @#$!$#!@

	func normalizeURLDrag() { //}-> [NSURL] {
		// extracts any URLs dragged in, and makes the pasteboard writeable whilst restoring most of the original contents
		//var urls: [NSURL] = []

		let apsfctype = dataForType(kPasteboardTypeFilePromiseContent as String) //"com.apple.pasteboard.promised-file-content-type")
		let apsfurl = dataForType(kPasteboardTypeFileURLPromise as String) //"com.apple.pasteboard.promised-file-url")
		//let urlstr = stringForType(kUTTypeURL as String)
		//let urlname = stringForType("public.url-name" as String)
		let str = stringForType(NSStringPboardType as String)
		let wkurls = WebURLsWithTitles.URLsFromPasteboard(self)

		if let urls = readObjectsForClasses([NSURL.self], options: nil) as? [NSURL] {
			clearContents() // have to wipe it clean in order to modify

			// re-add any promises UTIs
			if let ctype = apsfctype {
				addTypes([kPasteboardTypeFilePromiseContent as String], owner: nil)
				setData(ctype, forType: kPasteboardTypeFilePromiseContent as String)
			}
			if let url = apsfurl {
				addTypes([kPasteboardTypeFileURLPromise as String], owner: nil)
				setData(url, forType: kPasteboardTypeFileURLPromise as String)
			}

			if let url = urls.first {
				addTypes([kUTTypeURL as String, NSStringPboardType], owner: nil) // *WebURLPboardType http://uti.schwa.io/identifier/public.url
				setString(url.description, forType: kUTTypeURL as String) // -> public.url

				setString(url.description, forType: NSStringPboardType as String) // -> text/plain
				// https://github.com/WebKit/webkit/blob/fb77811f2b8164ce4c34fc63b496519be15f55ca/Source/WebCore/platform/mac/PasteboardMac.mm#L539
			}

/*
			if let urlstr = urlstr, urlname = urlname {
				addTypes([kUTTypeURL, "public.url-name"], owner: nil)
				setString(urlstr, forType: kUTTypeURL as String) // -> public.url
				setString(urlname, forType: "public.url-name") // -> public.url-name

				// fake x-moz-url beaause Trello Inc. is BRAINDEAD
				// text/x-moz-url seems to be used for inter-tab link drags in Chrome and FF
				// https://hg.mozilla.org/mozilla-central/file/tip/dom/base/nsContentAreaDragDrop.cpp
				// https://hg.mozilla.org/mozilla-central/file/tip/widget/cocoa/nsDragService.mm
				// https://hg.mozilla.org/mozilla-central/file/tip/widget/cocoa/nsClipboard.mm
				let mozuti = "dyn.ar34gq81k3p2su11upprr77c47pwru" //  => ?0=7:3=text/x-moz-url
				addTypes([mozuti], owner: nil)
				setString("\(urlstr)\n\(urlname)", forType: mozuti)
			}
*/
			if let str = str {
				addTypes([NSStringPboardType], owner: nil)
				setString(str, forType: NSStringPboardType as String) // -> text/plain
			}

			addTypes(["WebURLsWithTitlesPboardType"], owner: nil)
			WebURLsWithTitles.writeURLs(wkurls ?? urls, andTitles: nil, toPasteboard: self)
			// https://github.com/WebKit/webkit/blob/master/Source/WebKit/mac/History/WebURLsWithTitles.h
		}

		//return urls

	}
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
			WebURLPboardType (kUTTypeURL), //webkit proprietary: public.url
			WebURLNamePboardType (kUTTypeURLName), //webkit proprietary: public.url-name
			NSStringPboardType, // public.utf8-plain-text -> WKJS: text/plain
			NSFilenamesPboardType, // Finder -> text/uri-list & Files
		])
	} */

	// http://stackoverflow.com/a/25114813/3878712

	// try to accept DnD'd links from other browsers more gracefully than default WebKit behavior
	// this mess ain't funny: https://hsivonen.fi/kesakoodi/clipboard/
	func shimmedPerformDragOperation(sender: NSDraggingInfo) -> Bool {
		if sender.draggingSource() == nil { //dragged from external application
			let pboard = sender.draggingPasteboard()

			if let file = pboard.stringForType(kUTTypeFileURL as String) { //drops from Finder
				warn("DnD: file from Finder: \(file)")
			} else {
				pboard.dump()
				pboard.normalizeURLDrag()
				pboard.dump()
			}

			if let urls = pboard.readObjectsForClasses([NSURL.self], options: nil) {
				if AppScriptRuntime.shared.jsdelegate.tryFunc("handleDragAndDroppedURLs", urls.map({$0.description})) {
			 		return true  // app.js indicated it handled drag itself
				}
			}
		} // -from external app

		return self.shimmedPerformDragOperation(sender) //return pre-swizzled method from WKWebView ..
		// if current page doesn't have HTML5 DnD event observers, webview will just navigate to URL dropped in
	}
}

// show an NSError to the user, attaching it to any given view
func displayError(error: NSError, _ vc: NSViewController? = nil) {
	warn("`\(error.localizedDescription)` [\(error.domain)] [\(error.code)] `\(error.localizedFailureReason ?? String())` : \(error.userInfo)")
	if Darwin.isatty(Int32(0)) == 0 { // don't popup these modal alerts if REPL() is active on STDIN!
		if let window = vc?.view.window {
			// display it as a NSPanel sheet
			vc?.view.presentError(error, modalForWindow: window, delegate: nil, didPresentSelector: nil, contextInfo: nil)
		} else if let window = NSApplication.sharedApplication().mainWindow {
			window.presentError(error, modalForWindow: window, delegate: nil, didPresentSelector: nil, contextInfo: nil)
		} else {
			NSApplication.sharedApplication().presentError(error)
		}
	}
}

func askToOpenURL(url: NSURL?) { //uti: UTIType? = nil
	let app = NSApplication.sharedApplication()
	let window = app.mainWindow
	let wk = NSWorkspace.sharedWorkspace()
	app.unhide(nil)
				// if let uti = uti, opener = LSCopyDefaultRoleHandlerForContentType(UTI, kLSRolesAll)
					// offer to send url directly to compatible app if there is one
					//wk.iconForFileType(uti)
					//wk.localizedDescriptionForType(uti)
					// ask to open direct, .Cancel & return if we did

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
		alert.icon = wk.iconForFile(opener.path!)
		alert.beginSheetModalForWindow(window, completionHandler:{(response:NSModalResponse) -> Void in
			if response == NSAlertFirstButtonReturn { wk.openURL(url) }
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
