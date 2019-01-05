/// MacPin OmniBoxController
///
/// Controls a textfield that displays a WebViewController's current URL and accepts editing to change loaded URL in WebView

import AppKit
import WebKit
extension WKWebView {
	@objc override open func setValue(_ value: Any?, forUndefinedKey key: String) {
		if key != "URL" { super.setValue(value, forUndefinedKey: key) } //prevents URLbox from trying to directly rewrite webView.URL
		// copy by ref?
	}
}

class URLAddressField: NSTextField { // FIXMEios UILabel + UITextField
	@objc dynamic var isLoading: Bool = false { didSet { needsDisplay = true } } // cell.needsDisplay = true
	@objc dynamic var progress: Double = Double(0.0) { didSet { needsDisplay = true } }

	let thickness = CGFloat(3) // progress line thickness

	//var baselineOffsetFromBottom: CGFloat { get } // http://www.openradar.me/36672952

	//override init(frame frameRect: NSRect) {
	//	self.super(frame: frameRect)
	func viewDidLoad() {
		isSelectable = true
		isEditable = true
	}

	override func draw(_ dirtyRect: NSRect) {
		var bezel: NSBezierPath = NSBezierPath(roundedRect: NSInsetRect(bounds, 2, 2), xRadius: 5, yRadius: 5)
			// approximating the geo of 10.10's .roundedBezel
			NSColor.darkGray.set(); bezel.stroke() // draw bezel
	    	bezel.addClip() // constrain further drawing within bezel

		if isLoading {
			// draw a Safari style progress-line along edge of the text box's focus ring
			//var progressRect = NSOffsetRect(bounds, 0, 4) // top edge of bezel
			var progressRect = NSOffsetRect(bounds, 0, NSMaxY(bounds) - (thickness + 2)) // bottom edge of bezel

			progressRect.size.height = thickness
			progressRect.size.width *= progress == 1.0 ? 0 : CGFloat(progress) // only draw line when downloading

			//NSColor(calibratedRed:0.0, green: 0.0, blue: 1.0, alpha: 0.4).set() // transparent blue line
			// FIXME alpha get overwhelmed when bg/appearance is light
			NSColor.systemBlue.set() // matches "Highlight Color: Blue" from SysPrefs:General
			progressRect.fill(using: .sourceOver)
		} else {
	    	NSColor.clear.setFill() // clear background
			bounds.fill(using: .copy) // .clear
		}

		super.draw(dirtyRect) // draw control's built-in bezel, background (if not a rounded bezel), & text
	}

	// NSControl
	override func validateProposedFirstResponder(_ responder: NSResponder, for event: NSEvent?) -> Bool {
		//warn(event?.description ?? "")
		//warn(obj: responder)
		//warn(obj: event)
		return true
	}

	// NSTextDelegate
	//override func textShouldBeginEditing(_ textObject: NSText) -> Bool { warn(); return true } //allow editing
}
/* iOS progbar: http://stackoverflow.com/questions/29410849/unable-to-display-subview-added-to-wkwebview?rq=1
        webview?.addObserver(self, forKeyPath: "estimatedProgress", options: .New, context: nil)
        let progressView = UIProgressView(progressViewStyle: .Bar)
        progressView.center = view.center
        progressView.progress = 20.0/30.0
        progressView.trackTintColor = UIColor.lightGrayColor()
        progressView.tintColor = UIColor.blueColor()
        webview?.addSubview(progressView)
*/

