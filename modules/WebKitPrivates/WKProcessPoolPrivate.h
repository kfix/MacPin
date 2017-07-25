@import WebKit;
// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/Cocoa/WKProcessPoolPrivate.h

#if WK_API_ENABLED

@class _WKProcessPoolConfiguration;
@protocol _WKDownloadDelegate;

@interface WKProcessPool () 
- (instancetype)_initWithConfiguration:(_WKProcessPoolConfiguration *)configuration __attribute__((objc_method_family(init))) WK_DESIGNATED_INITIALIZER;
@end

@interface WKProcessPool (WKPrivate)

+ (WKProcessPool *)_sharedProcessPool; // 10.11.4 ?

@property (nonatomic, readonly) _WKProcessPoolConfiguration *_configuration;

- (void)_setAllowsSpecificHTTPSCertificate:(NSArray *)certificateChain forHost:(NSString *)host;
- (void)_setCanHandleHTTPSServerTrustEvaluation:(BOOL)value WK2_AVAILABLE(10_11, 9_0);
- (void)_setCookieAcceptPolicy:(NSHTTPCookieAcceptPolicy)policy;

- (id)_objectForBundleParameter:(NSString *)parameter;
- (void)_setObject:(id <NSCopying, NSSecureCoding>)object forBundleParameter:(NSString *)parameter;
// FIXME: This should be NSDictionary<NSString *, id <NSCopying, NSSecureCoding>>
//- (void)_setObjectsForBundleParametersWithDictionary:(NSDictionary *)dictionary WK_AVAILABLE(WK_MAC_TBA, WK_IOS_TBA);

@property (nonatomic, weak, setter=_setDownloadDelegate:) id <_WKDownloadDelegate> _downloadDelegate;
// https://github.com/WebKit/webkit/blob/master/Tools/TestWebKitAPI/Tests/WebKit2Cocoa/Download.mm
// https://github.com/WebKit/webkit/search?q=_downloadDelegate&type=Code

// tells where in the local filesystem any particular URL's cache file ("~/Library/WebKit/WebsiteData") is saved
+ (NSURL *)_websiteDataURLForContainerWithURL:(NSURL *)containerURL;
+ (NSURL *)_websiteDataURLForContainerWithURL:(NSURL *)containerURL bundleIdentifierIfNotInContainer:(NSString *)bundleIdentifier;
//- (void)_automationCapabilitiesDidChange WK_AVAILABLE(WK_MAC_TBA, WK_IOS_TBA);
//- (void)_setAutomationSession:(_WKAutomationSession *)automationSession WK_AVAILABLE(WK_MAC_TBA, WK_IOS_TBA);

//- (void)_warmInitialProcess WK_AVAILABLE(WK_MAC_TBA, WK_IOS_TBA);

@end

#endif
