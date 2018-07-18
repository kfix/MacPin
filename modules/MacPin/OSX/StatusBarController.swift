/// MacPin StatusBarController
///
/// Controls a textfield that displays a WebViewController's current hovered URL

import AppKit
import WebKitPrivates

@objc class StatusBarController: NSViewController {
	let statusbox = NSTextField()

	@objc weak var hovered: _WKHitTestResult? = nil {
		didSet {
			if let hovered = hovered {
				statusbox.stringValue = hovered.absoluteLinkURL.absoluteString
				//TODO: scale frame.width to fit URL length, like safari does
				// Safari also seems to use SegmentedText to bold the scheme+host (origin)
				statusbox.isHidden = statusbox.stringValue.isEmpty
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
	}

	deinit { hovered = nil }
}
