import Foundation
import WebKit
import WebKitPrivates

class UserNotifier: NSObject  {
	static let shared = UserNotifier() // create & export the singleton

	// thunks for WebKit user notification C APIs

	static let showCallback: WKNotificationProviderShowCallback = { page, notification, clientInfo in
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

	//static let permissionsCallback: WKNotificationProviderNotificationPermissionsCallback = { clientInfo -> WKDictionaryRef in }

	static let clearCallback: WKNotificationProviderClearNotificationsCallback = { notificationIDs, clientInfo in
		warn("clear")
	}

	// https://github.com/WebKit/webkit/blob/5277f6fb92b0c03958265d24a7692142f7bdeaf8/Tools/WebKitTestRunner/WebNotificationProvider.cpp
	var notificationProvider = WKNotificationProviderV0(
		base: WKNotificationProviderBase(),
		show: UserNotifier.showCallback,
		cancel: UserNotifier.cancelCallback,
		didDestroyNotification: UserNotifier.destroyCallback,
		addNotificationManager: UserNotifier.addCallback,
		removeNotificationManager: UserNotifier.removeCallback,
		notificationPermissions: nil, // UserNotifier.permissionsCallback,
		clearNotifications: UserNotifier.clearCallback
	)

	func subscribe(webview: MPWebView) {
		warn()
		WKNotificationManagerSetProvider(WKContextGetNotificationManager(webview.context), &notificationProvider.base)
	}

}
