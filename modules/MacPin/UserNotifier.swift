import Foundation
import WebKit
import WebKitPrivates

struct NotificationCallbacks {
	// thunks for WebKit user notification C APIs

	static let showCallback: WKNotificationProviderShowCallback = { page, notification, clientInfo in
		// clientInfo == &UserNotifier.shared.notificationProvider.base.clientInfo

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

		let idnum = WKNotificationGetID(notification)

		warn("\(title) - \(body) - \(iconurl)")
		AppScriptRuntime.shared.postNotification(title, subtitle: tag, msg: body, id: String(idnum))
		// TODO store the tag,idnum,clientInfo so we can ping the webview when AppDelegate/main.js says notification was clicked
	}

	static let cancelCallback: WKNotificationProviderCancelCallback = { notification, clientInfo in
		warn("cancel")
	}

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

	static let permissionsCallback: WKNotificationProviderNotificationPermissionsCallback = { clientInfo -> Optional<OpaquePointer> /*WKDictionaryRef*/ in
		warn("permissions")
		return WKMutableDictionaryCreate()
		// WKDictionarySetItem(WKMutableDictionaryRef dictionary, WKStringRef key, WKTypeRef item)
	}

	static let clearCallback: WKNotificationProviderClearNotificationsCallback = { notificationIDs, clientInfo in
		warn("clear")
		// only happens for new about:blank tabs that are closed and deinit'd
		// all active tabs are being retained post-close and not clearing ...
	}
}

class UserNotifier: NSObject  {
	static let shared = UserNotifier() // create & export the singleton

	// https://github.com/WebKit/webkit/blob/5277f6fb92b0c03958265d24a7692142f7bdeaf8/Tools/WebKitTestRunner/WebNotificationProvider.cpp
	var notificationProvider = WKNotificationProviderV0(
		base: WKNotificationProviderBase(),
		show: NotificationCallbacks.showCallback,
		cancel: NotificationCallbacks.cancelCallback,
		didDestroyNotification: NotificationCallbacks.destroyCallback,
		addNotificationManager: NotificationCallbacks.addCallback,
		removeNotificationManager: NotificationCallbacks.removeCallback,
		notificationPermissions: nil, // NotificationCallbacks.permissionsCallback,
		clearNotifications: NotificationCallbacks.clearCallback
	)

	func subscribe(webview: MPWebView) {
		warn()
		WKNotificationManagerSetProvider(WKContextGetNotificationManager(webview.context), &notificationProvider.base)
		// FIXME: create a new provider(.base) for each webview? that way the clientInfo's will be tab-unique ....
	}

}
