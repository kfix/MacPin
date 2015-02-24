import WebKit
public extension WKWebView {
	override func setValue(value: AnyObject?, forUndefinedKey key: String) {
		if key != "URL" { super.setValue(value, forUndefinedKey: key) } //prevents URLbox from trying to directly rewrite webView.URL
	}
}

import Cocoa

class URLBoxController: NSViewController {	
	required init?(coder: NSCoder) { super.init(coder: coder) }

	//let progbar = NSProgressIndicator(frame: CGRectZero)
	override var representedObject: AnyObject? {
		didSet { //KVC to copy updates to webviews url & title (user navigations, history.pushState(), window.title=)
			view.bind(NSToolTipBinding, toObject: self, withKeyPath: "representedObject.view.title", options: nil)
			view.bind(NSValueBinding, toObject: self, withKeyPath: "representedObject.view.URL", options: nil)
			view.bind(NSFontItalicBinding, toObject: self, withKeyPath: "representedObject.view.isLoading", options: nil)
			//progbar.bind("doubleValue", toObject: self, withKeyPath: "representedObject.view.estimatedProgress", options: nil)
		}
		willSet(newro) { 
			view.unbind(NSToolTipBinding)
			view.unbind(NSValueBinding)
			view.unbind(NSFontItalicBinding)
			//progbar.unbind("doubleValue")
		}
	}

	init?(urlbox: NSTextField) { //prepareForReuse()?
		super.init(nibName: nil, bundle:nil)
		urlbox.bezelStyle = .RoundedBezel
		urlbox.drawsBackground = false
		urlbox.textColor = NSColor.controlTextColor() 
		urlbox.toolTip = ""
		//urlbox.wantsLayer = true
		//urlbox.editable = false
		//urlbox.menu = NSMenu //ctrl-click context menu

		//ti.minSize = CGSize(width: 70, height: 24)

		if let cell = urlbox.cell() as? NSTextFieldCell {
			cell.placeholderString = "Navigate to URL"
			cell.scrollable = true
			cell.action = Selector("userEnteredURL")
			//cell.target = nil // on Enter, send action up the Responder chain
			cell.target = self
			cell.sendsActionOnEndEditing = false //only send action when Return is pressed
			cell.usesSingleLineMode = true
			cell.focusRingType = .None
			//cell.representedObject
			//cell.currentEditor()?.delegate = blah
			// do live validation of input URL before Enter is pressed
			// http://stackoverflow.com/questions/3605438/validate-decimal-max-min-values-in-a-nstextfield?rq=1
		}
		view = urlbox
		//view.addSubview(progbar)
		preferredContentSize = CGSize(width: 600, height: 24)
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
			//would be cool if I could just kick up gotoURL up the responder chain?
			if let wvc = representedObject? as? WebViewController {
				view.window?.makeFirstResponder(wvc.view)
				wvc.gotoURL(url)
				//view.addSubview(progbar)
				//wait for isLoaded == true
				presentingViewController?.dismissViewController(self) //if a thoust art a popover, close thyself
			}
		} else {
			warn("\(__FUNCTION__): invalid url `\(urlstr)` was requested!")
		}
	}
	
	override func cancelOperation(sender: AnyObject?) { presentingViewController?.dismissViewController(self) } //if a thoust art a popover, close thyself
}

extension URLBoxController: NSPopoverDelegate {	
	func popoverWillShow(notification: NSNotification) {
		//view.frame = NSRect(x:0, y:0, width: 600, height: 24)
	}
}


