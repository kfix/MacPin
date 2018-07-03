import JavaScriptCore

@objc protocol ApplicationDelegateJS: JSExport {
	var browserController: BrowserViewController { get set }
}

protocol MacPinAppDelegate: ApplicationDelegate, ApplicationDelegateJS {
	var window: Window? { get }
}
