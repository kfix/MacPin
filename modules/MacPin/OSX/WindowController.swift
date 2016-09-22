import CoreGraphics
import AppKit

class WindowController: NSWindowController, NSWindowDelegate {
	required init?(coder: NSCoder) { super.init(coder: coder) } // conform to NSCoding

	override init(window: NSWindow?) {
		// take care of awakeFromNib() & windowDidLoad() tasks, which are not called for NIBless windows
		super.init(window: window)

		let appearance = NSUserDefaults.standardUserDefaults().stringForKey("AppleInterfaceStyle") ?? "Light"
		if let window = window {
			window.collectionBehavior = [.FullScreenPrimary, .ParticipatesInCycle, .Managed]
			window.styleMask.insert(.UnifiedTitleAndToolbar) // FIXME: toggle for borderless?
			window.movableByWindowBackground = true
			window.backgroundColor = NSColor.whiteColor()
			window.opaque = true
			window.hasShadow = true
			window.titleVisibility = .Hidden
			if appearance == "Dark" {
				window.appearance = NSAppearance(named: NSAppearanceNameVibrantDark) // match overall system dark-mode
			} else {
				window.appearance = NSAppearance(named: NSAppearanceNameVibrantLight) // Aqua LightContent VibrantDark VibrantLight
			} // NSVisualEffectMaterialAppearanceBased ??
			window.identifier = "browser"
			//window.registerForDraggedTypes([NSPasteboardTypeString, NSURLPboardType, NSFilenamesPboardType]) //wkwebviews do this themselves
			window.cascadeTopLeftFromPoint(NSMakePoint(20,20))
			window.delegate = self
			window.restorable = true
			window.restorationClass = MacPinAppDelegateOSX.self
			window.sharingType = .ReadWrite
			NSApplication.sharedApplication().windowsMenu = NSMenu()
			NSApplication.sharedApplication().addWindowsItem(window, title: window.title, filename: false)
		}
		shouldCascadeWindows = false // messes with Autosave
		windowFrameAutosaveName = "browser"
	}

	// these just handle drags to a tabless-background, webviews define their own
	func draggingEntered(sender: NSDraggingInfo) -> NSDragOperation { return NSDragOperation.Every }
	func performDragOperation(sender: NSDraggingInfo) -> Bool { return true } //should open the file:// url

	func window(window: NSWindow, willUseFullScreenPresentationOptions proposedOptions: NSApplicationPresentationOptions) -> NSApplicationPresentationOptions {
		return [.AutoHideToolbar, .AutoHideMenuBar, .FullScreen, proposedOptions]
	}

	//class func restorableStateKeyPaths() -> [String] { return [] }
	//override func encodeRestorableStateWithCoder(coder: NSCoder) { super(coder) }
	//override func restoreStateWithCoder(coder: NSCoder) { super(coder) }
	//func window(window: NSWindow, willEncodeRestorableState state: NSCoder) {}
	//func window(window: NSWindow, didDecodeRestorableState state: NSCoder) {}

	func toggleTitlebar() {
		if let window = window,
			close = window.standardWindowButton(.CloseButton),
			min = window.standardWindowButton(.MiniaturizeButton),
			zoom = window.standardWindowButton(.ZoomButton),
			toolbar = window.toolbar
		{
			//window.toggleToolbarShown(nil)
 			toolbar.visible = window.titlebarAppearsTransparent
			close.hidden = !close.hidden
			min.hidden = !min.hidden
			zoom.hidden = !zoom.hidden
			window.titlebarAppearsTransparent = !window.titlebarAppearsTransparent
			//window.styleMask.formSymmetricDifference(.UnifiedTitleAndToolbar) // XOR ^= in Swift3?
			//window.styleMask.formSymmetricDifference(.FullSizeContentView)
			window.styleMask = NSWindowStyleMask(rawValue: window.styleMask.rawValue
				^ NSWindowStyleMask.UnifiedTitleAndToolbar.rawValue
				^ NSWindowStyleMask.FullSizeContentView.rawValue // makes contentView (browserController) extend underneath the now invisible titlebar
			)
			//window.styleMask ^= .Titled // this blows away the actual .toolbar object, making browserController crash
			if window.titlebarAppearsTransparent { window.toolbar?.showsBaselineSeparator = false }
		}
	}

	// only useful in non-fullscreen mode
	//func toggleMenuBarAutoHide() { NSApp.presentationOptions |= .AutoHideMenuBar }
}
