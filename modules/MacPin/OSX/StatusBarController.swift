/// MacPin StatusBarController
///
/// Controls a textfield that displays a WebViewController's current hovered URL

import AppKit
import WebKitPrivates

@objc class StatusBarField: NSTextField { // FIXMEios UILabel + UITextField
	// override func minSizeForContent -> NSSize {} // https://brockerhoff.net/blog/2006/10/02/autoresizing-nstextfields/
	// FIXME adjust width to fit stringValue

	// http://devetc.org/code/2014/07/07/auto-layout-and-views-that-wrap.html
	//var preferredMaxLayoutWidth: CGFloat { get set }

	// https://www.objc.io/issues/3-views/advanced-auto-layout-toolbox/
	// var fittingSize: NSSize { get }
	//var intrinsicContentSize: NSSize { get }

	override var stringValue: String {
		didSet {
			//TODO: scale intrisicContentSize.width to fit URL length, like safari does
			invalidateIntrinsicContentSize()
			isHidden = stringValue.isEmpty
		}
	}
}

//let wkhtr = NSClassFromString("_WKHitTestResult")
// _WKHTR not avail in wk605.1.33 | osx10.11 | sf11.0
// try running a build without rpath to see if it crashes..

@objc class StatusBarController: NSViewController {
	let statusbox = StatusBarField()


	@objc weak var hovered: _WKHitTestResult? = nil {
		didSet {
			if let hovered = hovered {
				statusbox.stringValue = hovered.absoluteLinkURL.absoluteString
				// Safari also seems to use SegmentedText to bold the scheme+host (origin)
			} else {
				statusbox.isHidden = true
			}
		}
	}

	required init?(coder: NSCoder) { super.init(coder: coder) }
	override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) { super.init(nibName:nil, bundle:nil) } // calls loadView()
	override func loadView() { view = statusbox } // NIBless

	convenience init() {
		self.init(nibName:nil, bundle:nil)
	}

	override func viewDidLoad() {
		super.viewDidLoad()

		view.autoresizingMask = [.width]

		let appearance = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") ?? "Light"
		if appearance == "Dark" {
			//statusbox.drawsBackground = false
			statusbox.textColor = NSColor.labelColor
		}
		statusbox.wantsLayer = true
		statusbox.bezelStyle = .roundedBezel
		statusbox.toolTip = ""

		if let cell = statusbox.cell as? NSTextFieldCell {
			cell.placeholderString = ""
			cell.isScrollable = false
			cell.target = self
			cell.usesSingleLineMode = true
			cell.focusRingType = .none
			cell.isEditable = false
			cell.isSelectable = false
		}

		statusbox.isHidden = true
		statusbox.maximumNumberOfLines = 1
	}

	deinit { hovered = nil }
}
