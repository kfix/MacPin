import WebKitPrivates
import CoreFoundation

struct WebKitNotificationCallbacks {

	// Requests that a notification be shown.
	// https://www.w3.org/TR/notifications/#showing-a-notification
	static let showCallback: WKNotificationProviderShowCallback = { page, notification, clientInfo in
		weak var notifier = unsafeBitCast(clientInfo, to: WebNotifier.self)
		guard notifier != nil else { warn("no WebNotifier provided to callback!"); return }
		notifier?.showWebNotification(page!, notification!)
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

	static func makeProvider(_ webNotifier: WebNotifier) -> WKNotificationProviderV0 { return WKNotificationProviderV0(
		base: WKNotificationProviderBase(version: 0, clientInfo: Unmanaged.passUnretained(webNotifier).toOpaque()), // +0
		show: showCallback,
		cancel: cancelCallback,
		didDestroyNotification: nil, // destroyCallback,
		addNotificationManager: addCallback,
		removeNotificationManager: removeCallback,
		notificationPermissions: nil, // permissionsCallback,
		clearNotifications: clearCallback
	)}

	static func getManager(_ client: MPWebView) -> WKNotificationManagerRef? {
		if let context = client.context {
			return WKContextGetNotificationManager(context)
		}
		return nil
	}

	static func subscribe(_ provider: inout WKNotificationProviderV0, webview: MPWebView) {
		if let manager = getManager(webview) {
			WKNotificationManagerSetProvider(manager, &provider.base)
			warn("subscribed to Notification updates: \(webview)")
		}
	}

	static func unsubscribe(_ webview: MPWebView) {
		if let manager = getManager(webview) {
			WKNotificationManagerSetProvider(manager, nil)
			warn("unsubscribed from Notification updates: \(webview)")
		}
	}
}

class WebNotifier {
	// https://github.com/WebKit/webkit/blob/master/Tools/WebKitTestRunner/WebNotificationProvider.cpp
	// https://github.com/WebKit/webkit/blob/master/Tools/WebKitTestRunner/WebNotificationProvider.h

	lazy var wk_provider: WKNotificationProviderV0 = {
	    return WebKitNotificationCallbacks.makeProvider(self)
	}()

	static let shared = WebNotifier()

	var subscribers: [MPWebView] = []

	func subscribe(_ webview: MPWebView) {
		WebKitNotificationCallbacks.subscribe(&wk_provider, webview: webview)
		subscribers.append(webview)
		// func WKNotificationManagerProviderDidUpdateNotificationPolicy(_ managerRef: WKNotificationManagerRef!, _ origin: WKSecurityOriginRef!, _ allowed: Bool)
	}

	func unsubscribe(_ webview: MPWebView) {
		WebKitNotificationCallbacks.unsubscribe(webview)
		subscribers.removeAll(where: {$0 == webview})
	}

	deinit {
		for webview in subscribers {
			unsubscribe(webview)
		}
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

		if let webview = subscribers.first(where: {$0._page == page}) {
			webview.showDesktopNotification(title: title, tag: tag, body: body, iconurl: iconurl, id: Int(idnum), type: type, origin: origin, lang: lang, dir: dir)
			// let the webview know we sent it
			WKNotificationManagerProviderDidShowNotification(WKContextGetNotificationManager(context), idnum)
		}

	}

	func clicked(webview: MPWebView, id: UInt64) {
		WKNotificationManagerProviderDidClickNotification(WKContextGetNotificationManager(webview.context), id)
		// void return, so no confirmation that webview accepted/processed the click
	}
}
