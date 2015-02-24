@objc protocol WebViewScriptExports : JSExport { // 'var tab = $browser.newTab({...})' in app.js
	func close()
	func evalJS(js: String)
	func gotoURL(urlstr: String)
	func stealFocus()
}

class WebViewController: NSViewController {
	var browser: BrowserViewController? { get {
		if let browser = presentingViewController? as? BrowserViewController { return browser }
		if let browser = parentViewController? as? BrowserViewController { return browser }
		return nil
	}}

	var webview: WKWebView? { get {
		if let webview = view as? WKWebView { return webview }
		return nil
	}}

	var _webprefs: WKPreferences {
		get {
			var prefs = WKPreferences() // http://trac.webkit.org/browser/trunk/Source/WebKit2/UIProcess/API/Cocoa/WKPreferences.mm
			prefs.plugInsEnabled = true // NPAPI for Flash, Java, Hangouts
			//prefs.minimumFontSize = 14 //for blindies
			prefs.javaScriptCanOpenWindowsAutomatically = true;
			prefs._developerExtrasEnabled = true // http://trac.webkit.org/changeset/172406 will land in OSX 10.10.3?
#if WK2LOG
			//prefs._diagnosticLoggingEnabled = true //10.10.3?
#endif
			return prefs
		}
	}
	
	required init?(coder: NSCoder) { super.init(coder: coder) }

	init?(agent: String? = nil, configuration: WKWebViewConfiguration = WKWebViewConfiguration()) {
		super.init(nibName: nil, bundle: nil)
		configuration.preferences = _webprefs
		configuration.suppressesIncrementalRendering = false
		//withConfiguration._websiteDataStore = _WKWebsiteDataStore.nonPersistentDataStore

		let webview = WKWebView(frame: CGRectZero, configuration: configuration)
		webview.allowsBackForwardNavigationGestures = true
		webview.allowsMagnification = true
#if SAFARIDBG
		webview._allowsRemoteInspection = true // start webinspectord child
		// enables Safari.app->Develop-><computer name> remote debugging of JSCore and all webviews' JS threads
		// http://stackoverflow.com/questions/11361822/debug-ios-67-mobile-safari-using-the-chrome-devtools
#endif

		//webview._editable = true // https://github.com/WebKit/webkit/tree/master/Tools/WebEditingTester

		// https://github.com/WebKit/webkit/blob/master/Source/WebCore/page/mac/UserAgentMac.mm#L48
		webview._applicationNameForUserAgent = "Version/8.0.2 Safari/600.2.5"
		if let agent = agent { if !agent.isEmpty { webview._customUserAgent = agent } }

		webview.navigationDelegate = self // allows/denies navigation actions
		webview.UIDelegate = self //alert(), window.open()	

		let wkview = (webview.subviews.first as WKView) // 1 per frame?
		//wkview.shouldExpandToViewHeightForAutoLayout = false
		//wkview.setValue(false, forKey: "shouldExpandToViewHeightForAutoLayout") //KVO

		webview.identifier = "WKWebView:" + NSUUID().UUIDString //set before installing into a view/window, then get ... else crash!
		view = webview
		identifier = "WebViewController<\(webview.identifier)>"
		bind(NSTitleBinding, toObject: view, withKeyPath: "title", options: nil)
		bind("representedObject", toObject: view, withKeyPath: "URL", options: nil)
    }

	override func loadView() {
		super.loadView()
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		//view.frame = NSMakeRect(0, 0, 600, 800) // default size
		//view.frame = parentViewController.view.bounds
		//view.frame = parentViewController.view.window!.contentLayoutRect
		//view.frame = CGRect(x: 0, y: 0, 
	    //	width: CGRectGetWidth(parentViewController.view.bounds), 
	    //	height: CGRectGetHeight(parentViewController.view.bounds))
		//view.frame = view.window!.windowController.window!.contentView.frame
		//view.frame = parentViewController.view.frame
		// http://ashfurrow.com/blog/you-probably-dont-understand-frames-and-bounds/
		// https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/CocoaViewsGuide/WorkingWithAViewHierarchy/WorkingWithAViewHierarchy.html#//apple_ref/doc/uid/TP40002978-CH4-SW12


		//view.wantsLayer = true //use CALayer to coalesce views
		//view.layer?.frame = parentViewController!.view.frame
		//view.layer?.frame = view.window!.contentLayoutRect

		view.autoresizingMask = .ViewWidthSizable | .ViewHeightSizable
		view.postsFrameChangedNotifications = false //FIXME stop webinspector flicker?
	}
	
	override func viewWillAppear() { // window popping up with this tab already selected & showing
		super.viewWillAppear()
		if let window = view.window {
			//window.makeFirstResponder(view)
			//warn("\(__FUNCTION__) \(window.firstResponder)")
		}
		if let webview = webview { if let browser = browser { webview._drawsTransparentBackground = browser.isTransparent } } // use KVC to auto frob this?
	}

	override func viewDidAppear() { // window popping up. & tab switch?
		super.viewDidAppear()
		//view.autoresizesSubviews = false
		//view.translatesAutoresizingMaskIntoConstraints = false
	}

