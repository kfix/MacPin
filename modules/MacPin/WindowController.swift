import CoreGraphics
import Cocoa

public class WindowController: NSWindowController, NSWindowDelegate {
	required public init?(coder: NSCoder) { super.init(coder: coder) }

	public override init(window: NSWindow?) {
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

			NSApplication.sharedApplication().windowsMenu = NSMenu()
			NSApplication.sharedApplication().addWindowsItem(window, title: window.title!, filename: false)
			
			window.identifier = "browser"

			//window.registerForDraggedTypes([NSPasteboardTypeString,NSURLPboardType,NSFilenamesPboardType])
			window.cascadeTopLeftFromPoint(NSMakePoint(20,20))
			window.delegate = self
			window.restorable = true
			window.restorationClass = AppDelegate.self
		}
		shouldCascadeWindows = false // messes with Autosave
		windowFrameAutosaveName = "browser"
	}

	// these just handle drags to a tabless-background, webviews define their own
	public func draggingEntered(sender: NSDraggingInfo) -> NSDragOperation { return NSDragOperation.Every }
	public func performDragOperation(sender: NSDraggingInfo) -> Bool { return true } //should open the file:// url

	public func window(window: NSWindow, willUseFullScreenPresentationOptions proposedOptions: NSApplicationPresentationOptions) -> NSApplicationPresentationOptions {
		return NSApplicationPresentationOptions.AutoHideToolbar | NSApplicationPresentationOptions.AutoHideMenuBar | NSApplicationPresentationOptions.FullScreen | proposedOptions
	}
}
