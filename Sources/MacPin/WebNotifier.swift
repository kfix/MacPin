import WebKitPrivates
import CoreFoundation
import Foundation

struct WebKitNotificationCallbacks {

	// Requests that a notification be shown.
	// https://www.w3.org/TR/notifications/#showing-a-notification
	static let showCallback: WKNotificationProviderShowCallback = { page, notification, clientInfo in
		unsafeBitCast(clientInfo, to: WebNotifier.self).showWebNotification(page!, notification!)
	}

	// Requests that a notification that has already been shown be canceled.
	static let cancelCallback: WKNotificationProviderCancelCallback = { notification, clientInfo in
		warn("cancelled")
	}

	// Informs the presenter that a Notification object has been destroyed
	// (such as by a page transition). The presenter may continue showing
	// the notification, but must not attempt to call the event handlers.
	static let destroyCallback: WKNotificationProviderDidDestroyNotificationCallback = { notification, clientInfo in
		warn("destroyed")
	}

	static let removeCallback: WKNotificationProviderRemoveNotificationManagerCallback = { manager, clientInfo in
		warn("removed")
	}

	static let addCallback: WKNotificationProviderAddNotificationManagerCallback = { manager, clientInfo in
		warn("added") // happens when notificationPermission requests is authorized
	}

	static let permissionsCallback: WKNotificationProviderNotificationPermissionsCallback = { clientInfo -> Optional<WKDictionaryRef> in
		return OpaquePointer(WKRetain(UnsafeRawPointer(
			// must WKRetain to incr WK's refcount, balancing the release it does after this callback
			unsafeBitCast(clientInfo, to: WebNotifier.self).notificationPermissions
		))!)
	}

	// Cancel all outstanding requests
	static let clearCallback: WKNotificationProviderClearNotificationsCallback = { notificationIDs, clientInfo in
		warn("cleared")
	}

	static func makeProvider(_ webNotifier: WebNotifier) -> WKNotificationProviderV0 { return WKNotificationProviderV0(
		base: WKNotificationProviderBase(version: 0, clientInfo: Unmanaged.passUnretained(webNotifier).toOpaque()), // +0
		show: showCallback,
		cancel: cancelCallback,
		didDestroyNotification: destroyCallback,
		addNotificationManager: addCallback,
		removeNotificationManager: removeCallback,
		notificationPermissions: permissionsCallback,
		clearNotifications: clearCallback
	)}
}

class WebNotifier {
	// https://github.com/WebKit/webkit/blob/master/Tools/WebKitTestRunner/WebNotificationProvider.cpp
	// https://github.com/WebKit/webkit/blob/master/Tools/WebKitTestRunner/WebNotificationProvider.h

	weak var webview: MPWebView?
	let manager: WKNotificationManagerRef
	let notificationPermissions: WKMutableDictionaryRef
	// have to cache perms for individual webviews, as multiple sites could request permissions at the same time as browser/app-scripts trying to modify them

	required init(_ webview: MPWebView) {
		self.webview = webview
		self.notificationPermissions = WKMutableDictionaryCreate()
		self.manager = WKContextGetNotificationManager(webview.context!)
		var wk_provider = WebKitNotificationCallbacks.makeProvider(self)
		WKNotificationManagerSetProvider(self.manager, &wk_provider.base)
	}

	func unmanage() {
		warn("removing from Notification updates")
		WKNotificationManagerSetProvider(manager, nil)
	}

	deinit {
		warn("deinit")
		WKNotificationManagerSetProvider(manager, nil)
		WKRelease(UnsafeRawPointer(notificationPermissions))
	}

	func showWebNotification(_ page: WKPageRef, _ notification: WKNotificationRef) {
		let context = WKPageGetContext(page)
		let notificationManager = WKContextGetNotificationManager(context)

		// https://www.w3.org/TR/notifications/#model
		let title = WKStringCopyCFString(CFAllocatorGetDefault().takeUnretainedValue(),
			WKNotificationCopyTitle(notification)) as String

		let body = WKStringCopyCFString(CFAllocatorGetDefault().takeUnretainedValue(),
			WKNotificationCopyBody(notification)) as String

		let iconurl = WKStringCopyCFString(CFAllocatorGetDefault().takeUnretainedValue(),
			WKNotificationCopyIconURL(notification)) as String

		let tag = WKStringCopyCFString(CFAllocatorGetDefault().takeUnretainedValue(),
			WKNotificationCopyTag(notification)) as String

		let lang = WKStringCopyCFString(CFAllocatorGetDefault().takeUnretainedValue(),
			WKNotificationCopyLang(notification)) as String

		let dir = WKStringCopyCFString(CFAllocatorGetDefault().takeUnretainedValue(),
			WKNotificationCopyDir(notification)) as String

		let origin = WKStringCopyCFString(CFAllocatorGetDefault().takeUnretainedValue(),
			WKSecurityOriginCopyToString(WKNotificationGetSecurityOrigin(notification))) as String

		let type = Int(WKNotificationGetTypeID())

		let idnum = WKNotificationGetID(notification)

		warn("\(title) - \(body) - \(iconurl) - \(origin)", function: "showCallback")

		if let webview = webview {
			webview.showDesktopNotification(title: title, tag: tag, body: body, iconurl: iconurl, id: Int(idnum), type: type, origin: origin, lang: lang, dir: dir)
		}

		// let the webview know we sent it
		WKNotificationManagerProviderDidShowNotification(WKContextGetNotificationManager(context), idnum)
	}

	func clicked(id: UInt64) {
		if let webview = webview, let context = webview.context {
			WKNotificationManagerProviderDidClickNotification(WKContextGetNotificationManager(webview.context), id)
		}
		// void return, so no confirmation that webview accepted/processed the click
	}

	func requestPermission() -> Bool {
		if let webview = webview, let context = webview.context {
		// TODO: check cache, then popover prompt - if either true:
			authorizeNotifications(fromOrigin: webview.url)
			//   is a little late to do this, the prompt probably came because
			//     the url wasn't previously authorized...
		}
		return true // Notification.permission == "default" => "granted"
	}

	func authorizeNotifications(fromOrigin: URL?) {
		if let url = fromOrigin, let scheme = url.scheme, let host = url.host,
			!host.isEmpty, (scheme == "http" || scheme == "https") {
			// get origin of webview and add it to permissions
			if let origin = WKSecurityOriginCreate(
				// https://github.com/WebKit/webkit/blob/master/Source/WebCore/page/SecurityOrigin.cpp ::create
				WKStringCreateWithUTF8CString(scheme),
				WKStringCreateWithUTF8CString(host),
				Int32(url.port ?? 0) // Cpp falsey
				// https://github.com/WebKit/webkit/blob/master/Source/WebCore/page/SecurityOriginData.cpp
			) {

				let allowed = WKBooleanCreate(true)

				WKDictionarySetItem(
					notificationPermissions,
					WKSecurityOriginCopyToString(origin),
					UnsafeRawPointer(allowed!)
				)
				// https://github.com/WebKit/webkit/blob/89c28d471fae35f1788a0f857067896a10af8974/Source/WebKit/UIProcess/Notifications/WebNotificationProvider.cpp#L105

				if let webview = webview, let context = webview.context {
					WKNotificationManagerProviderDidUpdateNotificationPolicy(WKContextGetNotificationManager(webview.context), origin, true)
				}

				warn("\(url) authorized to make web notifications!")
			}
		}
	}
}
