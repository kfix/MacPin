/// MacPin ExtsOSX
///
/// Global-scope utility functions for OSX

import AppKit
import WebKit
import WebKitPrivates
import UTIKit
import Darwin

#if swift(>=4.0)
let NSURLPboardType = NSPasteboard.PasteboardType(kUTTypeURL as String)
#endif

class MenuItem: NSMenuItem {
	convenience init(_ itemName: String?, _ anAction: String? = nil, _ charCode: String? = nil, _ keyflags: [NSEvent.ModifierFlags] = [], target aTarget: AnyObject? = nil, represents: AnyObject? = nil, tag aTag: Int = 0) {
		self.init(
			title: itemName ?? "",
			action: anAction != nil ? Selector(anAction!) : nil,
			// FIXME: anAction should be a Selector.*: https://github.com/andyyhope/Blog_SelectorSyntaxSugar/blob/master/Blog_SelectorSyntaxSugar/ViewController.swift
			// each OSX class can privately extend its own bundle of Selectors
			keyEquivalent: charCode ?? ""
		)
		for keyflag in keyflags {
			keyEquivalentModifierMask.insert(keyflag)
		}

		//keyEquivalentModifierMask.formUnion(keyflags)
		target = aTarget
		representedObject = represents
		tag = aTag
		// menu item actions walk the responder chain if target == nil
		// https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/EventOverview/EventArchitecture/EventArchitecture.html#//apple_ref/doc/uid/10000060i-CH3-SW9
		// https://developer.apple.com/library/mac/releasenotes/AppKit/RN-AppKit/#10_10ViewController
		// ChildView -> ChildView ViewController -> ParentView -> ParentView's ViewController -> ParentView's ParentView -> Window -> Window's WindowController -> Window's Delegate -> NSApp -> App Delegate
	}
	//func validateMenuItem(menuItem: NSMenuItem) -> Bool { return true }
	convenience init(_ itemName: String?, _ anAction: Selector?, _ charCode: String? = nil, _ keyflags: [NSEvent.ModifierFlags] = [], target aTarget: AnyObject? = nil, represents: AnyObject? = nil, tag aTag: Int = 0) {
		self.init(
			title: itemName ?? "",
			action: anAction != nil ? anAction! : nil,
			keyEquivalent: charCode ?? ""
		)
		for keyflag in keyflags {
			keyEquivalentModifierMask.insert(keyflag)
		}

		//keyEquivalentModifierMask.formUnion(keyflags)
		target = aTarget
		representedObject = represents
		tag = aTag
	}

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
					if !uti.rawValue.isEmpty, let value = item.string(forType: uti) {
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

		let apsfctype = data(forType: NSPasteboard.PasteboardType(kPasteboardTypeFilePromiseContent as String)) //"com.apple.pasteboard.promised-file-content-type") .fileContents
		let apsfurl = data(forType: NSPasteboard.PasteboardType(kPasteboardTypeFileURLPromise as String)) //"com.apple.pasteboard.promised-file-url") // .fileUrl .filePromise
		//let urlstr = stringForType(kUTTypeURL as String)
		//let urlname = stringForType("public.url-name" as String)
		let str = string(forType: .string)
		let wkurls = WebURLsWithTitles.urls(from: self)

		if let urls = readObjects(forClasses: [NSURL.self], options: nil) as? [NSURL] {
			// FIXME: pass file urls to separate JS handler - image drags from safari to dock icons are tmpfiles
			clearContents() // have to wipe it clean in order to modify

			// re-add any promises UTIs
			if let ctype = apsfctype {
				addTypes([NSPasteboard.PasteboardType(kPasteboardTypeFilePromiseContent as String)], owner: nil)
				setData(ctype, forType: NSPasteboard.PasteboardType(kPasteboardTypeFilePromiseContent as String))
			}
			if let url = apsfurl {
				addTypes([NSPasteboard.PasteboardType(kPasteboardTypeFileURLPromise as String)], owner: nil)
				setData(url, forType: NSPasteboard.PasteboardType(kPasteboardTypeFileURLPromise as String))
			}

			if let url = urls.first {
				addTypes([NSPasteboard.PasteboardType(kUTTypeURL as String), .string], owner: nil) // *WebURLPboardType http://uti.schwa.io/identifier/public.url
				setString(url.description, forType: NSPasteboard.PasteboardType(kUTTypeURL as String)) // -> public.url

				setString(url.description, forType: PasteboardType.string) // -> text/plain
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
				addTypes([PasteboardType.string], owner: nil)
				setString(str, forType: PasteboardType.string) // -> text/plain
			}

			addTypes([NSPasteboard.PasteboardType("WebURLsWithTitlesPboardType")], owner: nil)
			WebURLsWithTitles.writeURLs(wkurls ?? urls, andTitles: nil, to: self)
			// https://github.com/WebKit/webkit/blob/master/Source/WebKit/mac/History/WebURLsWithTitles.h
		}

		//return urls

	}
}

