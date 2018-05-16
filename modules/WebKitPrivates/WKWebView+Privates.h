@import WebKit;
// https://github.com/WebKit/webkit/blob/master/Source/WebKit/UIProcess/API/Cocoa/WKWebViewPrivate.h
// https://github.com/WebKit/webkit/blob/master/Source/WebKit/UIProcess/Cocoa/WebViewImpl.h
// https://github.com/WebKit/webkit/blob/master/Source/WebCore/page/Settings.in

#ifdef STP
#import "_WKLayoutMode.h"
#endif

typedef NS_ENUM(NSInteger, _WKPaginationMode) {
    _WKPaginationModeUnpaginated,
    _WKPaginationModeLeftToRight,
    _WKPaginationModeRightToLeft,
    _WKPaginationModeTopToBottom,
    _WKPaginationModeBottomToTop,
} WK_API_AVAILABLE(macosx(10.10), ios(8.0));

typedef NS_ENUM(NSInteger, _WKImmediateActionType) {
    _WKImmediateActionNone,
    _WKImmediateActionLinkPreview,
    _WKImmediateActionDataDetectedItem,
    _WKImmediateActionLookupText,
    _WKImmediateActionMailtoLink,
    _WKImmediateActionTelLink
} WK_API_AVAILABLE(macosx(10.12));

typedef NS_OPTIONS(NSInteger, _WKMediaCaptureState) {
    _WKMediaCaptureStateNone = 0,
    _WKMediaCaptureStateActiveMicrophone = 1 << 0,
    _WKMediaCaptureStateActiveCamera = 1 << 1,
    _WKMediaCaptureStateMutedMicrophone = 1 << 2,
    _WKMediaCaptureStateMutedCamera = 1 << 3,
} WK_API_AVAILABLE(macosx(10.13), ios(11.0));

typedef NS_OPTIONS(NSInteger, _WKMediaMutedState) {
    _WKMediaNoneMuted = 0,
    _WKMediaAudioMuted = 1 << 0,
    _WKMediaCaptureDevicesMuted = 1 << 1,
} WK_API_AVAILABLE(macosx(10.13), ios(11.0));

typedef NS_OPTIONS(NSUInteger, _WKCaptureDevices) {
    _WKCaptureDeviceMicrophone = 1 << 0,
    _WKCaptureDeviceCamera = 1 << 1,
    _WKCaptureDeviceDisplay = 1 << 2,
} WK_API_AVAILABLE(macosx(10.13), ios(11.0));

#import "WKBrowsingContextHandle.h"
@class WKBrowsingContextHandle;

@class _WKIconLoadingDelegate;
@class _WKThumbnailView;

@protocol _WKFindDelegate;
@protocol _WKDiagnosticLoggingDelegate;
//@protocol _WKInputDelegate;
@protocol _WKIconLoadingDelegate;
@interface WKWebView (Privates)
@property (nonatomic, readonly) WKBrowsingContextHandle *_handle;
- (WKPageRef)_pageForTesting;
#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
//@property (nonatomic, readonly) _WKWebViewPrintFormatter *_webViewPrintFormatter;
//@property (nonatomic, getter=_allowsLinkPreview, setter=_setAllowsLinkPreview:) BOOL _allowsLinkPreview
@property (nonatomic, setter=_setBackgroundExtendsBeyondPage:) BOOL _backgroundExtendsBeyondPage;
- (UIView *)_viewForFindUI;
@property (nonatomic, readonly) CGFloat _viewportMetaTagWidth; // negative if tag undefined
@property (nonatomic, readonly) _WKWebViewPrintFormatter *_webViewPrintFormatter;
#else
@property (readonly) NSColor *_pageExtendedBackgroundColor;
@property (nonatomic, setter=_setTopContentInset:) CGFloat _topContentInset;
@property (nonatomic, setter=_setAutomaticallyAdjustsContentInsets:) BOOL _automaticallyAdjustsContentInsets;

@property (nonatomic, readonly) WKPageRef _pageRefForTransitionToWKWebView  WK_API_AVAILABLE(macosx(WK_MAC_TBA));
#endif

