import WebKit
import WebKitPrivates

@objc protocol WebViewScriptExports : JSExport { // 'var tab = $browser.newTab({...})' in app.js
	var isTransparent: Bool { get set }
	func close()
	func evalJS(js: String)
	func loadURL(urlstr: String) -> Bool
	func loadIcon(icon: String) -> Bool
}

class WebViewController: NSViewController {
	var webview = WKWebView(frame: CGRectZero)

	//let backMenu = NSMenu()
	//let forwardMenu = NSMenu()
		
	dynamic unowned var favicon: NSImage = NSImage(named: NSImageNameApplicationIcon)! { // NSImageNameStatusNone
		didSet {
			if let name = favicon.name() { warn("\(__FUNCTION__) = \(name)") }
			favicon.size = NSSize(width: 16, height: 16)
		}
		//need 24 & 36px**2 representations for the NSImage for bigger grid views
		// https://developer.apple.com/library/ios/documentation/AppleApplications/Reference/SafariWebContent/ConfiguringWebApplications/ConfiguringWebApplications.html
		// just C, no Cocoa API yet: WKIconDatabaseCopyIconURLForPageURL(icodb, url) WKIconDatabaseCopyIconDataForPageURL(icodb, url)
		// also https://github.com/WebKit/webkit/commit/660d1e55c2d1ee19ece4a7565d8df8cab2e15125
		// OSX has libxml2 built-in https://developer.apple.com/library/mac/samplecode/LinkedImageFetcher/Listings/Read_Me_About_LinkedImageFetcher_txt.html
	}

	var isTransparent: Bool = false {
		didSet {
			if let window = view.window {
				window.disableFlushWindow()
				browser?.isTransparent = isTransparent
			}
			webview._drawsTransparentBackground = isTransparent
			//^ background-color:transparent sites immediately bleedthru to a black CALayer, which won't go clear until the content is reflowed or reloaded
			webview.setFrameSize(NSSize(width: webview.frame.size.width, height: webview.frame.size.height - 1)) //needed to fully redraw w/ dom-reflow or reload! 
			evalJS("window.dispatchEvent(new window.CustomEvent('MacPinTransparencyChanged',{'detail':{'isTransparent': \(isTransparent)}}));" +
				"document.head.appendChild(document.createElement('style')).remove();") //force redraw in case event didn't
			webview.setFrameSize(NSSize(width: webview.frame.size.width, height: webview.frame.size.height + 1))
			webview.window?.enableFlushWindow()
			webview.needsDisplay = true
			webview.window?.flushWindowIfNeeded()
		}
	}

	var browser: BrowserViewController? { get {
		if let browser = presentingViewController? as? BrowserViewController { return browser }
		if let browser = parentViewController? as? BrowserViewController { return browser }
		return nil
	}}

	required init?(coder: NSCoder) { super.init(coder: coder) }
	override init?(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) { super.init(nibName:nil, bundle:nil) } //calls loadView
	override func loadView() { view = webview } // NIBless  

	init(config: WKWebViewConfiguration? = WKWebViewConfiguration()) {
		super.init() // calls init(nibName) via ??
		if let config = config {
			// reinit webview with custom config, needed for JS:window.open() which links new child Windows to parent Window
			var prefs = WKPreferences() // http://trac.webkit.org/browser/trunk/Source/WebKit2/UIProcess/API/Cocoa/WKPreferences.mm
			prefs.plugInsEnabled = true // NPAPI for Flash, Java, Hangouts
			//prefs.minimumFontSize = 14 //for blindies
			prefs.javaScriptCanOpenWindowsAutomatically = true;
			prefs._developerExtrasEnabled = true // http://trac.webkit.org/changeset/172406 will land in OSX 10.10.3?
#if WK2LOG
			//prefs._diagnosticLoggingEnabled = true //10.10.3?
#endif
			config.preferences = prefs
			config.suppressesIncrementalRendering = false
			//withConfiguration._websiteDataStore = _WKWebsiteDataStore.nonPersistentDataStore
			webview = WKWebView(frame: CGRectZero, configuration: config)
		}
	}

