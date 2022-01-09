import AppKit

class EffectViewController: NSViewController {
	lazy var effectView: NSVisualEffectView = {
		var view = NSVisualEffectView() // https://gist.github.com/vilhalmer/3052f7e9e7f34b92a40f
		view.blendingMode = .behindWindow
		view.material = .appearanceBased //.Dark .Light .Titlebar
		//	.fullScreenUI .contentBackground .windowBackground .underWindowBackground
		view.state = .active // set it to always be blurry regardless of window state
		view.blendingMode = .behindWindow
		view.frame = NSMakeRect(0, 0, 600, 800) // default size
		return view
 	}()

	required init?(coder: NSCoder) { super.init(coder: coder) } // conform to NSCoding
	override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) { super.init(nibName:nil, bundle:nil) } // calls loadView()
	override func loadView() { view = effectView } // NIBless
	convenience init() { self.init(nibName: nil, bundle: nil) }

	override func viewDidLoad() {
		view.autoresizesSubviews = true
		view.autoresizingMask = [.width, .height, .minXMargin, .minYMargin, .maxXMargin, .maxYMargin]
	}

	// make this view intercept all hits @ sendEvent:NSEvent so we can try to shunt right-clicks to toolbar items?
	//   https://stackoverflow.com/a/30558497/3878712
}