// show an NSError to the user, attaching it to any given view
func displayError(_ error: NSError, _ vc: NSViewController? = nil) {
	warn("`\(error.localizedDescription)` [\(error.domain)] [\(error.code)] `\(error.localizedFailureReason ?? String())` : \(error.userInfo)")
	DispatchQueue.main.async() { // don't lock up other threads on modally-presented errors
		if Darwin.isatty(Int32(0)) == 0 { // don't popup these modal alerts if REPL() is active on STDIN!
			if let window = vc?.view.window {
				// display it as a NSPanel sheet
				vc?.view.presentError(error, modalFor: window, delegate: nil, didPresent: nil, contextInfo: nil)
			} else if let window = NSApplication.shared.mainWindow {
				window.presentError(error, modalFor: window, delegate: nil, didPresent: nil, contextInfo: nil)
			} else {
				NSApplication.shared.presentError(error)
			}
		}
	}
}

func askToOpenURL(_ url: NSURL?) { //uti: UTIType? = nil
	let app = NSApplication.shared
	let window = app.mainWindow
	let wk = NSWorkspace.shared
	app.unhide(nil)
				// if let uti = uti, opener = LSCopyDefaultRoleHandlerForContentType(UTI, kLSRolesAll)
					// offer to send url directly to compatible app if there is one
					//wk.iconForFileType(uti)
					//wk.localizedDescriptionForType(uti)
					// ask to open direct, .Cancel & return if we did

	if let url = url, let window = window, let opener = NSWorkspace.shared.urlForApplication(toOpen: url as URL) {
		if opener == Bundle.main.bundleURL {
			// macpin is already the registered handler for this (probably custom) url scheme, so just open it
			NSWorkspace.shared.open(url as URL)
			return
		}
		warn("[\(url)]")
		let alert = NSAlert()
		alert.messageText = "Open using App:\n\(opener)"
		alert.addButton(withTitle: "OK")
		alert.addButton(withTitle: "Cancel")
		alert.informativeText = url.description
		alert.icon = wk.icon(forFile: opener.path)
		alert.beginSheetModal(for: window, completionHandler:{(response: NSApplication.ModalResponse) -> Void in
			if response == .alertFirstButtonReturn { wk.open(url as URL) }
 		})
		return
	}

	// if no opener, present app picker like Finder's "Open With" -> "Choose Application"?  http://stackoverflow.com/a/2876805/3878712
	// http://www.cocoabuilder.com/archive/cocoa/288002-how-to-filter-the-nsopenpanel-with-recommended-applications.html

	// all else has failed, complain to user
	let error = NSError(domain: "MacPin", code: 2, userInfo: [
		//NSURLErrorKey: url?,
		NSLocalizedDescriptionKey: "No program present on this system is registered to open this non-browser URL.\n\n\(url?.description ?? "")"
	])
	displayError(error, nil)
}
