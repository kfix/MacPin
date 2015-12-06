import Foundation
import CoreLocation

class Geolocator: NSObject  {
	static let shared = Geolocator() // create & export the singleton
	let manager = CLLocationManager()
	var currentLocation: CLLocation? = nil

	var subscribers: [MPWebView] = []

	override init() {
		super.init()
		manager.delegate = self
		manager.desiredAccuracy = kCLLocationAccuracyBest
	}

	func sendLocationEvent(webview: MPWebView) {
		if !subscribers.contains(webview) { subscribers.append(webview) }
		manager.stopUpdatingLocation()
		manager.startUpdatingLocation()
	}
	//func subscribeToLocationEvents(webview: MPWebView) {}
	//func unsubscribeFromLocationEvents(webview: MPWebView) {}
}

extension Geolocator: CLLocationManagerDelegate {

	func locationManager(manager: CLLocationManager!, didFailWithError error: NSError!) {
		manager.stopUpdatingLocation()
		//if (error != nil) { warn(error) }
	}

	private func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
		if let location = locations.last as? CLLocation where locations.count > 0 {
			currentLocation = location
			warn("lat: \(location.coordinate.latitude) lon:\(location.coordinate.longitude)")

			AppScriptRuntime.shared.jsdelegate.tryFunc("updateGeolocation", location.coordinate.latitude, location.coordinate.longitude)
			for subscriber in subscribers {
				subscriber.evalJS( //for now, send an omnibus event with all varnames values
					"window.dispatchEvent(new window.CustomEvent('gotCurrentGeolocation',{detail:{latitude: \(location.coordinate.latitude), longitude: \(location.coordinate.longitude)}}));"
				)
			}

		}
    }

	func locationManager(manager: CLLocationManager!, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
		switch status {
			//case CLAuthorizationStatus.Restricted:
			//case CLAuthorizationStatus.Denied:
			//case CLAuthorizationStatus.NotDetermined:
			default:
				manager.startUpdatingLocation()
		}
	}
}
