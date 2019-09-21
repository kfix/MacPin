/// MacPin StatusBarController
///
/// Controls a textfield that displays a WebViewController's current hovered URL

import AppKit
import WebKitPrivates

@objc class StatusBarField: NSTextField { // FIXMEios UILabel + UITextField
	override var stringValue: String {
		didSet {
			invalidateIntrinsicContentSize()
			sizeToFit() // shrink field to match text, like Safari
			isHidden = stringValue.isEmpty
		}
	}
}

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

	@objc override func viewDidLoad() {
		super.viewDidLoad()

		view.autoresizingMask = [.width]

		statusbox.backgroundColor = NSColor.textBackgroundColor
		statusbox.textColor = NSColor.labelColor
		statusbox.toolTip = ""

		if let cell = statusbox.cell as? NSTextFieldCell {
			cell.placeholderString = ""
			cell.isScrollable = false
			cell.target = self
			cell.usesSingleLineMode = true
			cell.focusRingType = .none
			cell.isEditable = false
			cell.isSelectable = false
			cell.backgroundStyle = .lowered
		}

		statusbox.isHidden = true
		statusbox.maximumNumberOfLines = 1

		statusbox.isBezeled = false
		// "In order to prevent inconsistent rendering, background color rendering is disabled for rounded-bezel text fields."
		///   seems that any .bezelStyle disables background color...
		statusbox.isBordered = true // in case we have more issues with text colors, at least the box will be apparent
		statusbox.drawsBackground = true
	}

	deinit { hovered = nil }
}
