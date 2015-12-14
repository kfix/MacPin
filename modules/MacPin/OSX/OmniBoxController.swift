/// MacPin OmniBoxController
///
/// Controls a textfield that displays a WebViewController's current URL and accepts editing to change loaded URL in WebView

import AppKit
import WebKit
extension WKWebView {
	override public func setValue(value: AnyObject?, forUndefinedKey key: String) {
		if key != "URL" { super.setValue(value, forUndefinedKey: key) } //prevents URLbox from trying to directly rewrite webView.URL
	}
}

import AppKit

class URLAddressField: NSTextField { // FIXMEios UILabel + UITextField
	var isLoading: Bool = false { didSet { needsDisplay = true } }
	var progress: Double = Double(0.0) { didSet { needsDisplay = true } }

	override func drawRect(dirtyRect: NSRect) {
		if isLoading {
			// draw a Safari style progress-line along edge of the text box's focus ring
			//var progressRect = NSOffsetRect(bounds, 0, 4) // top edge
			var progressRect = NSOffsetRect(bounds, 0, NSMaxY(bounds) - 4) // bottom edge
			progressRect.size.height = 6 // line thickness
			progressRect.size.width *= progress == 1.0 ? 0 : CGFloat(progress) // only draw line when downloading

			NSColor(calibratedRed:0.0, green: 0.0, blue: 1.0, alpha: 0.4).set() // transparent blue line
			NSRectFillUsingOperation(progressRect, .CompositeSourceOver)
		} else {
			//NSRectFillUsingOperation(bounds, .CompositeClear)
			NSRectFillUsingOperation(bounds, .CompositeCopy)
		}
		super.drawRect(dirtyRect)
	}
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
	var webview: MPWebView? = nil {
		didSet { //KVC to copy updates to webviews url & title (user navigations, history.pushState(), window.title=)
			if let wv = webview {
				view.bind(NSToolTipBinding, toObject: wv, withKeyPath: "title", options: nil)
				view.bind(NSValueBinding, toObject: wv, withKeyPath: "URL", options: nil)
				view.bind(NSFontBoldBinding, toObject: wv, withKeyPath: "hasOnlySecureContent", options: nil)
				view.bind("isLoading", toObject: wv, withKeyPath: "isLoading", options: nil)
				view.bind("progress", toObject: wv, withKeyPath: "estimatedProgress", options: nil)
				nextResponder = wv
				view.nextKeyView = wv
			}
		}
		willSet(newwv) { 
			if let _ = webview {
				nextResponder = nil
				view.nextKeyView = nil
				view.unbind(NSToolTipBinding)
				view.unbind(NSValueBinding)
				view.unbind(NSFontBoldBinding)
				view.unbind("progress")
				view.unbind("isLoading")
			}
		}
	}

	required init?(coder: NSCoder) { super.init(coder: coder) }
	override init!(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) { super.init(nibName:nil, bundle:nil) } // calls loadView() 
	override func loadView() { view = urlbox } // NIBless
 
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
		urlbox.wantsLayer = true
		urlbox.bezelStyle = .RoundedBezel
		urlbox.drawsBackground = false
		urlbox.textColor = NSColor.labelColor() 
		urlbox.toolTip = ""
		//urlbox.menu = NSMenu //ctrl-click context menu
		// search with DuckDuckGo
		// go to URL
		// js: addOmniBoxActionHandler('send to app',handleCustomOmniAction)
		// tab menu?

		urlbox.delegate = self

		if let cell = urlbox.cell as? NSTextFieldCell {
			cell.placeholderString = "Navigate to URL"
			cell.scrollable = true
			cell.action = Selector("userEnteredURL")
			cell.target = self
			cell.sendsActionOnEndEditing = false //only send action when Return is pressed
			cell.usesSingleLineMode = true
			cell.focusRingType = .None
			//cell.currentEditor()?.delegate = self // do live validation of input URL before Enter is pressed
			// FIXME: handle cmd+enter for open in new tab
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

	func userEnteredURL() {
		if let tf = view as? NSTextField, url = validateURL(tf.stringValue, fallback: { [unowned self] (urlstr: String) -> NSURL? in 
			if AppScriptRuntime.shared.jsdelegate.tryFunc("handleUserInputtedInvalidURL", urlstr, self.webview ?? false) { return nil } // app.js did its own thing FIXME: it should be able to return URL<->NSURL
			return nil
		}){
			if let wv = webview { // FIXME: Selector(gotoURL:) to nextResponder
				view.window?.makeFirstResponder(wv) // no effect if this vc was brought up as a modal sheet
				warn(url.description)
				wv.gotoURL(url)
				cancelOperation(self)
			} else { // tab-less browser window ...
				parentViewController?.addChildViewController(WebViewControllerOSX(webview: MPWebView(url: url))) // is parentVC the toolbar or contentView VC??
			}
		} else {
			warn("invalid url was requested!")
			//displayAlert
			//NSBeep()
		}
	}
	
	override func cancelOperation(sender: AnyObject?) { 
		view.resignFirstResponder() // relinquish key focus to webview
		presentingViewController?.dismissViewController(self) //if a thoust art a popover, close thyself
	}

	deinit { webview = nil; representedObject = nil }
}

extension OmniBoxController: NSTextFieldDelegate {
	//func textShouldBeginEditing(textObject: NSText) -> Bool { return true } //allow editing
		//replace textvalue with URL value, should normally be bound to title

	//func textDidChange(aNotification: NSNotification)
	func textShouldEndEditing(textObject: NSText) -> Bool { //user attempting to focus out of field
		if let _ = validateURL(textObject.string ?? "") { return true } //allow focusout
		warn("invalid url entered: \(textObject.string)")
		return false //NSBeep()s, keeps focus
	}
	//func textDidEndEditing(aNotification: NSNotification) {	}
}

extension OmniBoxController: NSPopoverDelegate {	
	func popoverWillShow(notification: NSNotification) {
		//urlbox.sizeToFit() //fixme: makes the box undersized sometimes
	}
}