@objc class OmniBoxController: NSViewController {
	let urlbox = URLAddressField()
	@objc weak var webview: MPWebView? = nil {
		didSet { //KVC to copy updates to webviews url & title (user navigations, history.pushState(), window.title=)
			if let wv = webview {
				view.bind(NSBindingName.toolTip, to: wv, withKeyPath: #keyPath(MPWebView.title), options: nil)
				view.bind(NSBindingName.value, to: wv, withKeyPath: #keyPath(MPWebView.url), options: nil)
				view.bind(NSBindingName.fontBold, to: wv, withKeyPath: #keyPath(MPWebView.hasOnlySecureContent), options: nil)
// TODO: mimic Safari UX for SSL sites: https://www.globalsign.com/en/blog/how-to-view-ssl-certificate-details/#safari
				view.bind(NSBindingName("isLoading"), to: wv, withKeyPath: #keyPath(MPWebView.isLoading), options: nil)
				view.bind(NSBindingName("progress"), to: wv, withKeyPath: #keyPath(MPWebView.estimatedProgress), options: nil)
				view.nextResponder = wv // passthru uncaptured selectors from omnibox tf to webview
				view.nextKeyView = wv
			}
		}
		willSet(newwv) {
			if let _ = webview {
				// we had one already set, so unwind all its entanglements
				view.nextResponder = nil
				view.nextKeyView = nil
				view.unbind(NSBindingName.toolTip)
				view.unbind(NSBindingName.value)
				view.unbind(NSBindingName.fontBold)
				view.unbind(NSBindingName("progress"))
				view.unbind(NSBindingName("isLoading"))
			}
		}
	}

	required init?(coder: NSCoder) { super.init(coder: coder) }
	override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) { super.init(nibName:nil, bundle:nil) } // calls loadView()
	override func loadView() { view = urlbox } // NIBless

	func popup(_ webview: MPWebView?) {
		guard let webview = webview else { return }
		MacPinApp.shared.appDelegate?.browserController.tabSelected = webview // EWW
	}

	/*
	convenience init(webViewController: WebViewController?) {
		self.init()
		preferredContentSize = CGSize(width: 600, height: 24) //app hangs on view presentation without this!
		if let wvc = webViewController { representedObject = wvc }
	}
	*/

	convenience init() {
		self.init(nibName:nil, bundle:nil)
		preferredContentSize = CGSize(width: 600, height: 24) //app hangs on view presentation without this!
	}

	override func viewDidLoad() {
		super.viewDidLoad()
 		// prepareForReuse() {...} ?

		urlbox.isBezeled = true
		urlbox.bezelStyle = .roundedBezel
		let appearance = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") ?? "Light"
		if appearance == "Dark" {
			urlbox.textColor = NSColor.labelColor
			// BUG: 10.11 dark-dock + high-constrast mode set a black textColor on a black-menu-bar-bg
		}
		urlbox.toolTip = ""

		urlbox.maximumNumberOfLines = 1
		urlbox.importsGraphics = false
		urlbox.allowsEditingTextAttributes = false

		//urlbox.menu = NSMenu //ctrl-click context menu
		// search with DuckDuckGo
		// go to URL
		// js: addOmniBoxActionHandler('send to app',handleCustomOmniAction)
		// tab menu?

		urlbox.delegate = self

		if let cell = urlbox.cell as? NSTextFieldCell {
			cell.placeholderString = "Navigate to URL"
			cell.isScrollable = true
			cell.action = #selector(OmniBoxController.userEnteredURL)
			cell.target = self
			cell.sendsActionOnEndEditing = false //only send action when Return is pressed
			cell.usesSingleLineMode = true
			cell.focusRingType = .none
			//cell.currentEditor()?.delegate = self // do live validation of input URL before Enter is pressed
		}

		// should have a grid of all tabs below the urlbox, safari style. NSCollectionView?
		// https://developer.apple.com/library/mac/samplecode/GridMenu/Listings/ReadMe_txt.html#//apple_ref/doc/uid/DTS40010559-ReadMe_txt-DontLinkElementID_14
		// or just show a segmented tabcontrol if clicking in the urlbox?
	}

	override func viewWillAppear() {
		super.viewWillAppear()
	}

	override func viewDidAppear() {
		super.viewDidAppear()
	}

	@objc func userEnteredURL() {
		if let tf = view as? NSTextField, let url = validateURL(tf.stringValue, fallback: { [unowned self] (urlstr: String) -> URL? in
			if AppScriptRuntime.shared.anyHandled(.handleUserInputtedInvalidURL, urlstr as NSString, self.webview!) { return nil } // app.js did its own thing
			if AppScriptRuntime.shared.anyHandled(.handleUserInputtedKeywords, urlstr as NSString, self.webview!) { return nil } // app.js did its own thing
			//FIXME: it should be able to return URL<->NSURL
			return searchForKeywords(urlstr)
		}){
			if let wv = webview { // FIXME: Selector(gotoURL:) to nextResponder
				view.window?.makeFirstResponder(wv) // no effect if this vc was brought up as a modal sheet
				warn(url.description)
				wv.gotoURL(url)
				cancelOperation(self)
			} else if let parent = parent { // tab-less browser window ...
				parent.addChild(WebViewControllerOSX(webview: MPWebView(url: url))) // is parentVC the toolbar or contentView VC??
			} else if let presenter = presentingViewController { // urlbox is a popover/sheet ...
				presenter.addChild(WebViewControllerOSX(webview: MPWebView(url: url)))
				// need parent of the presenter?
			} else {
				warn("no webviews-tabs and no parentVC ... WTF!!")
				if let win = view.window {
					//	win.performSelector(onMainThread: #selector(BrowserViewControllerOSX.newTabPrompt), with: nil, waitUntilDone: false, modes: nil)
					// win's responderChain is useless ...
				}
			}
		} else {
			warn("invalid url was requested!")
			//displayAlert
			//NSBeep()
		}
	}

	override func cancelOperation(_ sender: Any?) {
		warn()
		view.resignFirstResponder() // relinquish key focus to webview
		presentingViewController?.dismiss(self) //if a thoust art a popover, close thyself
	}

	deinit { webview = nil; representedObject = nil }
}

extension OmniBoxController: NSTextFieldDelegate { //NSControl
	//func controlTextDidBeginEditing(_ obj: NSNotification)
	//func controlTextDidChange(_ obj: NSNotification)
	//func controlTextDidEndEditing(_ obj: NSNotification)
}

	/*
		replace textvalue with URL value, might be bound to title
		"smart search" behavior:
		if url was a common search provider query...
			duckduckgo.com/?q=...
			www.google.com/search?q=...
		then extract the first query param, decode, and set the text value to that
	*/

/*

	//func textDidChange(aNotification: NSNotification)
	@objc func textShouldEndEditing(_ textObject: NSText) -> Bool { //user attempting to focus out of field
		if let _ = validateURL(textObject.string) { return true } //allow focusout
		warn("invalid url entered: \(textObject.string)")
		return false //NSBeep()s, keeps focus
	}
	//func textDidEndEditing(aNotification: NSNotification) {	}
*/

@objc extension OmniBoxController: NSControlTextEditingDelegate {
//func control(_ control: NSControl, isValidObject obj: AnyObject) -> Bool
//func control(_ control: NSControl, didFailToFormatString string: String, errorDescription error: String?) -> Bool
	func control(_ control: NSControl, textShouldBeginEditing fieldEditor: NSText) -> Bool { warn(); return true }
//func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool
//func control(_ control: NSControl, textView textView: NSTextView, completions words: [String], forPartialWordRange charRange: NSRange, indexOfSelectedItem index: UnsafeMutablePointer<Int>) -> [String]

	func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
		warn(commandSelector.description)
		switch commandSelector {
			case "noop:":
				if let event = Application.shared.currentEvent, event.modifierFlags.contains(.command) {
					guard let url = validateURL(control.stringValue) else { return false }
					popup(webview?.clone(url)) // cmd-enter pops open a new tab
				}
				fallthrough
			//case "insertLineBreak:":
			//   .ShiftKeyMask gotoURL privately (Safari opens new window with Shift)
			//   .AltKeyMask  // gotoURL w/ new session privately (Safari downloads with Alt

			// when Selector("insertTab:"):
			// scrollToBeginningOfDocument: scrollToEndOfDocument:
			default: return false
		}
	}
}

extension OmniBoxController: NSPopoverDelegate {
	func popoverWillShow(_ notification: Notification) {
		//urlbox.sizeToFit() //fixme: makes the box undersized sometimes
	}
}