@property (nonatomic, setter=_setLayoutMode:) _WKLayoutMode _layoutMode;
@property (nonatomic, setter=_setViewScale:) CGFloat _viewScale;

#ifdef STP
@property (nonatomic, setter=_setDrawsBackground:) BOOL _drawsBackground;
@property (nonatomic, weak, setter=_setInputDelegate:) id <_WKInputDelegate> _inputDelegate WK2_AVAILABLE(WK_MAC_TBA, WK_IOS_TBA);
// https://github.com/WebKit/webkit/commit/0dfc67a174b79a8a401cf6f60c02150ba27334e5
- (NSPrintOperation *)_printOperationWithPrintInfo:(NSPrintInfo *)printInfo; // prints top frame
//- (NSPrintOperation *)_printOperationWithPrintInfo:(NSPrintInfo *)printInfo forFrame:(_WKFrameHandle *)frameHandle WK_AVAILABLE(WK_MAC_TBA, WK_IOS_TBA);
@property (strong, nonatomic, setter=_setInspectorAttachmentView:) NSView *_inspectorAttachmentView WK2_AVAILABLE(10_11, NA);

// TODO: make Status Bar from NSTrackingArea's tooltips
// https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/EventOverview/TrackingAreaObjects/TrackingAreaObjects.html#//apple_ref/doc/uid/10000060i-CH8-SW1
- (NSString *)view:(NSView *)view stringForToolTip:(NSToolTipTag)tag point:(NSPoint)point userData:(void *)data;
- (NSView *)documentContainerView;
#else
@property (nonatomic, setter=_setDrawsTransparentBackground:) BOOL _drawsTransparentBackground; //DEPRECATED: missing from STP builds!
#endif

-(void)_close;

@property (nonatomic, readonly) BOOL _networkRequestsInProgress;
@property (nonatomic, getter=_isEditable, setter=_setEditable:) BOOL _editable WK2_AVAILABLE(10_11, 9_0);
@property (nonatomic, setter=_setAddsVisitedLinks:) BOOL _addsVisitedLinks;
@property (nonatomic, setter=_setAllowsRemoteInspection:) BOOL _allowsRemoteInspection;
@property (nonatomic, copy, setter=_setRemoteInspectionNameOverride:) NSString *_remoteInspectionNameOverride WK2_AVAILABLE(WK_MAC_TBA, WK_IOS_TBA);
@property (copy, setter=_setCustomUserAgent:) NSString *_customUserAgent;
@property (copy, setter=_setApplicationNameForUserAgent:) NSString *_applicationNameForUserAgent;
@property (nonatomic, readonly) NSString *_userAgent;
@property (nonatomic, readonly) BOOL _supportsTextZoom;
@property (nonatomic, setter=_setTextZoomFactor:) double _textZoomFactor;
@property (nonatomic, setter=_setPageZoomFactor:) double _pageZoomFactor;
@property (nonatomic, readonly, getter=_isDisplayingStandaloneImageDocument) BOOL _displayingStandaloneImageDocument;
@property (nonatomic, setter=_setPaginationMode:) _WKPaginationMode _paginationMode;
@property (nonatomic, setter=_setPaginationBehavesLikeColumns:) BOOL _paginationBehavesLikeColumns;
@property (nonatomic, setter=_setPageLength:) CGFloat _pageLength;
@property (nonatomic, setter=_setGapBetweenPages:) CGFloat _gapBetweenPages;
- (void)_loadAlternateHTMLString:(NSString *)string baseURL:(NSURL *)baseURL forUnreachableURL:(NSURL *)unreachableURL;
- (void)_getMainResourceDataWithCompletionHandler:(void (^)(NSData *, NSError *))completionHandler;
- (void)_getWebArchiveDataWithCompletionHandler:(void (^)(NSData *, NSError *))completionHandler;
@property (nonatomic, readonly) NSURL *_unreachableURL;
@property (nonatomic, readonly) NSURL *_committedURL;
@property (nonatomic, readonly) NSString *_MIMEType;
@property (nonatomic, weak, setter=_setDiagnosticLoggingDelegate:) id <_WKDiagnosticLoggingDelegate> _diagnosticLoggingDelegate WK2_AVAILABLE(10_11, 9_0);
//https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/Cocoa/_WKFormDelegate.h
@property (nonatomic, weak, setter=_setFormDelegate:) id <_WKFormDelegate> _formDelegate;

