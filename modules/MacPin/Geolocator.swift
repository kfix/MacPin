import Foundation
import CoreLocation

class Geolocator: NSObject  {
	static let shared = Geolocator() // create & export the singleton
	let manager = CLLocationManager()
	var currentLocation: CLLocation? = nil

	override init() {
		super.init()
		manager.delegate = self
	}

	//func sendLocationEvent(webview: MPWebView) {}
	//func subscribeToLocationEvents(webview: MPWebView) {}
	//func unsubscribeFromLocationEvents(webview: MPWebView) {}
	
}

extension Geolocator: CLLocationManagerDelegate {
}
