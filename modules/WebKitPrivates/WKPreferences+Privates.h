@import WebKit;
//#import <wtf/RefPtr.h> // https://github.com/WebKit/webkit/blob/master/Source/WTF/wtf/RefPtr.h
/*
// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/Cocoa/WKPreferencesInternal.h
//namespace WebKit {
//class WebPreferences;
//}
@interface WKPreferences () {
@public
//_preferences = WebKit::WebPreferences
RefPtr<WebKit::WebPreferences> _preferences;
}
@end
*/

typedef NS_ENUM(NSInteger, _WKStorageBlockingPolicy) {
    _WKStorageBlockingPolicyAllowAll,
    _WKStorageBlockingPolicyBlockThirdParty,
    _WKStorageBlockingPolicyBlockAll,
} WK_ENUM_AVAILABLE(10_10, 8_0);

typedef NS_OPTIONS(NSUInteger, _WKDebugOverlayRegions) {
    _WKNonFastScrollableRegion = 1 << 0,
    _WKWheelEventHandlerRegion = 1 << 1
} WK_ENUM_AVAILABLE(10_11, 9_0);

typedef NS_OPTIONS(NSUInteger, _WKJavaScriptRuntimeFlags) {
    _WKJavaScriptRuntimeFlagsAllEnabled = 0
} WK_ENUM_AVAILABLE(10_11, 9_0);

@interface WKPreferences (Privates)
// https://github.com/WebKit/webkit/blob/master/Source/WebKit/UIProcess/API/C/WKPreferencesRefPrivate.h
// https://github.com/WebKit/webkit/blob/master/Source/WebKit/UIProcess/API/C/WKPreferences.cpp
// https://github.com/WebKit/webkit/blob/master/Source/WebKit/UIProcess/API/Cocoa/WKPreferencesPrivate.h
@property (nonatomic, setter=_setStorageBlockingPolicy:) _WKStorageBlockingPolicy _storageBlockingPolicy;
@property (nonatomic, setter=_setDeveloperExtrasEnabled:) BOOL _developerExtrasEnabled;
@property (nonatomic, setter=_setDiagnosticLoggingEnabled:) BOOL _diagnosticLoggingEnabled WK2_AVAILABLE(10_11, 9_0);
@property (nonatomic, setter=_setStandalone:, getter=_isStandalone) BOOL _standalone WK_API_AVAILABLE(macosx(10.11), ios(9.0));
@property (nonatomic, setter=_setVisibleDebugOverlayRegions:) _WKDebugOverlayRegions _visibleDebugOverlayRegions WK2_AVAILABLE(10_11, 9_0);
@property (nonatomic, setter=_setSimpleLineLayoutDebugBordersEnabled:) BOOL _simpleLineLayoutDebugBordersEnabled WK2_AVAILABLE(10_11, 9_0);
@property (nonatomic, setter=_setLogsPageMessagesToSystemConsoleEnabled:) BOOL _logsPageMessagesToSystemConsoleEnabled WK2_AVAILABLE(10_11, 9_0);
@property (nonatomic, setter=_setAllowFileAccessFromFileURLs:) BOOL _allowFileAccessFromFileURLs WK2_AVAILABLE(10_11, 9_0);
@property (nonatomic, setter=_setJavaScriptRuntimeFlags:) _WKJavaScriptRuntimeFlags _javaScriptRuntimeFlags WK2_AVAILABLE(10_11, 9_0);

@property (nonatomic, setter=_setOfflineApplicationCacheIsEnabled:) BOOL _offlineApplicationCacheIsEnabled;
@property (nonatomic, setter=_setFullScreenEnabled:) BOOL _fullScreenEnabled WK_API_AVAILABLE(macosx(10.11), ios(9.0));
@property (nonatomic, setter=_setDefaultFontSize:) NSUInteger _defaultFontSize WK_API_AVAILABLE(macosx(10.12), ios(10.0));
@property (nonatomic, setter=_setDefaultFixedPitchFontSize:) NSUInteger _defaultFixedPitchFontSize WK_API_AVAILABLE(macosx(10.12), ios(10.0));
@property (nonatomic, copy, setter=_setFixedPitchFontFamily:) NSString *_fixedPitchFontFamily WK_API_AVAILABLE(macosx(10.12), ios(10.0));