	convenience init(agent: String? = nil, configuration: WKWebViewConfiguration? = nil) {
		self.init(config: configuration)
		if let agent = agent { if !agent.isEmpty { webview._customUserAgent = agent } }
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		//view.wantsLayer = true //use CALayer to coalesce views
		view.autoresizingMask = .ViewWidthSizable | .ViewHeightSizable
		if let wkview = view.subviews.first as? WKView {
			//wkview.setValue(false, forKey: "shouldExpandToViewHeightForAutoLayout") //KVO
			//wkview.shouldExpandToViewHeightForAutoLayout = false
			//wkview.postsFrameChangedNotifications = false //FIXME stop webinspector flicker?
			//view.postsBoundsChangedNotifications = false //FIXME stop webinspector flicker?
		}

		webview._applicationNameForUserAgent = "Version/8.0.2 Safari/600.2.5"
		webview.allowsBackForwardNavigationGestures = true
		webview.allowsMagnification = true
#if SAFAG
		webview._allowsRemoteInspection = true // start webinspectord child
		// enables Safari.app->Develop-><computer name> remote debugging of JSCore and all webviews' JS threads
		// http://stackoverflow.com/questions/11361822/debug-ios-67-mobile-safari-using-the-chrome-devtools
#endif
		//webview._editable = true // https://github.com/WebKit/webkit/tree/master/Tools/WebEditingTester
		// https://github.com/WebKit/webkit/blob/master/Source/WebCore/page/mac/UserAgentMac.mm#L48

		bind(NSTitleBinding, toObject: webview, withKeyPath: "title", options: nil)
		webview.navigationDelegate = self // allows/denies navigation actions
		webview.UIDelegate = self //alert(), window.open()	
		//backMenu.delegate = self
		//forwardMenu.delegate = self
	}
	
