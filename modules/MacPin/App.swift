import Foundation

@objc(MacPinApp)
class MacPinApp: Application {
	override static func sharedApplication() -> MacPinApp {
		let app = super.sharedApplication()
		return app as! MacPinApp
	}

	var appDelegate: MacPinAppDelegate? {
		get {
			return super.delegate as? MacPinAppDelegate
		}
		set {
			super.delegate = newValue as? ApplicationDelegate
		}
	}
}
