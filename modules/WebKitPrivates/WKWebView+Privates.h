@import WebKit;
// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/Cocoa/WKWebViewPrivate.h

typedef NS_ENUM(NSInteger, _WKPaginationMode) {
    _WKPaginationModeUnpaginated,
    _WKPaginationModeLeftToRight,
    _WKPaginationModeRightToLeft,
    _WKPaginationModeTopToBottom,
    _WKPaginationModeBottomToTop,
}; 

@interface WKWebView (Privates)

//@property (readonly) NSColor *_pageExtendedBackgroundColor;

@property (nonatomic, setter=_setDrawsTransparentBackground:) BOOL _drawsTransparentBackground;
@property (nonatomic, setter=_setTopContentInset:) CGFloat _topContentInset;
@property (nonatomic, setter=_setAutomaticallyAdjustsContentInsets:) BOOL _automaticallyAdjustsContentInsets;
@property (nonatomic, setter=_setAllowsRemoteInspection:) BOOL _allowsRemoteInspection;
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
//- (WKNavigation *)loadFileURL:(NSURL *)URL allowingReadAccessToURL:(NSURL *)readAccessURL; //hasn't landed in 10.10.2 WebKit.framework
- (void)_loadAlternateHTMLString:(NSString *)string baseURL:(NSURL *)baseURL forUnreachableURL:(NSURL *)unreachableURL;
- (void)_getMainResourceDataWithCompletionHandler:(void (^)(NSData *, NSError *))completionHandler;
- (void)_getWebArchiveDataWithCompletionHandler:(void (^)(NSData *, NSError *))completionHandler;
@property (nonatomic, readonly) NSURL *_unreachableURL;
@property (nonatomic, readonly) NSURL *_committedURL;
@property (nonatomic, readonly) NSString *_MIMEType;
@end
