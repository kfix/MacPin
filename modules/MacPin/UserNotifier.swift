import Foundation
import WebKitPrivates

class UserNotifier: NSObject  {
	//static let shared = UserNotifier() // create & export the singleton

	var notificationProvider = NotificationCallbacks.makeProvider()

	override init() {
		super.init()
		//notificationProvider.base = WKNotificationProviderBase(version: 0, clientInfo: Unmanaged.passUnretained(self).toOpaque())
	}

	func subscribe(webview: MPWebView) {
		warn()
		WKNotificationManagerSetProvider(WKContextGetNotificationManager(webview.context), &notificationProvider.base)
	}
}
