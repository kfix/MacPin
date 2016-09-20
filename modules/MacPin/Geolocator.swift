import Foundation
import CoreLocation
// generates Geolocation updates as JavaScript events in response to shimmed window.geolocation's postMessages

// WebKit2 has built-geolocation on iOS:
// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/ios/WKGeolocationProviderIOS.mm
// https://github.com/WebKit/webkit/blob/master/Source/WebKit/ios/Misc/WebGeolocationCoreLocationProvider.mm
// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/Cocoa/WKProcessGroupPrivate.h
// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/Cocoa/WKProcessPoolInternal.h
// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/Cocoa/WKUIDelegatePrivate.h
// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/WebProcess/WebCoreSupport/WebGeolocationClient.cpp
// https://github.com/WebKit/webkit/blob/ce24e8d887968296a2acebd96c31797d36fb08ca/Tools/TestWebKitAPI/Tests/WebKit2/Geolocation.cpp#L104
// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/C/WKGeolocationPermissionRequest.h

class Geolocator: NSObject  {
	static let shared = Geolocator() // create & export the singleton
	let manager = CLLocationManager()
	var currentLocation: CLLocation? = nil

	var subscribers: [MPWebView] = []

#if os(OSX)
	override init() {
		super.init()
		manager.delegate = self
		manager.desiredAccuracy = kCLLocationAccuracyBest
	}
#endif

	func sendLocationEvent(webview: MPWebView) {
		if !subscribers.contains(webview) { subscribers.append(webview) }
		manager.stopUpdatingLocation()
		manager.startUpdatingLocation()
	}
	//func subscribeToLocationEvents(webview: MPWebView) {}
	//func unsubscribeFromLocationEvents(webview: MPWebView) {}
}

extension Geolocator: CLLocationManagerDelegate {

	func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
		manager.stopUpdatingLocation()
		//if (error != nil) { warn(error) }
	}

//iOS9:
//	func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
//		if let location = locations.last {

#if os(OSX)
	func locationManager(manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		if let location = locations.last where locations.count > 0 {
			currentLocation = location
			warn("lat: \(location.coordinate.latitude) lon:\(location.coordinate.longitude)")

			// https://github.com/WebKit/webkit/blob/8c504b60d07b2a5c5f7c32b51730d3f6f6daa540/Tools/WebKitTestRunner/InjectedBundle/InjectedBundle.cpp#L457
			AppScriptRuntime.shared.jsdelegate.tryFunc("updateGeolocation", location.coordinate.latitude, location.coordinate.longitude)
			for subscriber in subscribers {
				subscriber.evalJS( //for now, send an omnibus event with all varnames values
					"window.dispatchEvent(new window.CustomEvent('gotCurrentGeolocation',{detail:{latitude: \(location.coordinate.latitude), longitude: \(location.coordinate.longitude)}}));"
				)
			}

		}
    }
#endif

	func locationManager(manager: CLLocationManager, didChangeAuthorizationStatus status: CLAuthorizationStatus) {
		switch status {
			//case CLAuthorizationStatus.Restricted:
			//case CLAuthorizationStatus.Denied:
			//case CLAuthorizationStatus.NotDetermined:
			default:
				manager.startUpdatingLocation()
		}
	}
}
