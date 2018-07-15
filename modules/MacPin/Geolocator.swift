import Foundation
import CoreLocation
import WebKit
import WebKitPrivates

struct GeolocationCallbacks {
	// thunks for WebKit geolocation C APIs
	static let setEnableHighAccuracyCallback: WKGeolocationProviderSetEnableHighAccuracyCallback = { manager, enable, clientInfo in
		let geolocator = unsafeBitCast(clientInfo, to: Geolocator.self)
		// https://github.com/WebKit/webkit/blob/2d04a55b4031d09c912c4673d3e753357b383071/Tools/TestWebKitAPI/Tests/WebKit/Geolocation.cpp#L68
		if enable {
			geolocator.manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
		}
	}

	static let startUpdatingCallback: WKGeolocationProviderStartUpdatingCallback = { manager, clientInfo in
		let geolocator = unsafeBitCast(clientInfo, to: Geolocator.self)
		geolocator.manager.startUpdatingLocation()

		if let location = geolocator.lastLocation {
			warn(location.description)

			// https://github.com/WebKit/webkit/blob/master/Source/WebCore/Modules/geolocation/ios/GeolocationPositionIOS.mm
			WKGeolocationManagerProviderDidChangePosition(manager,
				WKGeolocationPositionCreate(location.timestamp.timeIntervalSince1970, location.coordinate.latitude, location.coordinate.longitude, location.horizontalAccuracy)
			)
		}
	}

	static let stopUpdatingCallback: WKGeolocationProviderStopUpdatingCallback = { manager, clientInfo in
		let geolocator = unsafeBitCast(clientInfo, to: Geolocator.self)
		//geolocator.manager.stopUpdatingLocation()
		// FIXME: should unsubscribe the calling webview so Geol'r can choose to stop if no subscribers remain
	}
}

class Geolocator: NSObject  {

	var geoProvider = WKGeolocationProviderV1(
		base: WKGeolocationProviderBase(),
		startUpdating: GeolocationCallbacks.startUpdatingCallback,
		stopUpdating: GeolocationCallbacks.stopUpdatingCallback,
		setEnableHighAccuracy: GeolocationCallbacks.setEnableHighAccuracyCallback
	)

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
		geoProvider.base.clientInfo = UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque()) // +0
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

	func subscribeToLocationEvents(webview: MPWebView) {

		if !CLLocationManager.locationServicesEnabled() {
#if !os(OSX)
			Geolocator.shared.manager.requestWhenInUseAuthorization()
#endif
		}

		// https://github.com/WebKit/webkit/blob/827d99acfeb79537ec9ce26f4bb5a438ba2f5463/Tools/TestWebKitAPI/Tests/WebKitCocoa/UIDelegate.mm#L144
		WKGeolocationManagerSetProvider(WKContextGetGeolocationManager(webview.context), &geoProvider.base)
		// skipping this did not fix post-nav retain cycle
		manager.startUpdatingLocation()
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
