import CoreGraphics
import AppKit

class WindowController: NSWindowController, NSWindowDelegate {
	required init?(coder: NSCoder) { super.init(coder: coder) } // conform to NSCoding

	override init(window: NSWindow?) {
		// take care of awakeFromNib() & windowDidLoad() tasks, which are not called for NIBless windows
		super.init(window: window)

		let appearance = UserDefaults.standard.string(forKey: "AppleInterfaceStyle") ?? "Light"
		if let window = window {
			window.collectionBehavior = [.fullScreenPrimary, .participatesInCycle, .managed]
			window.styleMask.insert(.unifiedTitleAndToolbar) // FIXME: toggle for borderless?
			window.isMovableByWindowBackground = true
			window.backgroundColor = NSColor.white
			window.isOpaque = true
			window.hasShadow = true
			//window.ignoresMouseEvents = false
			//window.acceptsMouseMovedEvents = false
			window.titleVisibility = .hidden
			if appearance == "Dark" {
				window.appearance = NSAppearance(named: NSAppearance.Name.vibrantDark) // match overall system dark-mode
			} else {
				window.appearance = NSAppearance(named: NSAppearance.Name.vibrantLight) // Aqua LightContent VibrantDark VibrantLight
			} // NSVisualEffectMaterialAppearanceBased ??
			window.identifier = NSUserInterfaceItemIdentifier("browser")
			//window.registerForDraggedTypes([NSPasteboardTypeString, NSURLPboardType, NSFilenamesPboardType]) //wkwebviews do this themselves
			window.cascadeTopLeft(from: NSMakePoint(20,20))
			window.delegate = self
			window.isRestorable = true
			//window.isReleasedWhenClosed = true
			window.restorationClass = MacPinAppDelegateOSX.self
			window.sharingType = .readWrite
			NSApplication.shared.windowsMenu = NSMenu()
			NSApplication.shared.addWindowsItem(window, title: window.title, filename: false)
		}
		shouldCascadeWindows = false // messes with Autosave
		windowFrameAutosaveName = NSWindow.FrameAutosaveName("browser")
	}

	// these just handle drags to a tabless-background, webviews define their own
	func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { return NSDragOperation.every }
	func performDragOperation(_ sender: NSDraggingInfo) -> Bool { return true } // FIXME: should open the file:// url

	func window(_ window: NSWindow, willUseFullScreenPresentationOptions proposedOptions: NSApplication.PresentationOptions) -> NSApplication.PresentationOptions {
		return [.autoHideToolbar, .autoHideMenuBar, .fullScreen, proposedOptions]
	}

	//class func restorableStateKeyPaths() -> [String] { return [] }
	//override func encodeRestorableStateWithCoder(coder: NSCoder) { super(coder) }
	//override func restoreStateWithCoder(coder: NSCoder) { super(coder) }
	//func window(window: NSWindow, willEncodeRestorableState state: NSCoder) {}
	//func window(window: NSWindow, didDecodeRestorableState state: NSCoder) {}

	@objc func toggleTitlebar() {
		if let window = window,
			let close = window.standardWindowButton(.closeButton),
			let min = window.standardWindowButton(.miniaturizeButton),
			let zoom = window.standardWindowButton(.zoomButton),
			let toolbar = window.toolbar
		{
			//window.toggleToolbarShown(nil)
 			toolbar.isVisible = window.titlebarAppearsTransparent
			close.isHidden = !close.isHidden
			min.isHidden = !min.isHidden
			zoom.isHidden = !zoom.isHidden
			window.titlebarAppearsTransparent = !window.titlebarAppearsTransparent
			//window.styleMask.formSymmetricDifference(.UnifiedTitleAndToolbar) // XOR ^= in Swift3?
			//window.styleMask.formSymmetricDifference(.FullSizeContentView)
			window.styleMask = NSWindow.StyleMask(rawValue: window.styleMask.rawValue
				^ NSWindow.StyleMask.unifiedTitleAndToolbar.rawValue
				^ NSWindow.StyleMask.fullSizeContentView.rawValue // makes contentView (browserController) extend underneath the now invisible titlebar
			)
			//window.styleMask ^= .Titled // this blows away the actual .toolbar object, making browserController crash
			if window.titlebarAppearsTransparent { window.toolbar?.showsBaselineSeparator = false }
		}
	}

	// only useful in non-fullscreen mode
	//func toggleMenuBarAutoHide() { NSApp.presentationOptions |= .AutoHideMenuBar }

	override func windowTitle(forDocumentDisplayName displayName: String) -> String { warn(displayName); return window?.title ?? displayName }

	//func windowDidBecomeKey(_ notification: Notification) { warn(obj: notification); }

	func windowShouldClose(_ sender: NSWindow) -> Bool {
		warn()
		return true
	}
	func windowWillClose(_ notification: Notification) {
		warn()
		//warn(obj: self)
	} // window was closed by red stoplight button

	override func noResponder(for eventSelector: Selector) { warn(obj: eventSelector); }

	deinit { warn(description) }

	// TODO: implement rate-limiting of alert-sheets to flummox JS malwares
	// TODO: allow sheets to be dismissed by switching focus or tabs
	// func windowWillBeginSheet(_ notification: Notification)
	// func windowDidEndSheet(_ notification: Notification)
	// notification.object is the displaying window (the sheet itself is another derived-window)
}
