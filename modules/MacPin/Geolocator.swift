import Foundation
import CoreLocation
import WebKitPrivates

class Geolocator: NSObject  {

	lazy var geoProvider: WKGeolocationProviderV1 = {
		return WebViewGeolocationCallbacks.makeProvider(self)
	}()

	static let shared = Geolocator() // create & export the singleton
	let manager = CLLocationManager()
	var lastLocation: CLLocation? {
		get {
			return manager.location
		}
	}

	var subscribers: [MPWebView] = [] {
		didSet {
			if subscribers.isEmpty {
				manager.stopUpdatingLocation()
				warn("stopped updates")
			}
			//warn(subscribers.count.description)
		}
	}

#if os(OSX)
	override init() {
		super.init()
		manager.delegate = self
		manager.desiredAccuracy = kCLLocationAccuracyBest
	}
#endif

	func sendLocationEvent(_ webview: MPWebView) {
		if !subscribers.contains(webview) { subscribers.append(webview) }
		if CLLocationManager.locationServicesEnabled() {
			manager.stopUpdatingLocation()
			manager.startUpdatingLocation()
		}
	}

	@discardableResult
	func subscribeToLocationEvents(webview: MPWebView) -> Bool {

		if !CLLocationManager.locationServicesEnabled() { // device location is off
#if !os(OSX)
			manager.requestWhenInUseAuthorization() // runs async! Grrr....
#endif
			manager.startUpdatingLocation() // asyncly (prompts for app permission on OSX if needed) & warms up the fix
		}

		// FIXME: how to wait to ensure prompts were fired?

		//let appvds: [CLAuthorizationStatus] = [.authorizedAlways, .authorizedWhenInUse] // https://bugs.swift.org/browse/SR-4644
		//if appvds.contains(CLLocationManager.authorizationStatus()) {
		///if case .authorizedAlways = CLLocationManager.authorizationStatus() {

		if CLLocationManager.locationServicesEnabled() {
			WebViewGeolocationCallbacks.subscribe(&geoProvider, webview: webview)
			return true
		}

		return false
	}

	func unsubscribeFromLocationEvents(webview: MPWebView) {
		warn()
		//subscribers.removeAll(where: {$0 == webview}) } // xc10
		subscribers = subscribers.flatMap({$0 != webview ? $0 : nil})
	}

	deinit {
		warn(subscribers.count.description)
	}
}

extension Geolocator: CLLocationManagerDelegate {

	func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
		manager.stopUpdatingLocation()
		//if (error != nil) { warn(error) }
	}

	func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		if let location = locations.last, locations.count > 0 {
			warn("lat: \(location.coordinate.latitude) lon:\(location.coordinate.longitude)")
		}
    }

	func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
		switch status {
			//case CLAuthorizationStatus.Restricted:
			//case CLAuthorizationStatus.Denied:
			//case CLAuthorizationStatus.NotDetermined:
			default:
				warn()
		}
	}
}
