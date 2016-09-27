/// MacPin WebViewControllerOSX
///
/// WebViewController subclass for Mac OSX

import WebKit
import WebKitPrivates

@objc class WebViewControllerOSX: WebViewController, NSTextFinderBarContainer {
	let textFinder = NSTextFinder()
	var findBarView: NSView? {
		willSet { if findBarView != nil { findBarVisible = false } }
		didSet { if findBarView != nil { findBarVisible = true } }
	}
	private var _findBarVisible = false
	var findBarVisible: Bool {
		@objc(isFindBarVisible) get { return _findBarVisible }
		set(vis) {
			_findBarVisible = vis
			if let findview = findBarView {
				vis ? view.addSubview(findview) : findview.removeFromSuperview()
			}
			layout()
		}
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		//view.wantsLayer = true //use CALayer to coalesce views
		//^ default=true:  https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/mac/WKView.mm#L3641
		view.autoresizesSubviews = true
		view.autoresizingMask = [.ViewWidthSizable, .ViewHeightSizable]
		webview.autoresizingMask = [.ViewWidthSizable, .ViewHeightSizable]
#if STP
		// scale-to-fit https://github.com/WebKit/webkit/commit/b40b702baeb28a497d29d814332fbb12a2e25d03
		webview._layoutMode = .DynamicSizeComputedFromViewScale
#endif

		bind(NSTitleBinding, toObject: webview, withKeyPath: "title", options: nil)
		//backMenu.delegate = self
		//forwardMenu.delegate = self

		//webview._editable = true //makes about:blank editable by default
		textFinder.client = webview
		textFinder.findBarContainer = self
		textFinder.incrementalSearchingEnabled = true
		textFinder.incrementalSearchingShouldDimContentView = true
		// FIXME: webview doesn't auto-scroll to found matches
		//  https://github.com/WebKit/webkit/blob/112c663463807e8676765cb7a006d415c372f447/Source/WebKit2/UIProcess/mac/WKTextFinderClient.mm#L39
	}

	func contentView() -> NSView? { return webview }

	override func performTextFinderAction(sender: AnyObject?) {
		if let control = sender as? NSMenuItem, action = NSTextFinderAction(rawValue: control.tag) {
			textFinder.performAction(action)
		}
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
#if STP
			window.hasShadow = webview.transparent
#else
			window.hasShadow = !webview.transparent
#endif
			window.invalidateShadow()
			window.toolbar?.showsBaselineSeparator = window.titlebarAppearsTransparent ? false : !webview.transparent
		}
	}

	override func viewDidDisappear() {
		super.viewDidDisappear()
	}

	func findBarViewDidChangeHeight() { layout() }

	func layout() {
		warn()
		if let find = findBarView where findBarVisible {
			find.frame = CGRect(x: view.bounds.origin.x,
				y: view.bounds.origin.y + view.bounds.size.height - find.frame.size.height,
				width: view.bounds.size.width, height: find.frame.size.height)
			webview.frame = CGRect(x: view.bounds.origin.x, y: view.bounds.origin.y, width: view.bounds.size.width,
				height: view.bounds.size.height - find.frame.size.height)
		} else {
			webview.frame = view.bounds
		}
	}

	override func viewWillLayout() {
		//webview.resizeSubviewsWithOldSize(CGSizeZero)
		if webview != nil { // vc's still in hierarchy can be asked to layout after view is deinit'd
			webview._inspectorAttachmentView = webview
		}
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
		/*
		for histItem in webview.backForwardList.backList {
			let mi = NSMenuItem(title:(histItem.title ?? histItem.URL.absoluteString), action:Selector("gotoHistoryMenuURL:"), keyEquivalent:"" )
			mi.representedObject = histItem.URL
			mi.target = self
		}
		*/
	}
}

extension WebViewControllerOSX { // AppGUI funcs

	override func closeTab() {
		webview._inspectorAttachmentView = nil
		//view?.removeFromSuperviewWithoutNeedingDisplay()
		super.closeTab()
	}

	func toggleTransparency() { webview.transparent = !webview.transparent; viewDidAppear() }  // WKPageForceRepaint(webview.topFrame?.pageRef, 0, didForceRepaint);

#if STP
	func zoomIn() { webview._viewScale += 0.2 }
	func zoomOut() { webview._viewScale -= 0.2 }
#else
	func zoomIn() { webview.magnification += 0.2 }
	func zoomOut() { webview.magnification -= 0.2 }
#endif
	func zoomText() {
		webview._textZoomFactor = webview._textZoomFactor
		webview._pageZoomFactor = webview._pageZoomFactor
	}

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

	func snapshotButtonClicked(sender: AnyObject?) {
		//guard if let btn = sender as? NSView else { }
		return // WKWebViewSnappable can't link yet :-(
		/*
		guard let thumb = webview.thumbnail else { return }
		var poprect = view.bounds
		let snap = NSViewController()
		snap.view = thumb
		poprect.size.height -= snap.view.frame.height + 12 // make room at the top to stuff the popover
		presentViewController(snap, asPopoverRelativeToRect: poprect, ofView: view, preferredEdge: NSRectEdge.MaxY, behavior: NSPopoverBehavior.Transient)
		*/
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

/*
	func validateUserInterfaceItem(anItem: NSValidatedUserInterfaceItem) -> Bool {
		switch (anItem.action().description) {
			case "performTextFinderAction:":
				if let action = NSTextFinderAction(rawValue: anItem.tag()) where textFinder.validateAction(action) { return true }
			default:
				break
		}
		return false
		//return webview.validateUserInterfaceItem(anItem)
	}
*/

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
