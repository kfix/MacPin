import Foundation
import CoreLocation
import WebKitPrivates

struct WebKitGeolocationCallbacks {
	// thunks for WebKit geolocation C APIs
	static let setEnableHighAccuracyCallback: WKGeolocationProviderSetEnableHighAccuracyCallback = { manager, enable, clientInfo in

		weak var geolocator = unsafeBitCast(clientInfo, to: Geolocator.self)
		// https://github.com/WebKit/webkit/blob/2d04a55b4031d09c912c4673d3e753357b383071/Tools/TestWebKitAPI/Tests/WebKit/Geolocation.cpp#L68
		if enable && geolocator != nil {
			warn(enable.description, function: "setHighAccuracy")
			geolocator!.manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
		}
	}

	static let startUpdatingCallback: WKGeolocationProviderStartUpdatingCallback = { manager, clientInfo in
		weak var geolocator = unsafeBitCast(clientInfo, to: Geolocator.self)
		guard geolocator != nil else { warn("no Geolocator provided to callback!"); return }

		warn()
		geolocator?.active = true
	}

	static let stopUpdatingCallback: WKGeolocationProviderStopUpdatingCallback = { manager, clientInfo in
		weak var geolocator = unsafeBitCast(clientInfo, to: Geolocator.self)
		guard geolocator != nil else { warn("no Geolocator provided to callback!"); return }

		warn()
		geolocator?.active = false
	}

	static func makeProvider(_ client: Geolocator) -> WKGeolocationProviderV1 { return WKGeolocationProviderV1(
		base: WKGeolocationProviderBase(version: 1, clientInfo: Unmanaged.passUnretained(client).toOpaque()), // +0
		startUpdating: nil, /*startUpdatingCallback,*/
		stopUpdating: nil, /*stopUpdatingCallback,*/
		setEnableHighAccuracy: setEnableHighAccuracyCallback

	)}

	static func getManager(_ client: MPWebView) -> WKGeolocationManagerRef? {
		if let context = client.context {
			return WKContextGetGeolocationManager(context)
		}
		return nil
	}

	// https://github.com/WebKit/webkit/blob/827d99acfeb79537ec9ce26f4bb5a438ba2f5463/Tools/TestWebKitAPI/Tests/WebKitCocoa/UIDelegate.mm#L144
	static func subscribe(_ provider: inout WKGeolocationProviderV1, webview: MPWebView) {
		if let manager = getManager(webview) {
			WKGeolocationManagerSetProvider(manager, &provider.base)
			warn("subscribed to Geolocator updates: \(webview)")
		}
	}
}

class Geolocator: NSObject  {

	lazy var geoProvider: WKGeolocationProviderV1 = {
		return WebKitGeolocationCallbacks.makeProvider(self)
	}()

	static let shared = Geolocator() // create & export the singleton
	let manager = CLLocationManager()
	var lastLocation: CLLocation? {
		get {
			return manager.location
		}
	}
	var active = false

	var subscribers: [MPWebView] = [] {
		didSet {
			if subscribers.isEmpty {
				manager.stopUpdatingLocation()
				active = false
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

	func subscribeToLocationEvents(webview: MPWebView) {
		warn()

		WebKitGeolocationCallbacks.subscribe(&geoProvider, webview: webview)
        subscribers.append(webview)

		let authstatus = CLLocationManager.authorizationStatus()

		//if !CLLocationManager.locationServicesEnabled() { // device location is off
		if authstatus == .notDetermined || !active {
#if !os(OSX)
			manager.requestWhenInUseAuthorization() // runs async! Grrr....
#endif
			manager.startUpdatingLocation() // asyncly (prompts for app permission on OSX if needed) & warms up the fix
			// CLLoactionManagerDelegates will then be called-back to propagate the updates
		}
	}

	func sendLocationToAllSubscribers(_ location: CLLocation?) {
		for webview in subscribers {
			if let manager = WebKitGeolocationCallbacks.getManager(webview) {
				if let location = location {
					WKGeolocationManagerProviderDidChangePosition(manager,
						WKGeolocationPositionCreate(location.timestamp.timeIntervalSince1970, location.coordinate.latitude, location.coordinate.longitude, location.horizontalAccuracy)
					)
				} else {
					"no position available".withCString { reason in
						WKGeolocationManagerProviderDidFailToDeterminePositionWithErrorMessage(manager, WKStringCreateWithUTF8CString(reason));
					}
				}
			}
		}
	}

	func unsubscribeFromLocationEvents(webview: MPWebView) {
		warn()
		subscribers.removeAll(where: {$0 == webview})
	}

	deinit {
		warn(subscribers.count.description)
	}
}

extension Geolocator: CLLocationManagerDelegate {

	func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
		warn(error)
		guard let error = CLError.Code(rawValue: error._code) else { return; }

		if error == .denied {
			// request was denied
			warn("denied fix")
			manager.stopUpdatingLocation()
			active = false

			// we have no datapoint, so send a blank to make an error for JS
			sendLocationToAllSubscribers(nil)
		}
	}

	func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
		guard let location = locations.last, locations.count > 0 else {
			warn("no locations in update!")
			return
		}

		warn("lat: \(location.coordinate.latitude) lon:\(location.coordinate.longitude)")

		sendLocationToAllSubscribers(location)
    }

	func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
		warn("CLAuthStatus: \(status.rawValue)")

		switch status {
			case .notDetermined:
				fallthrough //???
			case .restricted:
				fallthrough
			case .denied:
				manager.stopUpdatingLocation()
				active = false
			default:
				manager.startUpdatingLocation()
				active = true
		}
	}

#if os(iOS)
	func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
		active = false
	}

	func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
		active = true
	}
#endif
}
