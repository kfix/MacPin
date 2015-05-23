import CoreGraphics
import AppKit

class WindowController: NSWindowController, NSWindowDelegate {
	required init?(coder: NSCoder) { super.init(coder: coder) } // conform to NSCoding

	override init(window: NSWindow?) {
		// take care of awakeFromNib() & windowDidLoad() tasks, which are not called for NIBless windows
		super.init(window: window)
		if let window = window {
			window.collectionBehavior = .FullScreenPrimary | .ParticipatesInCycle | .Managed | .CanJoinAllSpaces
			window.styleMask |= NSUnifiedTitleAndToolbarWindowMask
			window.movableByWindowBackground = true
			window.backgroundColor = NSColor.whiteColor()
			window.opaque = true
			window.hasShadow = true
			window.titleVisibility = .Hidden
			window.appearance = NSAppearance(named: NSAppearanceNameVibrantDark) // Aqua LightContent VibrantDark VibrantLight //FIXME add a setter?
			window.identifier = "browser"
			//window.registerForDraggedTypes([NSPasteboardTypeString, NSURLPboardType, NSFilenamesPboardType]) //wkwebviews do this themselves
			window.cascadeTopLeftFromPoint(NSMakePoint(20,20))
			window.delegate = self
			window.restorable = true
			window.restorationClass = AppDelegate.self
			window.sharingType = .ReadWrite
			NSApplication.sharedApplication().windowsMenu = NSMenu()
			NSApplication.sharedApplication().addWindowsItem(window, title: window.title!, filename: false)
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
			window.styleMask ^= NSUnifiedTitleAndToolbarWindowMask
			window.styleMask ^= NSFullSizeContentViewWindowMask // makes contentView (browserController) extend underneath the now invisible titlebar
			//window.styleMask ^= NSTitledWindowMask // this blows away the actual .toolbar object, making browserController crash
			if window.titlebarAppearsTransparent { window.toolbar?.showsBaselineSeparator = false }
		}
	}
}
