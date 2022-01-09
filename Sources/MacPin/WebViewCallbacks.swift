// thunk-chunks for WebKit C APIs
import WebKitPrivates

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

//	static let checkUserMediaPermissions: WKCheckUserMediaPermissionCallback = { page, frame, mediaOrigin, topOrigin, permissionRequest, clientInfo in
//		WKUserMediaPermissionCheckSetUserMediaAccessInfo(permissionRequest, WKStringCreateWithUTF8CString("0x123456789"), true)
//	}

	// static let decidePolicyForUserMediaPermissionRequest: WK = { page, frame, mediaOrigin, topOrigin, permissionRequest, clientInfo in
	//  https://github.com/WebKit/webkit/blob/master/Tools/TestWebKitAPI/Tests/WebKit/UserMedia.cpp
		//WKUserMediaPermissionRequestAllow(permissionRequest,
		//, WKUserMediaPermissionRequestAudioDeviceUIDs(permissionRequest)
		//, WKUserMediaPermissionRequestVideoDeviceUIDs(permissionRequest)
		//)
	// without this, requests auto-denied
	//https://github.com/WebKit/webkit/blob/7e853093871006bd0e9455272189e0d045df927e/Source/WebKit/UIProcess/UserMediaPermissionRequestManagerProxy.cpp#L318


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

		// V6:
		//  checkUserMediaPermissionForOrigin = checkUserMediaPermissionCallback
		//	decidePolicyForUserMediaPermissionRequest = decidePolicyForUserMediaPermissionRequest

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
		warn("UI")
		var uiClient = makeClient()
		uiClient.base.clientInfo = UnsafeRawPointer(Unmanaged.passUnretained(webview).toOpaque()) // +0
		guard let page = webview._page else { return }
		WKPageSetPageUIClient(page, &uiClient.base)
	}
}
