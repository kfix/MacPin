// thunk-chunks for WebKit C APIs
import CoreFoundation
import WebKitPrivates

struct WebViewNotificationCallbacks {

	// Requests that a notification be shown.
	// https://www.w3.org/TR/notifications/#showing-a-notification
	static let showCallback: WKNotificationProviderShowCallback = { page, notification, clientInfo in
		let webview = unsafeBitCast(clientInfo, to: MPWebView.self)

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
		webview.showDesktopNotification(title: title, tag: tag, body: body, iconurl: iconurl, id: Int(idnum), type: type, origin: origin, lang: lang, dir: dir)

		if let manager = getManager(webview) {
			// let the webview know we sent it
			WKNotificationManagerProviderDidShowNotification(manager, idnum)
		}
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

	static func getManager(_ client: MPWebView) -> WKNotificationManagerRef? {
		if let context = client.context {
			return WKContextGetNotificationManager(context)
		}
		return nil
	}

	static func subscribe(_ client: MPWebView) {
		warn()
		var provider = makeProvider()
		provider.base = WKNotificationProviderBase(version: 0, clientInfo: Unmanaged.passUnretained(client).toOpaque())
		if let manager = getManager(client) {
			WKNotificationManagerSetProvider(manager, &provider.base)
		}
		// func WKNotificationManagerProviderDidUpdateNotificationPolicy(_ managerRef: WKNotificationManagerRef!, _ origin: WKSecurityOriginRef!, _ allowed: Bool)
	}
}


struct WebViewUICallbacks {

	static let decidePolicyForGeolocationPermissionRequestCallBack: WKPageDecidePolicyForGeolocationPermissionRequestCallback = { page, frame, origin, permissionRequest, clientInfo in
		// FIXME: prompt?
		warn("", function: "decide pol for geoloc req")
		WKGeolocationPermissionRequestAllow(permissionRequest)
	}

	static let decidePolicyForNotificationPermissionRequest: WKPageDecidePolicyForNotificationPermissionRequestCallback = { page, securityOrigin, permissionRequest, clientInfo in
		warn("", function: "decide pol for notif req")
		WKNotificationPermissionRequestAllow(permissionRequest)
		//WKNotificationPermissionRequestDeny(permissionRequest)
	}

	static func makeClient() -> WKPageUIClientV2 {
		var uiClient = WKPageUIClientV2()
		uiClient.base.version = 2
#if os(OSX)
		uiClient.decidePolicyForGeolocationPermissionRequest = decidePolicyForGeolocationPermissionRequestCallBack
		uiClient.decidePolicyForNotificationPermissionRequest = decidePolicyForNotificationPermissionRequest
#endif
		//uiClient.showPage: WKPageUIClientCallback!
		//uiClient.close: WKPageUIClientCallback!
		//uiClient.takeFocus: WKPageTakeFocusCallback!
		//uiClient.focus: WKPageFocusCallback! // window.focus()
		//uiClient.unfocus: WKPageUnfocusCallback! // window.blur()

		// V9:
		//  didClickAutoFillButton: WKPageDidClickAutoFillButtonCallback!
		//  requestPointerLock: WKRequestPointerLockCallback!
		//  didLosePointerLock: WKDidLosePointerLockCallback!
		//  handleAutoplayEvent: WKHandleAutoplayEventCallback!

		// https://developer.mozilla.org/en-US/docs/Web/API/Window/status
		// https://developer.mozilla.org/en-US/docs/Web/API/Window/statusbar
		//uiClient.setStatusText: WKPageSetStatusTextCallback!
		//statusBarIsVisible: WKPageGetStatusBarIsVisibleCallback!
		//setStatusBarIsVisible: WKPageSetStatusBarIsVisibleCallback!

		return uiClient
	}

	static func subscribe(_ webview: MPWebView) {
		warn()
		var uiClient = makeClient()
		uiClient.base.clientInfo = UnsafeRawPointer(Unmanaged.passUnretained(webview).toOpaque()) // +0
		guard let page = webview._page else { return }
		WKPageSetPageUIClient(page, &uiClient.base)
	}
}
