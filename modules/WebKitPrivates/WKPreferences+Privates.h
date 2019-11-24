@import WebKit;
//#import <wtf/RefPtr.h> // https://github.com/WebKit/webkit/blob/master/Source/WTF/wtf/RefPtr.h
/*
// https://github.com/WebKit/webkit/blob/master/Source/WebKit/UIProcess/API/Cocoa/WKPreferencesInternal.h
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
} WK_API_AVAILABLE(macos(10.10), ios(8.0));

typedef NS_OPTIONS(NSUInteger, _WKDebugOverlayRegions) {
    _WKNonFastScrollableRegion = 1 << 0,
    _WKWheelEventHandlerRegion = 1 << 1
} WK_API_AVAILABLE(macos(10.11), ios(9.0));

typedef NS_OPTIONS(NSUInteger, _WKJavaScriptRuntimeFlags) {
    _WKJavaScriptRuntimeFlagsAllEnabled = 0
} WK_API_AVAILABLE(macos(10.11), ios(9.0));

@interface WKPreferences (Privates)
// https://github.com/WebKit/webkit/blob/master/Source/WebKit/UIProcess/API/C/WKPreferencesRefPrivate.h
// https://github.com/WebKit/webkit/blob/master/Source/WebKit/UIProcess/API/C/WKPreferences.cpp
// https://github.com/WebKit/webkit/blob/master/Source/WebKit/UIProcess/API/Cocoa/WKPreferencesPrivate.h
@property (nonatomic, setter=_setStorageBlockingPolicy:) _WKStorageBlockingPolicy _storageBlockingPolicy;


@property (nonatomic, setter=_setCompositingBordersVisible:) BOOL _compositingBordersVisible;
@property (nonatomic, setter=_setCompositingRepaintCountersVisible:) BOOL _compositingRepaintCountersVisible;
@property (nonatomic, setter=_setTiledScrollingIndicatorVisible:) BOOL _tiledScrollingIndicatorVisible;
@property (nonatomic, setter=_setResourceUsageOverlayVisible:) BOOL _resourceUsageOverlayVisible WK_API_AVAILABLE(macos(10.12), ios(10.0));
@property (nonatomic, setter=_setVisibleDebugOverlayRegions:) _WKDebugOverlayRegions _visibleDebugOverlayRegions WK_API_AVAILABLE(macos(10.11), ios(9.0));
@property (nonatomic, setter=_setSimpleLineLayoutEnabled:) BOOL _simpleLineLayoutEnabled WK_API_AVAILABLE(macos(10.12), ios(10.0));
@property (nonatomic, setter=_setSimpleLineLayoutDebugBordersEnabled:) BOOL _simpleLineLayoutDebugBordersEnabled WK_API_AVAILABLE(macos(10.11), ios(9.0));
@property (nonatomic, setter=_setAcceleratedDrawingEnabled:) BOOL _acceleratedDrawingEnabled WK_API_AVAILABLE(macos(10.12), ios(10.0));
@property (nonatomic, setter=_setDisplayListDrawingEnabled:) BOOL _displayListDrawingEnabled WK_API_AVAILABLE(macos(10.12), ios(10.0));
@property (nonatomic, setter=_setVisualViewportEnabled:) BOOL _visualViewportEnabled WK_API_AVAILABLE(macos(10.12.3), ios(10.3));
@property (nonatomic, setter=_setLargeImageAsyncDecodingEnabled:) BOOL _largeImageAsyncDecodingEnabled WK_API_AVAILABLE(macos(10.12.3), ios(10.3));
@property (nonatomic, setter=_setAnimatedImageAsyncDecodingEnabled:) BOOL _animatedImageAsyncDecodingEnabled WK_API_AVAILABLE(macos(10.12.3), ios(10.3));
@property (nonatomic, setter=_setTextAutosizingEnabled:) BOOL _textAutosizingEnabled WK_API_AVAILABLE(macos(10.12), ios(10.0));
@property (nonatomic, setter=_setSubpixelAntialiasedLayerTextEnabled:) BOOL _subpixelAntialiasedLayerTextEnabled WK_API_AVAILABLE(macos(10.12), ios(10.0));

@property (nonatomic, setter=_setDeveloperExtrasEnabled:) BOOL _developerExtrasEnabled WK_API_AVAILABLE(macos(10.11), ios(9.0));

@property (nonatomic, setter=_setLogsPageMessagesToSystemConsoleEnabled:) BOOL _logsPageMessagesToSystemConsoleEnabled WK_API_AVAILABLE(macos(10.11), ios(9.0));

@property (nonatomic, setter=_setAllowFileAccessFromFileURLs:) BOOL _allowFileAccessFromFileURLs WK_API_AVAILABLE(macos(10.11), ios(9.0));
@property (nonatomic, setter=_setJavaScriptRuntimeFlags:) _WKJavaScriptRuntimeFlags _javaScriptRuntimeFlags WK_API_AVAILABLE(macos(10.11), ios(9.0));

@property (nonatomic, setter=_setStandalone:, getter=_isStandalone) BOOL _standalone WK_API_AVAILABLE(macos(10.11), ios(9.0));

@property (nonatomic, setter=_setDiagnosticLoggingEnabled:) BOOL _diagnosticLoggingEnabled WK_API_AVAILABLE(macos(10.11), ios(9.0));

@property (nonatomic, setter=_setDefaultFontSize:) NSUInteger _defaultFontSize WK_API_AVAILABLE(macos(10.12), ios(10.0));
@property (nonatomic, setter=_setDefaultFixedPitchFontSize:) NSUInteger _defaultFixedPitchFontSize WK_API_AVAILABLE(macos(10.12), ios(10.0));
@property (nonatomic, copy, setter=_setFixedPitchFontFamily:) NSString *_fixedPitchFontFamily WK_API_AVAILABLE(macos(10.12), ios(10.0));

@property (nonatomic, setter=_setOfflineApplicationCacheIsEnabled:) BOOL _offlineApplicationCacheIsEnabled;
@property (nonatomic, setter=_setFullScreenEnabled:) BOOL _fullScreenEnabled WK_API_AVAILABLE(macos(10.11), ios(9.0));
@property (nonatomic, setter=_setShouldSuppressKeyboardInputDuringProvisionalNavigation:) BOOL _shouldSuppressKeyboardInputDuringProvisionalNavigation WK_API_AVAILABLE(macos(10.12.3), ios(10.3));
@property (nonatomic, setter=_setAllowsPictureInPictureMediaPlayback:) BOOL _allowsPictureInPictureMediaPlayback WK_API_AVAILABLE(macos(10.13), ios(11.0));

@property (nonatomic, setter=_setApplePayCapabilityDisclosureAllowed:) BOOL _applePayCapabilityDisclosureAllowed WK_API_AVAILABLE(macos(10.12), ios(10.0));

@property (nonatomic, setter=_setLoadsImagesAutomatically:) BOOL _loadsImagesAutomatically WK_API_AVAILABLE(macos(10.13), ios(11.0));

@property (nonatomic, setter=_setPeerConnectionEnabled:) BOOL _peerConnectionEnabled WK_API_AVAILABLE(macos(10.13.4), ios(11.3));
@property (nonatomic, setter=_setMediaDevicesEnabled:) BOOL _mediaDevicesEnabled WK_API_AVAILABLE(macos(10.13), ios(11.0));
@property (nonatomic, setter=_setScreenCaptureEnabled:) BOOL _screenCaptureEnabled WK_API_AVAILABLE(macos(10.13.4), ios(11.3));
@property (nonatomic, setter=_setMockCaptureDevicesEnabled:) BOOL _mockCaptureDevicesEnabled WK_API_AVAILABLE(macos(10.13), ios(11.0));
@property (nonatomic, setter=_setMockCaptureDevicesPromptEnabled:) BOOL _mockCaptureDevicesPromptEnabled WK_API_AVAILABLE(macos(10.13.4), ios(11.3));
@property (nonatomic, setter=_setMediaCaptureRequiresSecureConnection:) BOOL _mediaCaptureRequiresSecureConnection WK_API_AVAILABLE(macos(10.13), ios(11.0));
@property (nonatomic, setter=_setEnumeratingAllNetworkInterfacesEnabled:) BOOL _enumeratingAllNetworkInterfacesEnabled WK_API_AVAILABLE(macos(10.13), ios(11.0));
@property (nonatomic, setter=_setICECandidateFilteringEnabled:) BOOL _iceCandidateFilteringEnabled WK_API_AVAILABLE(macos(10.13.4), ios(11.3));
@property (nonatomic, setter=_setWebRTCLegacyAPIEnabled:) BOOL _webRTCLegacyAPIEnabled WK_API_AVAILABLE(macos(10.13), ios(11.0));
@property (nonatomic, setter=_setInactiveMediaCaptureSteamRepromptIntervalInMinutes:) double _inactiveMediaCaptureSteamRepromptIntervalInMinutes WK_API_AVAILABLE(macos(10.13.4), ios(11.3));

@property (nonatomic, setter=_setJavaScriptCanAccessClipboard:) BOOL _javaScriptCanAccessClipboard WK_API_AVAILABLE(macos(10.13), ios(11.0));
@property (nonatomic, setter=_setDOMPasteAllowed:) BOOL _domPasteAllowed WK_API_AVAILABLE(macos(10.13), ios(11.0));

@property (nonatomic, setter=_setShouldAllowUserInstalledFonts:) BOOL _shouldAllowUserInstalledFonts WK_API_AVAILABLE(macos(10.13.4), ios(11.3));

//@property (nonatomic, setter=_setEditableLinkBehavior:) _WKEditableLinkBehavior _editableLinkBehavior WK_API_AVAILABLE(macos(10.13.4), ios(11.3));

@property (nonatomic, setter=_setAVFoundationEnabled:) BOOL _avFoundationEnabled WK_API_AVAILABLE(macos(10.10), ios(WK_IOS_TBA));

//+ (NSArray<_WKExperimentalFeature *> *)_experimentalFeatures WK_API_AVAILABLE(macos(10.12), ios(10.0));
//- (BOOL)_isEnabledForFeature:(_WKExperimentalFeature *)feature WK_API_AVAILABLE(macos(10.12), ios(10.0));
//- (void)_setEnabled:(BOOL)value forFeature:(_WKExperimentalFeature *)feature WK_API_AVAILABLE(macos(10.12), ios(10.0));

@property (nonatomic, setter=_setMediaDocumentEntersFullscreenAutomatically:) BOOL _mediaDocumentEntersFullscreenAutomatically WK_API_AVAILABLE(macos(WK_MAC_TBA), ios(WK_IOS_TBA));

@property (nonatomic, setter=_setColorFilterEnabled:) BOOL _colorFilterEnabled WK_API_AVAILABLE(macos(WK_MAC_TBA), ios(WK_IOS_TBA));

#if !TARGET_OS_IPHONE
@property (nonatomic, setter=_setWebGLEnabled:) BOOL _webGLEnabled WK_API_AVAILABLE(macos(10.13.4));
@property (nonatomic, setter=_setPlugInsEnabled:) BOOL _plugInsEnabled WK_API_AVAILABLE(macos(WK_MAC_TBA));
#endif

@end