	override func viewWillAppear() { // window popping up with this tab already selected & showing
		super.viewWillAppear()
		if let browser = browser { 
			browser.isTransparent = isTransparent
		 }
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
		//warn("\(__FUNCTION__) WKWebView \(view.frame)")
		//warn("\(__FUNCTION__) WKWebView subviews #\(view.subviews.count)")
		//warn("\(__FUNCTION__) WKWebView autoResizes subviews \(view.autoresizesSubviews)")i

		// https://github.com/WebKit/webkit/blob/aefe74816c3a4db1b389893469e2d9475bbc0fd9/Source/WebKit2/UIProcess/mac/WebInspectorProxyMac.mm#L809
		// inspectedViewFrameDidChange is looping itself
		// ignoreNextInspectedViewFrameDidChange is supposed to prevent this

		if let wkview = view.subviews.first? as? NSView {
			if wkview.tag == 1000 { //WKInspectorViewTag
				// wkview.autoresizingMask == .ViewWidthSizable | .ViewMaxYMargin {
				warn("\(__FUNCTION__) webinpector layout \(wkview.frame)") //probably a webinspector
				if let pageView = view.subviews.last? as? NSView { // tag=-1 should be the page content
					warn("\(__FUNCTION__) page layout \(pageView.frame)")
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
		warn("\(__FUNCTION__) \(view.frame)")
#endif
		//super.updateViewContraints()
		view.updateConstraints()
		//view.removeConstraints(view.constraints)
	}

	//override func removeFromParentViewController() { super.removeFromParentViewController() }

	deinit {
		warn("\(__FUNCTION__) \(reflect(self).summary)")
		unbind(NSTitleBinding)
	}

}

extension WebViewController: NSMenuDelegate {
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

extension WebViewController: WebViewScriptExports { // AppGUI / ScriptRuntime funcs
	override func cancelOperation(sender: AnyObject?) { webview.stopLoading(sender) } //make Esc key stop page load

	func evalJS(js: String) { webview.evaluateJavaScript(js, completionHandler: nil) }

	func conlog(msg: String) { // _ webview: WKWebView? = nil
		warn(msg)
#if APP2JSLOG
		evalJS("console.log(\'<\(__FILE__)> \(msg)\')")
#endif
	}

	func close() { removeFromParentViewController() }

	func grabWindow() -> NSWindow? {
		// make this take a closure instead?
		// and provide a window if one from the (non-existent?) parent isn't found?
		browser?.tabSelected = self
		if let window = view.window { return window }
		return nil
	}

	func print(sender: AnyObject?) { warn(__FUNCTION__); webview.print(sender) }

	func zoomIn() { webview.magnification += 0.2 }
	func zoomOut() { webview.magnification -= 0.2 }
	func toggleTransparency() { isTransparent = !isTransparent }

	func highlightConstraints() { view.window?.visualizeConstraints(view.constraints) }

	func replaceContentView() { view.window?.contentView = view }

	func shareButtonClicked(sender: AnyObject?) {
		if let btn = sender? as? NSView {
			if let url = webview.URL {
				var sharer = NSSharingServicePicker(items: [url] )
				sharer.delegate = self
				sharer.showRelativeToRect(btn.bounds, ofView: btn, preferredEdge: NSMinYEdge)
			}
		}
	}

	func gotoURL(url: NSURL) {
		if url.scheme == "file" {
			//webview.loadFileURL(url, allowingReadAccessToURL: url.URLByDeletingLastPathComponent!) //load file and allow link access to its parent dir
			//		waiting on http://trac.webkit.org/changeset/174029/trunk to land
			//webview._addOriginAccessWhitelistEntry(WithSourceOrigin:destinationProtocol:destinationHost:allowDestinationSubdomains:)
			// need to allow loads from file:// to inject NSBundle's CSS
		}
		webview.loadRequest(NSURLRequest(URL: url))
	}
	func loadURL(urlstr: String) -> Bool { // overloading gotoURL is crashing Cocoa selectors
		if let url = NSURL(string: urlstr) { 
			gotoURL(url as NSURL)
			return true
		}
		return false // tell JS we were given a malformed URL
	}

	func gotoButtonClicked(sender: AnyObject?) {
		let urlbox = URLBoxController(webViewController: self)

		if let btn = sender? as? NSButton {
			if let cell = btn.cell()? as? NSCell {
				conlog("\(__FUNCTION__) mouseDownFlags:\(cell.mouseDownFlags)")
			} 
		} 

		if let sender = sender? as? NSView { //OpenTab toolbar button
			presentViewController(urlbox, asPopoverRelativeToRect: sender.bounds, ofView: sender, preferredEdge:NSMinYEdge, behavior: .Semitransient)
		} else { //keyboard shortcut
			//presentViewControllerAsSheet(urlbox) // modal, yuck
			var poprect = view.bounds
			poprect.size.height -= urlbox.preferredContentSize.height + 12 // make room at the top to stuff the popover
			presentViewController(urlbox, asPopoverRelativeToRect: poprect, ofView: view, preferredEdge: NSMaxYEdge, behavior: .Semitransient)
		}
	}

	func askToOpenURL(url: NSURL) {
		if let window = grabWindow() {
			if let opener = NSWorkspace.sharedWorkspace().URLForApplicationToOpenURL(url) {
				conlog("\(__FUNCTION__): [\(url)]")
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
			let error = NSError(domain: "MacPin", code: 2, userInfo: [
				NSURLErrorKey: url,
				NSLocalizedDescriptionKey: "No program present on this system is registered to open this non-browser URL.\n\n\(url)"
			])
			view.presentError(error, modalForWindow: window, delegate: nil, didPresentSelector: nil, contextInfo: nil)
		}
	}

	func scrapeIcon(webview: WKWebView) {
		// https://code.google.com/p/cocoalicious/source/browse/trunk/cocoalicious/Utilities/SFHFFaviconCache.m

		// check the cache first
		if let url = webview.URL {
			if let host = url.host {
				if let icon = NSImage(named: host) { 
					self.favicon = icon
					return
				}
			}
		}

		webview.evaluateJavaScript("document.querySelector('link[rel$=icon]').href;", completionHandler:{ [unowned self] (result: AnyObject!, exception: NSError!) -> Void in
			if let href = result as? String {
				if let url = NSURL(string: href) {
					if let icon = NSImage(contentsOfURL: url) {
						if let host = url.host { icon.setName(host) } // add cache name
						self.favicon = icon
					}
				}
			} else {
				// look for a root-domain-level icon file
				if let url = webview.URL {
					let iconurlp = NSURLComponents(URL: url, resolvingAgainstBaseURL: false)!
					iconurlp.path = "/favicon.ico"
					if let iconurl = iconurlp.URL {
						let request = NSURLRequest(URL: iconurl)
						NSURLConnection.sendAsynchronousRequest(request, queue: NSOperationQueue.mainQueue()) { [unowned self] (response, data, error) in
							if data != nil { 
								if let icon = NSImage(data: data) { 
									if let host = iconurl.host { icon.setName(host) } // add cache name
									self.favicon = icon
								}
							}
						}
					}
				}
			}
		})
	}

	func loadIcon(icon: String) -> Bool {
		if !icon.isEmpty { 
			favicon = NSImage(byReferencingURL: NSURL(string: icon)!)
			return true
		}
		return false
	}

}

extension WebViewController: NSSharingServicePickerDelegate { }
