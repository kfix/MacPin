@import WebKit;
// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/Cocoa/WKWebViewPrivate.h
@interface WKWebView (Privates)
@property (readonly) NSColor *_pageExtendedBackgroundColor;
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
//- (WKNavigation *)loadFileURL:(NSURL *)URL allowingReadAccessToURL:(NSURL *)readAccessURL;
@end
