import Foundation

@objc(MacPinApp)
class MacPinApp: Application {
	/*
	override static func shared() -> MacPinApp {
		let app = super.shared()
		return app as! MacPinApp
	}
	*/
	@objc override static var shared: MacPinApp {
		get {
			return super.shared as! MacPinApp
		}
	}

	var appDelegate: MacPinAppDelegate? {
		get {
			return super.delegate as? MacPinAppDelegate
		}
		set {
			super.delegate = newValue as ApplicationDelegate?
		}
	}
}