	override func viewWillLayout() {
#if WK2LOG
		//warn("\(__FUNCTION__) WKWebView \(view.frame)")
		warn("\(__FUNCTION__) WKWebView subviews #\(view.subviews.count)")
		warn("\(__FUNCTION__) WKWebView autoResizes subviews #\(view.autoresizesSubviews)")
		if let wkview = view.subviews.first? as? NSView {
			if wkview.autoresizingMask == .ViewWidthSizable | .ViewMaxYMargin {
				// https://github.com/WebKit/webkit/blob/aefe74816c3a4db1b389893469e2d9475bbc0fd9/Source/WebKit2/UIProcess/mac/WebInspectorProxyMac.mm#L809
				warn("\(__FUNCTION__) got bottom-anchored WKView \(wkview.frame)")
				if let pageView = view.subviews.last? as? NSView {
					pageView.autoresizingMask = .ViewWidthSizable
				}
			}
		}
#endif
		super.viewWillLayout()
	}

	override func updateViewConstraints() {
#if WK2LOG
		warn("\(__FUNCTION__) \(view.frame)")
#endif
		//super.updateViewContraints()
		view.updateConstraints()
		//view.removeConstraints(view.constraints)
	}

	//viewWillTransitionToSize(newSize: NSSize) { }

}

extension WebViewController: WebViewScriptExports { // AppGUI / ScriptRuntime funcs

	func evalJS(js: String) { webview?.evaluateJavaScript(js, completionHandler: nil) }

	func conlog(msg: String) { // _ webview: WKWebView? = nil
		warn(msg)
#if APP2JSLOG
		evalJS("console.log(\'<\(__FILE__)> \(msg)\')")
#endif
	}

	func close() { removeFromParentViewController() }
	func stealFocus() { 
		//presentingViewController.tabView.selectTabViewItem(presentingViewController.tabViewItemForViewController(self))
		browser?.tabView.selectTabViewItem(browser?.tabViewItemForViewController(self))
	}

	func grabWindow() -> NSWindow? {
		stealFocus()
		if let window = view.window { return window }
		return nil
	}

	func print(sender: AnyObject?) { warn(__FUNCTION__); webview?.print(sender) }

	func zoomIn() { if let webview = webview { webview.magnification += 0.2 } }
	func zoomOut() { if let webview = webview { webview.magnification -= 0.2 } }

	func highlightConstraints() { view.window?.visualizeConstraints(view.constraints) }

	func shareButtonClicked(sender: AnyObject?) {
		if let btn = sender? as? NSView {
			if let url = webview?.URL {
				var sharer = NSSharingServicePicker(items: [url] )
				sharer.delegate = self
				sharer.showRelativeToRect(btn.bounds, ofView: btn, preferredEdge: NSMinYEdge)
			}
		}
	}

	func gotoURL(url: NSURL) {
		if let webview = webview {
			if url.scheme == "file" {
				//webview.loadFileURL(url, allowingReadAccessToURL: url.URLByDeletingLastPathComponent!) //load file and allow link access to its parent dir
				//		waiting on http://trac.webkit.org/changeset/174029/trunk to land
				//webview._addOriginAccessWhitelistEntry(WithSourceOrigin:destinationProtocol:destinationHost:allowDestinationSubdomains:)
				// need to allow loads from file:// to inject NSBundle's CSS
			}
			webview.loadRequest(NSURLRequest(URL: url))
		}
	}
	func gotoURL(urlstr: String) { gotoURL(NSURL(string: urlstr)!) }

	func gotoButtonClicked(sender: AnyObject?) {
		var urlboxVC = URLBoxController(urlbox: NSTextField())!
		urlboxVC.representedObject = self // KVC bind webview title and URL to urlbox
		urlboxVC.nextResponder = self.view // ensure all menu bindings will walk responder tree starting from webview
		urlboxVC.view.nextKeyView = self.view // TABbing off the urlbox will move focus to selected webview //FIXME not working
		if let btn = sender? as? NSView { 
			presentViewController(urlboxVC, asPopoverRelativeToRect: btn.bounds, ofView: btn, preferredEdge:NSMinYEdge, behavior: .Semitransient)
		} else {
			presentViewControllerAsSheet(urlboxVC) //Keyboard shortcut
		}
	}

	func askToOpenURL(url: NSURL) {
		if let opener = NSWorkspace.sharedWorkspace().URLForApplicationToOpenURL(url) {
			conlog("prompting to externally open URL: [\(url)]")
			let alert = NSAlert()
			alert.messageText = "Open using App:\n\(opener)"
			alert.addButtonWithTitle("OK")
			alert.addButtonWithTitle("Cancel")
			alert.informativeText = url.description
			alert.icon = NSWorkspace.sharedWorkspace().iconForFile(opener.path!)
			if let window = grabWindow() {
				alert.beginSheetModalForWindow(window, completionHandler:{(response:NSModalResponse) -> Void in
					if response == NSAlertFirstButtonReturn { NSWorkspace.sharedWorkspace().openURL(url) }
	 			})
			}
			return
		}
		//FIXME: complain here
		if let window = view.window {
			//var error = NSError(domain: "ProcessName", code: 2, userInfo: [:])
			//view.presentError(error, modalForWindow: window, delegate: nil, didPresentSelector: nil, contextInfo: nil) }
		}
	}

}

extension WebViewController: NSSharingServicePickerDelegate { }
