class WindowController: NSWindowController {
	var cornerRadius = CGFloat(0.0) // increment to put nice corners on the window

	required init?(coder: NSCoder) { super.init(coder: coder) }

	override init(window: NSWindow?) {
		// since this is NIB-less, take care of awakeFromNib()s / windowDidLoad() tasks
		super.init(window: window)
		if let window = window {
			window.collectionBehavior = .FullScreenPrimary | .ParticipatesInCycle | .Managed | .CanJoinAllSpaces //.FullScreenAuxiliary | .MoveToActiveSpace 
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
			//window.restorationClass = MacPin.self //NSWindowRestoration Protocol - not a multi-window app, so not needed yet

			// lay down a blurry view underneath, only seen when transparency is toggled
			var blurView = NSVisualEffectView(frame: window.contentLayoutRect)
			blurView.blendingMode = .BehindWindow
			blurView.material = .AppearanceBased //.Dark .Light .Titlebar
			blurView.state = NSVisualEffectState.Active // set it to always be blurry regardless of window state
 			blurView.autoresizingMask = .ViewWidthSizable | .ViewHeightSizable
			blurView.wantsLayer = true
			blurView.layer?.cornerRadius = cornerRadius
			blurView.layer?.masksToBounds = true

			let cView = (window.contentView as NSView)
			cView.wantsLayer = true
			cView.layer?.cornerRadius = cornerRadius
			cView.layer?.masksToBounds = true
			//cView.autoresizesSubviews = false //ignore resizemasks
			cView.addSubview(blurView)
			//cView.addSubview(viewController.view)

			//window.delegate = self // default is windowController
			//window.registerForDraggedTypes([NSPasteboardTypeString,NSURLPboardType,NSFilenamesPboardType]) // DnD http://stackoverflow.com/a/26733085/3878712

			//window.cascadeTopLeftFromPoint(NSMakePoint(20,20))
		}
		shouldCascadeWindows = false // messes with Autosave
		windowFrameAutosaveName = "browser"
	}
}

extension MacPin: NSWindowDelegate {
	// these just handle tabless-background drags
	func draggingEntered(sender: NSDraggingInfo) -> NSDragOperation { return NSDragOperation.Every }
	func performDragOperation(sender: NSDraggingInfo) -> Bool { return true }
}

extension MacPin: NSWindowRestoration {
	class public func restoreWindowWithIdentifier(identifier: String, state: NSCoder, completionHandler: ((NSWindow!,NSError!) -> Void)) {
		warn("restoreWindowWithIdentifier: \(identifier)") // state: \(state)")
		switch identifier {
			case "browser":
				var appdel = (NSApplication.sharedApplication().delegate as MacPin)
				completionHandler(appdel.windowController.window!, nil)
			default:
				//have app remake window from scratch
				completionHandler(nil, nil) //FIXME: should ret an NSError
		}
	}
}
