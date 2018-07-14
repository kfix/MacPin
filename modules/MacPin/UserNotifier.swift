import Foundation
import WebKit
import WebKitPrivates

struct NotificationCallbacks {
	// thunks for WebKit user notification C APIs

	// Requests that a notification be shown.
	// https://www.w3.org/TR/notifications/#showing-a-notification
	static let showCallback: WKNotificationProviderShowCallback = { page, notification, clientInfo in
		//let notifier = unsafeBitCast(clientInfo, to: UserNotifier.self)
		//let webview = unsafeBitCast(clientInfo, to: MPWebView.self)

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

		let type = WKNotificationGetTypeID()

		let idnum = WKNotificationGetID(notification)

		warn("\(title) - \(body) - \(iconurl) - \(origin)")
		AppScriptRuntime.shared.postNotification(title, subtitle: tag, msg: body, id: String(idnum))
		// webview.showDesktopNotification(title: title, tag: tag, body: body, iconurl: iconurl, id: idnum, type: type, origin: origin, lang: lang, dir: dir)
		// ^^ enables tab-focusing activations to webview's DOM
	}

	// Requests that a notification that has already been shown be canceled.
	static let cancelCallback: WKNotificationProviderCancelCallback = { notification, clientInfo in
		warn("cancel")
	}

    // Informs the presenter that a Notification object has been destroyed
    // (such as by a page transition). The presenter may continue showing
    // the notification, but must not attempt to call the event handlers.
	static let destroyCallback: WKNotificationProviderDidDestroyNotificationCallback = { notification, clientInfo in
		warn("destroy")
	}

	static let removeCallback: WKNotificationProviderRemoveNotificationManagerCallback = { manager, clientInfo in
		warn("remove")
	}

	static let addCallback: WKNotificationProviderAddNotificationManagerCallback = { manager, clientInfo in
		warn("add")
		// seems to happen for erry new tab
	}

	 // Checks the current level of permission.
	static let permissionsCallback: WKNotificationProviderNotificationPermissionsCallback = { clientInfo -> Optional<OpaquePointer> /*WKDictionaryRef*/ in
		warn("permissions")
		return WKMutableDictionaryCreate()
		// WKDictionarySetItem(WKMutableDictionaryRef dictionary, WKStringRef key, WKTypeRef item)
	}

	// Cancel all outstanding requests
	static let clearCallback: WKNotificationProviderClearNotificationsCallback = { notificationIDs, clientInfo in
		warn("clear")
		// only happens for new about:blank tabs that are closed and deinit'd
	}

	// https://github.com/WebKit/webkit/blob/5277f6fb92b0c03958265d24a7692142f7bdeaf8/Tools/WebKitTestRunner/WebNotificationProvider.cpp
	static func makeProvider() -> WKNotificationProviderV0 { return WKNotificationProviderV0(
		base: WKNotificationProviderBase(),
		show: showCallback,
		cancel: cancelCallback,
		didDestroyNotification: destroyCallback,
		addNotificationManager: addCallback,
		removeNotificationManager: removeCallback,
		notificationPermissions: nil, // permissionsCallback,
		clearNotifications: clearCallback
	)}

	static func subscribe(_ client: MPWebView) {
		warn()
		var provider = NotificationCallbacks.makeProvider()
		provider.base = WKNotificationProviderBase(version: 0, clientInfo: Unmanaged.passUnretained(client).toOpaque())
		WKNotificationManagerSetProvider(WKContextGetNotificationManager(client.context), &provider.base)
		// func WKNotificationManagerProviderDidUpdateNotificationPolicy(_ managerRef: WKNotificationManagerRef!, _ origin: WKSecurityOriginRef!, _ allowed: Bool)
	}

}

class UserNotifier: NSObject  {
	static let shared = UserNotifier() // create & export the singleton

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
