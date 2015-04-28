import AppKit

class EffectViewController: NSViewController {
	lazy var effectView: NSVisualEffectView = { 
		var view = NSVisualEffectView()
		view.blendingMode = .BehindWindow
		view.material = .AppearanceBased //.Dark .Light .Titlebar
		view.state = NSVisualEffectState.Active // set it to always be blurry regardless of window state
		view.blendingMode = .BehindWindow
		view.frame = NSMakeRect(0, 0, 600, 800) // default size
		return view
 	}()

	required init?(coder: NSCoder) { super.init(coder: coder) } // conform to NSCoding
	override init!(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) { super.init(nibName:nil, bundle:nil) } // calls loadView() 
	override func loadView() { view = effectView } // NIBless
	convenience init() { self.init(nibName: nil, bundle: nil) }
	
	override func viewDidLoad() {
		view.autoresizesSubviews = true
		view.autoresizingMask = .ViewWidthSizable | .ViewHeightSizable //shouldn't matter if this is the contentView
		//view.translatesAutoresizingMaskIntoConstraints = true
	}
}
