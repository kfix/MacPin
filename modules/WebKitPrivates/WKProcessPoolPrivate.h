@import WebKit;
// https://github.com/WebKit/webkit/blob/main/Source/WebKit/UIProcess/API/Cocoa/WKProcessPoolPrivate.h

@class _WKProcessPoolConfiguration;
@protocol _WKDownloadDelegate;

@interface WKProcessPool ()
- (instancetype)_initWithConfiguration:(_WKProcessPoolConfiguration *)configuration __attribute__((objc_method_family(init))) NS_DESIGNATED_INITIALIZER;
@end

@interface WKProcessPool (WKPrivate)

+ (WKProcessPool *)_sharedProcessPool; // 10.11.4 ?

@property (nonatomic, readonly) _WKProcessPoolConfiguration *_configuration;

- (void)_setAllowsSpecificHTTPSCertificate:(NSArray *)certificateChain forHost:(NSString *)host;
- (void)_setCanHandleHTTPSServerTrustEvaluation:(BOOL)value WK_API_DEPRECATED_WITH_REPLACEMENT("_WKWebsiteDataStoreConfiguration.fastServerTrustEvaluationEnabled", macos(10.11, WK_MAC_TBA), ios(9.0, WK_IOS_TBA));
- (void)_setCookieAcceptPolicy:(NSHTTPCookieAcceptPolicy)policy;

- (id)_objectForBundleParameter:(NSString *)parameter;
- (void)_setObject:(id <NSCopying, NSSecureCoding>)object forBundleParameter:(NSString *)parameter;
// FIXME: This should be NSDictionary<NSString *, id <NSCopying, NSSecureCoding>>
//- (void)_setObjectsForBundleParametersWithDictionary:(NSDictionary *)dictionary WK_AVAILABLE(WK_MAC_TBA, WK_IOS_TBA);

@property (nonatomic, weak, setter=_setDownloadDelegate:) id <_WKDownloadDelegate> _downloadDelegate;
// https://github.com/WebKit/webkit/blob/main/Tools/TestWebKitAPI/Tests/WebKit2Cocoa/Download.mm
// https://github.com/WebKit/webkit/search?q=_downloadDelegate&type=Code

//@property (nonatomic, weak, setter=_setAutomationDelegate:) id <_WKAutomationDelegate> _automationDelegate WK_API_AVAILABLE(macos(10.12), ios(10.0));

// tells where in the local filesystem any particular URL's cache file ("~/Library/WebKit/WebsiteData") is saved
+ (NSURL *)_websiteDataURLForContainerWithURL:(NSURL *)containerURL;
+ (NSURL *)_websiteDataURLForContainerWithURL:(NSURL *)containerURL bundleIdentifierIfNotInContainer:(NSString *)bundleIdentifier;
//- (void)_automationCapabilitiesDidChange WK_AVAILABLE(WK_MAC_TBA, WK_IOS_TBA);
//- (void)_setAutomationSession:(_WKAutomationSession *)automationSession WK_AVAILABLE(WK_MAC_TBA, WK_IOS_TBA);

// Test only. Returns web processes running web pages (does not include web processes running service workers)
- (size_t)_webPageContentProcessCount WK_API_AVAILABLE(macos(10.13.4), ios(11.3));

//- (void)_warmInitialProcess WK_AVAILABLE(WK_MAC_TBA, WK_IOS_TBA);

- (void)_preconnectToServer:(NSURL *)serverURL WK_API_AVAILABLE(macos(10.13.4), ios(11.3));

@property (nonatomic, getter=_isCookieStoragePartitioningEnabled, setter=_setCookieStoragePartitioningEnabled:) BOOL _cookieStoragePartitioningEnabled WK_API_AVAILABLE(macos(10.12.3), ios(10.3));
@property (nonatomic, getter=_isStorageAccessAPIEnabled, setter=_setStorageAccessAPIEnabled:) BOOL _storageAccessAPIEnabled WK_API_AVAILABLE(macos(10.13.4), ios(11.3));
@end
