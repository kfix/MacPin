import WebKit
public extension WKWebView {
	override func setValue(value: AnyObject?, forUndefinedKey key: String) {
		if key != "URL" { super.setValue(value, forUndefinedKey: key) } //prevents URLbox from trying to directly rewrite webView.URL
	}
}

import Cocoa

class URLBoxController: NSViewController {	
	let urlbox = NSTextField()
	//let progbar = NSProgressIndicator(frame: CGRectZero)

	override var representedObject: AnyObject? {
		didSet { //KVC to copy updates to webviews url & title (user navigations, history.pushState(), window.title=)
			view.bind(NSToolTipBinding, toObject: self, withKeyPath: "representedObject.view.title", options: nil)
			view.bind(NSValueBinding, toObject: self, withKeyPath: "representedObject.view.URL", options: nil)
			view.bind(NSFontItalicBinding, toObject: self, withKeyPath: "representedObject.view.isLoading", options: nil)
			//progbar.bind("doubleValue", toObject: self, withKeyPath: "representedObject.view.estimatedProgress", options: nil)
			if let focusObj = representedObject as? NSViewController {
				nextResponder = focusObj
				view.nextKeyView = focusObj.view
			}
		}
		willSet(newro) { 
			view.unbind(NSToolTipBinding)
			view.unbind(NSValueBinding)
			view.unbind(NSFontItalicBinding)
			//progbar.unbind("doubleValue")
		}
	}

	// NIBless  
	required init?(coder: NSCoder) { super.init(coder: coder) }
	override init?(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) { super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil) }
	override init() { super.init() }
	override func loadView() { view = urlbox }

	convenience init(webViewController: WebViewController?) {
		self.init()
		preferredContentSize = CGSize(width: 600, height: 24) //app hangs on view presentation without this!
		if let webVC = webViewController { representedObject = webVC }

 		// prepareForReuse() {...} ?
		urlbox.bezelStyle = .RoundedBezel
		urlbox.drawsBackground = false
		urlbox.textColor = NSColor.controlTextColor() 
		urlbox.toolTip = ""
		//urlbox.wantsLayer = true
		//urlbox.editable = false
		//urlbox.menu = NSMenu //ctrl-click context menu

		urlbox.delegate = self

		if let cell = urlbox.cell() as? NSTextFieldCell {
			cell.placeholderString = "Navigate to URL"
			cell.scrollable = true
			cell.action = Selector("userEnteredURL")
			//cell.target = nil // on Enter, send action up the Responder chain
			cell.target = self
			cell.sendsActionOnEndEditing = false //only send action when Return is pressed
			cell.usesSingleLineMode = true
			cell.focusRingType = .None
			//cell.currentEditor()?.delegate = self // do live validation of input URL before Enter is pressed
		}
		//view.addSubview(progbar)
	}

	override func viewDidLoad() {
		super.viewDidLoad()
	}

	override func viewWillAppear() {
		super.viewWillAppear()
		//progbar.removeFromSuperview()
		//urlbox.sizeToFit()
	}

	override func viewDidAppear() {
		super.viewDidAppear()
		//progbar.style = .BarStyle // .SpinningStyle
		//progbar.thickness = .PreferredLargeThickness
		//progbar.maxValue = Double(1.0)
		//view.addSubview(progbar, positioned: .Above, relativeTo: nil) // bind this to estimatedProgres...
	}

	func userEnteredURL() {
		var urlstr = (view as NSTextField).stringValue
		if let url = validateURL(urlstr) {
			if let wvc = representedObject? as? WebViewController { //would be cool if I could just kick up gotoURL to nextResponder as NSResponder
				view.window?.makeFirstResponder(wvc.view)
				wvc.gotoURL(url as NSURL)
				//view.addSubview(progbar)
				//wait for isLoaded == true
				presentingViewController?.dismissViewController(self) //if a thoust art a popover, close thyself
			}
		} else {
			warn("\(__FUNCTION__): invalid url `\(urlstr)` was requested!")
			//NSBeep()
		}
	}
	
	override func cancelOperation(sender: AnyObject?) { presentingViewController?.dismissViewController(self) } //if a thoust art a popover, close thyself
}

extension URLBoxController: NSTextFieldDelegate {
	//func textShouldBeginEditing(textObject: NSText) -> Bool { return true } //allow editing
	//func textDidChange(aNotification: NSNotification)
	func textShouldEndEditing(textObject: NSText) -> Bool { //user attempting to focus out of field
		if let url = validateURL(textObject.string ?? "") { return true } //allow focusout
		warn("\(__FUNCTION__): invalid url entered: \(textObject.string)")
		return false //NSBeep()s, keeps focus
	}
	//func textDidEndEditing(aNotification: NSNotification) {	}
}

extension URLBoxController: NSPopoverDelegate {	
	func popoverWillShow(notification: NSNotification) {
		//view.frame = NSRect(x:0, y:0, width: 600, height: 24)
	}
}


