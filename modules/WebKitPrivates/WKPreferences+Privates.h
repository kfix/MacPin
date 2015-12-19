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
// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/Cocoa/WKPreferencesPrivate.h
@property (nonatomic, setter=_setStorageBlockingPolicy:) _WKStorageBlockingPolicy _storageBlockingPolicy;
@property (nonatomic, setter=_setDeveloperExtrasEnabled:) BOOL _developerExtrasEnabled;
@property (nonatomic, setter=_setFullScreenEnabled:) BOOL _fullScreenIsEnabled WK_AVAILABLE(10_11, 9_0);
@property (nonatomic, setter=_setDiagnosticLoggingEnabled:) BOOL _diagnosticLoggingEnabled  WK_AVAILABLE(10_11, 9_0);
@property (nonatomic, setter=_setStandalone:, getter=_isStandalone) BOOL _standalone;
@property (nonatomic, setter=_setVisibleDebugOverlayRegions:) _WKDebugOverlayRegions _visibleDebugOverlayRegions WK_AVAILABLE(10_11, 9_0);
@property (nonatomic, setter=_setSimpleLineLayoutDebugBordersEnabled:) BOOL _simpleLineLayoutDebugBordersEnabled WK_AVAILABLE(10_11, 9_0);
@property (nonatomic, setter=_setLogsPageMessagesToSystemConsoleEnabled:) BOOL _logsPageMessagesToSystemConsoleEnabled WK_AVAILABLE(10_11, 9_0);
@property (nonatomic, setter=_setAllowFileAccessFromFileURLs:) BOOL _allowFileAccessFromFileURLs WK_AVAILABLE(10_11, 9_0);
@property (nonatomic, setter=_setJavaScriptRuntimeFlags:) _WKJavaScriptRuntimeFlags _javaScriptRuntimeFlags WK_AVAILABLE(10_11, 9_0);
@end
