/// MacPin WebViewControllerOSX
///
/// WebViewController subclass for Mac OSX

import WebKit
import WebKitPrivates

@objc class WebViewControllerOSX: WebViewController {
	override func viewDidLoad() {
		super.viewDidLoad()
		//view.wantsLayer = true //use CALayer to coalesce views
		//^ default=true:  https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/mac/WKView.mm#L3641
		view.autoresizingMask = [.ViewWidthSizable, .ViewHeightSizable]

/*
		if let wkview = view.subviews.first as? WKView {
			//wkview.setValue(false, forKey: "shouldExpandToViewHeightForAutoLayout") //KVO
			//wkview.shouldExpandToViewHeightForAutoLayout = false
			//wkview.postsFrameChangedNotifications = false //FIXME stop webinspector flicker?
			//view.postsBoundsChangedNotifications = false //FIXME stop webinspector flicker?
		}
*/

		//view.setContentHuggingPriority(NSLayoutPriorityDefaultLow, forOrientation:  NSLayoutConstraintOrientation.Vertical) // prevent autolayout-flapping when web inspector is docked to tab
		view.setContentHuggingPriority(250.0, forOrientation:  NSLayoutConstraintOrientation.Vertical) // prevent autolayout-flapping when web inspector is docked to tab

		bind(NSTitleBinding, toObject: webview, withKeyPath: "title", options: nil)
		//backMenu.delegate = self
		//forwardMenu.delegate = self
	}

	override func viewWillAppear() { // window popping up with this tab already selected & showing
		super.viewWillAppear() // or tab switching into view as current selection
	}

	override func viewDidAppear() { // window now loaded and showing view
		super.viewDidAppear()
		//view.autoresizesSubviews = false
		//view.translatesAutoresizingMaskIntoConstraints = false
		if let window = view.window {
			//window.backgroundColor = webview.transparent ? NSColor.clearColor() : NSColor.whiteColor()
			window.backgroundColor = window.backgroundColor.colorWithAlphaComponent(webview.transparent ? 0 : 1) //clearColor | fooColor
			window.opaque = !webview.transparent
			window.hasShadow = !webview.transparent
			window.invalidateShadow()
			window.toolbar?.showsBaselineSeparator = window.titlebarAppearsTransparent ? false : !webview.transparent
		}

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

	deinit { unbind(NSTitleBinding) }

	override func cancelOperation(sender: AnyObject?) { webview.stopLoading(sender) } // NSResponder: make Esc key stop page load
}

extension WebViewControllerOSX: NSMenuDelegate {
	func menuNeedsUpdate(menu: NSMenu) {
		//if menu.tag == 1 //backlist
		for histItem in webview.backForwardList.backList {
			let mi = NSMenuItem(title:(histItem.title ?? histItem.URL.absoluteString), action:Selector("gotoHistoryMenuURL:"), keyEquivalent:"" )
			mi.representedObject = histItem.URL
			mi.target = self
		}
	}
}

extension WebViewControllerOSX { // AppGUI funcs

	/*
	func print(sender: AnyObject?) { warn(""); webview.print(sender) }
	*/

	func toggleTransparency() { webview.transparent = !webview.transparent; viewDidAppear() }

	//FIXME: support new scaling https://github.com/WebKit/webkit/commit/b40b702baeb28a497d29d814332fbb12a2e25d03
	func zoomIn() { webview.magnification += 0.2 }
	func zoomOut() { webview.magnification -= 0.2 }

	func print(sender: AnyObject?) { warn(""); webview.print(sender) }

	func highlightConstraints() { view.window?.visualizeConstraints(view.constraints) }

	func replaceContentView() { view.window?.contentView = view }

	func shareButtonClicked(sender: AnyObject?) {
		if let btn = sender as? NSView {
			if let url = webview.URL {
				let sharer = NSSharingServicePicker(items: [url])
				sharer.delegate = self
				sharer.showRelativeToRect(btn.bounds, ofView: btn, preferredEdge: NSRectEdge.MinY)
				//sharer.style = 1 // https://github.com/iljaiwas/NSSharingPickerTest/pull/1
			}
		}
	}

	func displayAlert(alert: NSAlert, _ completionHandler: (NSModalResponse) -> Void) {
		if let window = view.window {
			alert.beginSheetModalForWindow(window, completionHandler: completionHandler)
		} else {
			completionHandler(alert.runModal())
		}
	}

	func popupMenu(items: [String: String]) { // trigger a menu @ OSX right-click & iOS longPress point
		let _ = NSMenu(title:"popup")
		// items: [itemTitle:String eventName:String], when clicked, fire event in jsdelegate?
		//menu.popUpMenu(menu.itemArray.first, atLocation: NSPointFromCGPoint(CGPointMake(0,0)), inView: self.view)
	}

}

extension WebViewControllerOSX: NSSharingServicePickerDelegate { }

/*
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
*/
