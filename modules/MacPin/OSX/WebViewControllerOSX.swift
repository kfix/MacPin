/// MacPin WebViewControllerOSX
///
/// WebViewController subclass for Mac OSX

import WebKit
import WebKitPrivates
import JavaScriptCore
	
class WebViewControllerOSX: WebViewController {
	//required convenience init(config: WKWebViewConfiguration? = nil) { warn(""); self.init(config: config) }

	//convenience required init(config: WKWebViewConfiguration? = WKWebViewConfiguration()) {
	//	self.init(nibName: nil, bundle: nil)
	//	if let config = config { webview = WebViewController.make_webview(config) }
	//}
	// required init?(object: [String:AnyObject]) { super.init(object: object) }

	override var transparent: Bool {
		didSet { // add observer to frobble window's transparency in concert with webview
			//webview.window?.disableFlushWindow()
			container?.transparent = transparent
			webview._drawsTransparentBackground = transparent
			//^ background-color:transparent sites immediately bleedthru to a black CALayer, which won't go clear until the content is reflowed or reloaded
			webview.setFrameSize(NSSize(width: webview.frame.size.width, height: webview.frame.size.height - 1)) //needed to fully redraw w/ dom-reflow or reload! 
			evalJS("window.dispatchEvent(new window.CustomEvent('MacPinWebViewChanged',{'detail':{'transparent': \(transparent)}}));" +
				"document.head.appendChild(document.createElement('style')).remove();") //force redraw in case event didn't
				//"window.scrollTo();")
			webview.setFrameSize(NSSize(width: webview.frame.size.width, height: webview.frame.size.height + 1))
			//webview.window?.enableFlushWindow()
			webview.needsDisplay = true
			//webview.window?.flushWindowIfNeeded()
		}
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		//view.wantsLayer = true //use CALayer to coalesce views
		//^ default=true:  https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/mac/WKView.mm#L3641
		view.autoresizingMask = .ViewWidthSizable | .ViewHeightSizable
		if let wkview = view.subviews.first as? WKView {
			//wkview.setValue(false, forKey: "shouldExpandToViewHeightForAutoLayout") //KVO
			//wkview.shouldExpandToViewHeightForAutoLayout = false
			//wkview.postsFrameChangedNotifications = false //FIXME stop webinspector flicker?
			//view.postsBoundsChangedNotifications = false //FIXME stop webinspector flicker?
		}

		//view.setContentHuggingPriority(NSLayoutPriorityDefaultLow, forOrientation:  NSLayoutConstraintOrientation.Vertical) // prevent autolayout-flapping when web inspector is docked to tab
		view.setContentHuggingPriority(250.0, forOrientation:  NSLayoutConstraintOrientation.Vertical) // prevent autolayout-flapping when web inspector is docked to tab

		webview._applicationNameForUserAgent = "Version/8.0.5 Safari/600.5.17"
		bind(NSTitleBinding, toObject: webview, withKeyPath: "title", options: nil)
		webview.UIDelegate = self //alert(), window.open()	
		//backMenu.delegate = self
		//forwardMenu.delegate = self
	}
	
	override func viewWillAppear() { // window popping up with this tab already selected & showing
		super.viewWillAppear() // or tab switching into view as current selection
	}

	override func viewDidAppear() {
		super.viewDidAppear()
		//view.autoresizesSubviews = false
		//view.translatesAutoresizingMaskIntoConstraints = false
	}

	override func viewDidDisappear() {
		super.viewDidDisappear()
	}

	override func viewWillLayout() {
#if WK2LOG
		//warn("WKWebView \(view.frame)")
		//warn("WKWebView subviews #\(view.subviews.count)")
		//warn("WKWebView autoResizes subviews \(view.autoresizesSubviews)")i

		// https://github.com/WebKit/webkit/blob/aefe74816c3a4db1b389893469e2d9475bbc0fd9/Source/WebKit2/UIProcess/mac/WebInspectorProxyMac.mm#L809
		// inspectedViewFrameDidChange is looping itself
		// ignoreNextInspectedViewFrameDidChange is supposed to prevent this
		// fixed? https://bugs.webkit.org/show_bug.cgi?id=142892 https://github.com/WebKit/webkit/commit/eea322e40e200c93030702aa0a6524d249e9795f
		// moar feex http://trac.webkit.org/changeset/181927 http://trac.webkit.org/changeset/181972

		webview.resizeSubviewsWithOldSize(CGSizeZero)
		if let wkview = view.subviews.first as? NSView {
			if wkview.tag == 1000 { //WKInspectorViewTag
				// wkview.autoresizingMask == .ViewWidthSizable | .ViewMaxYMargin {
				warn("webinpector layout \(wkview.frame)") //probably a webinspector (WKWebInspectorWKWebView)
				if let pageView = view.subviews.last as? NSView { // tag=-1 should be the page content
					warn("page layout \(pageView.frame)")
					//pageView.autoresizingMask = .ViewWidthSizable
					//pageView.autoresizingMask = .ViewNotSizable
				}
			}
		}
#endif
		super.viewWillLayout()
	}

	override func updateViewConstraints() {
#if WK2LOG
		warn("\(view.frame)")
#endif
		//super.updateViewContraints()
		view.updateConstraints()
		//view.removeConstraints(view.constraints)
	}

	deinit {
		warn("\(reflect(self).summary)")
		unbind(NSTitleBinding)
	}

	override func askToOpenURL(url: NSURL?) {
		container?.tabSelected = self
		if let url = url, window = view.window, opener = NSWorkspace.sharedWorkspace().URLForApplicationToOpenURL(url) {
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
		displayError(error, self)
	}

	/*
	func print(sender: AnyObject?) { warn(""); webview.print(sender) }

	//FIXME: support new scaling https://github.com/WebKit/webkit/commit/b40b702baeb28a497d29d814332fbb12a2e25d03
	func zoomIn() { webview.magnification += 0.2 }
	func zoomOut() { webview.magnification -= 0.2 }
	*/
	
	override func cancelOperation(sender: AnyObject?) { webview.stopLoading(sender) } // NSResponder: make Esc key stop page load
}

extension WebViewControllerOSX: NSMenuDelegate {
	func menuNeedsUpdate(menu: NSMenu) {
		//if menu.tag == 1 //backlist
		for histItem in webview.backForwardList.backList {
			if let histItem = histItem as? WKBackForwardListItem {
				let mi = NSMenuItem(title:(histItem.title ?? histItem.URL.absoluteString!), action:Selector("gotoHistoryMenuURL:"), keyEquivalent:"" )
				mi.representedObject = histItem.URL
				mi.target = self
			}
		}
	}
}

extension WebViewControllerOSX { // AppGUI funcs
	func highlightConstraints() { view.window?.visualizeConstraints(view.constraints) }

	func replaceContentView() { view.window?.contentView = view }

	func shareButtonClicked(sender: AnyObject?) {
		if let btn = sender as? NSView {
			if let url = webview.URL {
				var sharer = NSSharingServicePicker(items: [url])
				sharer.delegate = self
				sharer.showRelativeToRect(btn.bounds, ofView: btn, preferredEdge: NSMinYEdge)
				//sharer.style = 1 // https://github.com/iljaiwas/NSSharingPickerTest/pull/1
			}
		}
	}

	func displayAlert(alert: NSAlert, _ completionHandler: (NSModalResponse) -> Void) {
		container?.tabSelected = self
		if let window = view.window {
			alert.beginSheetModalForWindow(window, completionHandler: completionHandler)
		} else {
			//modal app alert
		}
	}
}

extension WebViewController: NSSharingServicePickerDelegate { }