@property (nonatomic, weak, setter=_setFindDelegate:) id <_WKFindDelegate> _findDelegate;
- (void)_findString:(NSString *)string options:(_WKFindOptions)options maxCount:(NSUInteger)maxCount;
- (void)_countStringMatches:(NSString *)string options:(_WKFindOptions)options maxCount:(NSUInteger)maxCount;
- (void)_hideFindUI;

// Icon delegate
// https://github.com/WebKit/webkit/commit/583510ef68c8aa56558c17263791b5cd8f762f99
@property (nonatomic, weak, setter=_setIconLoadingDelegate:) id <_WKIconLoadingDelegate> _iconLoadingDelegate;

// https://github.com/WebKit/webkit/commit/cabc571fb1a8b5d599592662d4823af181f5dab3#diff-8e23aa6fa7b7953093696656facbb583
@property (nonatomic, setter=_setThumbnailView:) _WKThumbnailView *_thumbnailView WK_API_AVAILABLE(macosx(WK_MAC_TBA));
@property (nonatomic, setter=_setIgnoresAllEvents:) BOOL _ignoresAllEvents WK_API_AVAILABLE(macosx(WK_MAC_TBA));

#if __MAC_OS_X_VERSION_MIN_REQUIRED >= 101200
#endif
@end

// https://github.com/WebKit/webkit/commit/1e291e88d96caa8e5421f81bd570e90b1af02ff4
#if !TARGET_OS_IPHONE
@interface WKWebView (WKNSTextFinderClient) <NSTextFinderClient>
@end

typedef enum : NSUInteger {
    NSTextFinderAsynchronousDocumentFindOptionsBackwards = 1 << 0,
    NSTextFinderAsynchronousDocumentFindOptionsWrap = 1 << 1,
    NSTextFinderAsynchronousDocumentFindOptionsCaseInsensitive = 1 << 2,
    NSTextFinderAsynchronousDocumentFindOptionsStartsWith = 1 << 3,
} NSTextFinderAsynchronousDocumentFindOptions;


@protocol NSTextFinderAsynchronousDocumentFindMatch <NSObject>
@property (retain, nonatomic, readonly) NSArray *textRects;
@end

@interface WKWebView (NSTextFinderSupport)
- (void)findMatchesForString:(NSString *)targetString relativeToMatch:(id <NSTextFinderAsynchronousDocumentFindMatch>)relativeMatch findOptions:(NSTextFinderAsynchronousDocumentFindOptions)findOptions maxResults:(NSUInteger)maxResults resultCollector:(void (^)(NSArray *matches, BOOL didWrap))resultCollector;
- (void)getSelectedText:(void (^)(NSString *selectedTextString))completionHandler;
- (void)selectFindMatch:(id <NSTextFinderAsynchronousDocumentFindMatch>)findMatch completionHandler:(void (^)(void))completionHandler;
@end
#endif

// CPU limit!!
// https://github.com/WebKit/webkit/commit/7cb2c970ac18d8ea58d95236ef6897feb7f7fb01#diff-8e23aa6fa7b7953093696656facbb583

// [WKWebView _pageRefForTransitionToWKWebView]
// https://github.com/WebKit/webkit/commit/77f18c8949dad58b43e81f35d1b861a0f28a0efa#diff-8e23aa6fa7b7953093696656facbb583

// moar from WebViewImpl !!
// https://github.com/WebKit/webkit/commit/cfe92b4e265636c1396c7c7ed188cc51b78582ca#diff-8e23aa6fa7b7953093696656facbb583
// https://github.com/WebKit/webkit/commit/dcb4f6fd0815005282c92da91b5f26b12083821d#diff-8e23aa6fa7b7953093696656facbb583
