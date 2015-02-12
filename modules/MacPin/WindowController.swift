import CoreGraphics

class WindowController: NSWindowController, NSWindowDelegate {
	var cornerRadius = CGFloat(0.0) // increment to put nice corners on the window FIXME userDefaults

	required init?(coder: NSCoder) { super.init(coder: coder) }

	override init(window: NSWindow?) {
		// take care of awakeFromNib() & windowDidLoad() tasks, which are not called for NIBless windows
		super.init(window: window)
		if let window = window {
			window.collectionBehavior = .FullScreenPrimary | .ParticipatesInCycle | .Managed | .CanJoinAllSpaces | .FullScreenAuxiliary //| .MoveToActiveSpace 
			window.movableByWindowBackground = true
			window.backgroundColor = NSColor.whiteColor()
			window.opaque = true
			window.hasShadow = true
			window.titleVisibility = .Hidden
			window.appearance = NSAppearance(named: NSAppearanceNameVibrantDark) // Aqua LightContent VibrantDark VibrantLight //FIXME add a setter?

			window.toolbar = NSToolbar(identifier: "toolbar") //placeholder, will be re-init'd by NSTabViewController

			window.title = NSProcessInfo.processInfo().processName
			NSApplication.sharedApplication().windowsMenu = NSMenu()
			NSApplication.sharedApplication().addWindowsItem(window, title: window.title!, filename: false)
			
			window.identifier = "browser"

			let cView = (window.contentView as NSView)
			cView.wantsLayer = true
			cView.layer?.cornerRadius = cornerRadius
			cView.layer?.masksToBounds = true

			// lay down a blurry view underneath, only seen when transparency is toggled
			var blurView = NSVisualEffectView(frame: window.contentLayoutRect)
			blurView.blendingMode = .BehindWindow
			blurView.material = .AppearanceBased //.Dark .Light .Titlebar
			blurView.state = NSVisualEffectState.Active // set it to always be blurry regardless of window state
 			blurView.autoresizingMask = .ViewWidthSizable | .ViewHeightSizable
			blurView.wantsLayer = true
			blurView.layer?.cornerRadius = cornerRadius
			blurView.layer?.masksToBounds = true
			cView.addSubview(blurView)
			
			window.registerForDraggedTypes([NSPasteboardTypeString,NSURLPboardType,NSFilenamesPboardType])
			window.cascadeTopLeftFromPoint(NSMakePoint(20,20))
			window.delegate = self
		}
		shouldCascadeWindows = false // messes with Autosave
		windowFrameAutosaveName = "browser"
	}

	// these just handle drags to a tabless-background, webviews define their own
	func draggingEntered(sender: NSDraggingInfo) -> NSDragOperation { return NSDragOperation.Every }
	func performDragOperation(sender: NSDraggingInfo) -> Bool { return true } //should open the file:// url

	func window(window: NSWindow, willUseFullScreenPresentationOptions proposedOptions: NSApplicationPresentationOptions) -> NSApplicationPresentationOptions {
		return NSApplicationPresentationOptions.AutoHideToolbar | NSApplicationPresentationOptions.AutoHideMenuBar | NSApplicationPresentationOptions.FullScreen | proposedOptions
	}
}