@property (nonatomic, setter=_setAllowsPictureInPictureMediaPlayback:) BOOL _allowsPictureInPictureMediaPlayback WK_API_AVAILABLE(macosx(WK_MAC_TBA), ios(WK_IOS_TBA));
@property (nonatomic, setter=_setApplePayCapabilityDisclosureAllowed:) BOOL _applePayCapabilityDisclosureAllowed WK_API_AVAILABLE(macosx(10.12), ios(10.0));
@property (nonatomic, setter=_setLoadsImagesAutomatically:) BOOL _loadsImagesAutomatically WK_API_AVAILABLE(macosx(WK_MAC_TBA), ios(WK_IOS_TBA));

@property (nonatomic, setter=_setPeerConnectionEnabled:) BOOL _peerConnectionEnabled WK_API_AVAILABLE(macosx(WK_MAC_TBA), ios(WK_IOS_TBA));
@property (nonatomic, setter=_setMediaDevicesEnabled:) BOOL _mediaDevicesEnabled WK_API_AVAILABLE(macosx(10.13), ios(11.0));
@property (nonatomic, setter=_setMockCaptureDevicesEnabled:) BOOL _mockCaptureDevicesEnabled WK_API_AVAILABLE(macosx(10.13), ios(11.0));
@property (nonatomic, setter=_setMockCaptureDevicesPromptEnabled:) BOOL _mockCaptureDevicesPromptEnabled WK_API_AVAILABLE(macosx(WK_MAC_TBA), ios(WK_IOS_TBA));
@property (nonatomic, setter=_setMediaCaptureRequiresSecureConnection:) BOOL _mediaCaptureRequiresSecureConnection WK_API_AVAILABLE(macosx(10.13), ios(11.0));
@property (nonatomic, setter=_setEnumeratingAllNetworkInterfacesEnabled:) BOOL _enumeratingAllNetworkInterfacesEnabled WK_API_AVAILABLE(macosx(10.13), ios(11.0));
@property (nonatomic, setter=_setICECandidateFilteringEnabled:) BOOL _iceCandidateFilteringEnabled WK_API_AVAILABLE(macosx(WK_MAC_TBA), ios(WK_IOS_TBA));
@property (nonatomic, setter=_setWebRTCLegacyAPIEnabled:) BOOL _webRTCLegacyAPIEnabled WK_API_AVAILABLE(macosx(10.13), ios(11.0));

@property (nonatomic, setter=_setJavaScriptCanAccessClipboard:) BOOL _javaScriptCanAccessClipboard WK_API_AVAILABLE(macosx(10.13), ios(11.0));
@property (nonatomic, setter=_setDOMPasteAllowed:) BOOL _domPasteAllowed WK_API_AVAILABLE(macosx(10.13), ios(11.0));

//+ (NSArray<_WKExperimentalFeature *> *)_experimentalFeatures WK_API_AVAILABLE(macosx(10.12), ios(10.0));
//- (BOOL)_isEnabledForFeature:(_WKExperimentalFeature *)feature WK_API_AVAILABLE(macosx(10.12), ios(10.0));
//- (void)_setEnabled:(BOOL)value forFeature:(_WKExperimentalFeature *)feature WK_API_AVAILABLE(macosx(10.12), ios(10.0));

@property (nonatomic, setter=_setMediaDocumentEntersFullscreenAutomatically:) BOOL _mediaDocumentEntersFullscreenAutomatically WK_API_AVAILABLE(macosx(WK_MAC_TBA), ios(WK_IOS_TBA));

#if !TARGET_OS_IPHONE
@property (nonatomic, setter=_setPlugInsEnabled:) BOOL _plugInsEnabled WK_API_AVAILABLE(macosx(WK_MAC_TBA));
#endif

@end
