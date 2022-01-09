// https://github.com/WebKit/webkit/blob/main/Source/WebKit/UIProcess/API/Cocoa/WKWebViewPrivate.h
// https://github.com/WebKit/webkit/blob/main/Source/WebKit/UIProcess/Cocoa/WebViewImpl.h
// https://github.com/WebKit/webkit/blob/main/Source/WebCore/page/Settings.yaml

#import "./WebKitAvailability.h"
#import "_WKLayoutMode.h"
#import "_WKFindDelegate.h"
#import "_WKFindOptions.h"
#import "_WKInputDelegate.h"
#import "_WKAttachment.h"
#import "NSTextFinderSPI.h"

typedef NS_ENUM(NSInteger, _WKPaginationMode) {
    _WKPaginationModeUnpaginated,
    _WKPaginationModeLeftToRight,
    _WKPaginationModeRightToLeft,
    _WKPaginationModeTopToBottom,
    _WKPaginationModeBottomToTop,
} WK_API_AVAILABLE(macos(10.10), ios(8.0));

typedef NS_ENUM(NSInteger, _WKImmediateActionType) {
    _WKImmediateActionNone,
    _WKImmediateActionLinkPreview,
    _WKImmediateActionDataDetectedItem,
    _WKImmediateActionLookupText,
    _WKImmediateActionMailtoLink,
    _WKImmediateActionTelLink
} WK_API_AVAILABLE(macos(10.12));

typedef NS_OPTIONS(NSInteger, _WKMediaMutedState) {
    _WKMediaNoneMuted = 0,
    _WKMediaAudioMuted = 1 << 0,
    _WKMediaCaptureDevicesMuted = 1 << 1,
} WK_API_AVAILABLE(macos(10.13), ios(11.0));

#import "WKBrowsingContextHandle.h"
@class WKBrowsingContextHandle;
@class _WKApplicationManifest;
@class _WKIconLoadingDelegate;
@class _WKThumbnailView;
@class _WKFrameHandle;
@class _WKInspector;
@class _WKWebViewPrintFormatter;

@protocol _WKDiagnosticLoggingDelegate;
@protocol _WKInputDelegate;
@protocol WKHistoryDelegatePrivate;
@protocol _WKIconLoadingDelegate;

@interface WKWebView (Privates)

@property (nonatomic, readonly) WKBrowsingContextHandle *_handle;

- (WKPageRef)_pageForTesting;

#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
//@property (nonatomic, getter=_allowsLinkPreview, setter=_setAllowsLinkPreview:) BOOL _allowsLinkPreview
- (UIView *)_viewForFindUI;
@property (nonatomic, readonly) CGFloat _viewportMetaTagWidth; // negative if tag undefined
@property (nonatomic, readonly) _WKWebViewPrintFormatter *_webViewPrintFormatter;
#else
@property (readonly) NSColor *_pageExtendedBackgroundColor;
@property (nonatomic, setter=_setTopContentInset:) CGFloat _topContentInset;
@property (nonatomic, setter=_setAutomaticallyAdjustsContentInsets:) BOOL _automaticallyAdjustsContentInsets;

- (void)_setFrame:(NSRect)rect andScrollBy:(NSSize)offset WK_API_AVAILABLE(macos(10.13.4));

- (void)_gestureEventWasNotHandledByWebCore:(NSEvent *)event WK_API_AVAILABLE(macos(10.13.4));
- (void)_setCustomSwipeViews:(NSArray *)customSwipeViews WK_API_AVAILABLE(macos(10.13.4));
- (void)_setCustomSwipeViewsTopContentInset:(float)topContentInset WK_API_AVAILABLE(macos(10.13.4));
- (NSView *)_fullScreenPlaceholderView WK_API_AVAILABLE(macos(10.13.4));
- (NSWindow *)_fullScreenWindow WK_API_AVAILABLE(macos(10.13.4));

@property (nonatomic, readonly) BOOL _hasActiveVideoForControlsManager WK_API_AVAILABLE(macos(10.12));
- (void)_requestControlledElementID WK_API_AVAILABLE(macos(10.12.3));
- (void)_handleControlledElementIDResponse:(NSString *)identifier WK_API_AVAILABLE(macos(10.12.3));
- (void)_handleAcceptedCandidate:(NSTextCheckingResult *)candidate WK_API_AVAILABLE(macos(10.12.3));
- (void)_didHandleAcceptedCandidate WK_API_AVAILABLE(macos(10.12.3));
- (void)_forceRequestCandidates WK_API_AVAILABLE(macos(10.12.3));
- (void)_didUpdateCandidateListVisibility:(BOOL)visible WK_API_AVAILABLE(macos(10.12.3));
@property (nonatomic, readonly) BOOL _shouldRequestCandidates WK_API_AVAILABLE(macos(10.12.3));
- (void)_insertText:(id)string replacementRange:(NSRange)replacementRange WK_API_AVAILABLE(macos(10.12.3));
- (NSRect)_candidateRect WK_API_AVAILABLE(macos(10.13));
@property (nonatomic, readwrite, setter=_setUseSystemAppearance:) BOOL _useSystemAppearance WK_API_AVAILABLE(macos(10.14));
@property (nonatomic, readonly) NSMenu *_activeMenu WK_API_AVAILABLE(macos(WK_MAC_TBA));

- (void)_setHeaderBannerHeight:(int)height WK_API_AVAILABLE(macos(10.12.3));
- (void)_setFooterBannerHeight:(int)height WK_API_AVAILABLE(macos(10.12.3));
- (void)_doAfterProcessingAllPendingMouseEvents:(dispatch_block_t)action WK_API_AVAILABLE(macos(10.14.4));

// TODO: make Status Bar from NSTrackingArea's tooltips
// https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/EventOverview/TrackingAreaObjects/TrackingAreaObjects.html#//apple_ref/doc/uid/10000060i-CH8-SW1
- (NSString *)view:(NSView *)view stringForToolTip:(NSToolTipTag)tag point:(NSPoint)point userData:(void *)data;
- (NSView *)documentContainerView;
#endif

@property (nonatomic, setter=_setLayoutMode:) _WKLayoutMode _layoutMode;
@property (nonatomic, setter=_setViewScale:) CGFloat _viewScale;

@property (nonatomic, setter=_setMinimumEffectiveDeviceWidth:) CGFloat _minimumEffectiveDeviceWidth WK_API_AVAILABLE(macos(10.14.4), ios(12.2));

@property (nonatomic, setter=_setBackgroundExtendsBeyondPage:) BOOL _backgroundExtendsBeyondPage WK_API_AVAILABLE(macos(10.13.4), ios(8.0));

- (_WKAttachment *)_insertAttachmentWithFilename:(NSString *)filename contentType:(NSString *)contentType data:(NSData *)data options:(_WKAttachmentDisplayOptions *)options completion:(void(^)(BOOL success))completionHandler WK_API_DEPRECATED_WITH_REPLACEMENT("-_insertAttachmentWithFileWrapper:contentType:options:completion:", macos(10.13.4, 10.14.4), ios(11.3, 12.2));
- (_WKAttachment *)_insertAttachmentWithFileWrapper:(NSFileWrapper *)fileWrapper contentType:(NSString *)contentType options:(_WKAttachmentDisplayOptions *)options completion:(void(^)(BOOL success))completionHandler WK_API_DEPRECATED_WITH_REPLACEMENT("-_insertAttachmentWithFileWrapper:contentType:completion:", macos(10.14.4, 10.14.4), ios(12.2, 12.2));
- (_WKAttachment *)_insertAttachmentWithFileWrapper:(NSFileWrapper *)fileWrapper contentType:(NSString *)contentType completion:(void(^)(BOOL success))completionHandler WK_API_AVAILABLE(macos(10.14.4), ios(12.2));
- (_WKAttachment *)_attachmentForIdentifier:(NSString *)identifier WK_API_AVAILABLE(macos(10.14.4), ios(12.2));

- (void)_simulateDeviceOrientationChangeWithAlpha:(double)alpha beta:(double)beta gamma:(double)gamma WK_API_AVAILABLE(macos(10.14.4), ios(12.2));

+ (BOOL)_handlesSafeBrowsing WK_API_AVAILABLE(macos(10.14.4), ios(12.2));
+ (NSURL *)_confirmMalwareSentinel WK_API_AVAILABLE(macos(10.14.4), ios(12.2));
+ (NSURL *)_visitUnsafeWebsiteSentinel WK_API_AVAILABLE(macos(10.14.4), ios(12.2));
- (void)_showSafeBrowsingWarningWithTitle:(NSString *)title warning:(NSString *)warning details:(NSAttributedString *)details completionHandler:(void(^)(BOOL))completionHandler WK_API_AVAILABLE(macos(10.14.4), ios(12.2));
- (void)_showSafeBrowsingWarningWithURL:(NSURL *)url title:(NSString *)title warning:(NSString *)warning details:(NSAttributedString *)details completionHandler:(void(^)(BOOL))completionHandler WK_API_AVAILABLE(macos(10.14.4), ios(12.2));

- (void)_isJITEnabled:(void(^)(BOOL))completionHandler WK_API_AVAILABLE(macos(10.14.4), ios(12.2));
- (void)_removeDataDetectedLinks:(dispatch_block_t)completion WK_API_AVAILABLE(macos(10.14.4), ios(12.2));

- (IBAction)_alignCenter:(id)sender WK_API_AVAILABLE(macos(10.14.4), ios(12.2));
- (IBAction)_alignJustified:(id)sender WK_API_AVAILABLE(macos(10.14.4), ios(12.2));
- (IBAction)_alignLeft:(id)sender WK_API_AVAILABLE(macos(10.14.4), ios(12.2));
- (IBAction)_alignRight:(id)sender WK_API_AVAILABLE(macos(10.14.4), ios(12.2));
- (IBAction)_indent:(id)sender WK_API_AVAILABLE(macos(10.14.4), ios(12.2));
- (IBAction)_outdent:(id)sender WK_API_AVAILABLE(macos(10.14.4), ios(12.2));
- (IBAction)_toggleStrikeThrough:(id)sender WK_API_AVAILABLE(macos(10.14.4), ios(12.2));
- (IBAction)_insertOrderedList:(id)sender WK_API_AVAILABLE(macos(10.14.4), ios(12.2));
- (IBAction)_insertUnorderedList:(id)sender WK_API_AVAILABLE(macos(10.14.4), ios(12.2));
- (IBAction)_insertNestedOrderedList:(id)sender WK_API_AVAILABLE(macos(10.14.4), ios(12.2));
- (IBAction)_insertNestedUnorderedList:(id)sender WK_API_AVAILABLE(macos(10.14.4), ios(12.2));
- (IBAction)_increaseListLevel:(id)sender WK_API_AVAILABLE(macos(10.14.4), ios(12.2));
- (IBAction)_decreaseListLevel:(id)sender WK_API_AVAILABLE(macos(10.14.4), ios(12.2));
- (IBAction)_changeListType:(id)sender WK_API_AVAILABLE(macos(10.14.4), ios(12.2));
- (IBAction)_pasteAsQuotation:(id)sender WK_API_AVAILABLE(macos(10.14.4), ios(12.2));
- (IBAction)_pasteAndMatchStyle:(id)sender WK_API_AVAILABLE(macos(10.14.4), ios(12.2));
- (IBAction)_takeFindStringFromSelection:(id)sender WK_API_AVAILABLE(macos(10.14.4), ios(12.2));

 @property (class, nonatomic, copy, setter=_setStringForFind:) NSString *_stringForFind WK_API_AVAILABLE(macos(10.14.4), ios(12.2));

// hard-renamed to ^background in 11/2015. only pre-macOS with no STP will respond to ^transparentBackground.
// https://github.com/WebKit/webkit/commit/6cbd5051e809407615b2fd903dacc8c14bbd69eb =>
// https://trac.webkit.org/browser/webkit/tags/Safari-602.1.11/Source/WebKit2/ChangeLog
@property (nonatomic, setter=_setDrawsBackground:) BOOL _drawsBackground WK_API_AVAILABLE(macos(10.12), ios(10.0));
@property (nonatomic, setter=_setDrawsTransparentBackground:) BOOL _drawsTransparentBackground; // DEPRECATED!

-(void)_close;

@property (nonatomic, readonly) BOOL _networkRequestsInProgress;
@property (nonatomic, getter=_isEditable, setter=_setEditable:) BOOL _editable WK_API_AVAILABLE(macos(10.11), ios(9.0));
@property (nonatomic, setter=_setAddsVisitedLinks:) BOOL _addsVisitedLinks;
@property (nonatomic, setter=_setAllowsRemoteInspection:) BOOL _allowsRemoteInspection;
@property (nonatomic, copy, setter=_setRemoteInspectionNameOverride:) NSString *_remoteInspectionNameOverride WK_API_AVAILABLE(macos(10.12), ios(10.0));
@property (copy, setter=_setCustomUserAgent:) NSString *_customUserAgent;
@property (copy, setter=_setApplicationNameForUserAgent:) NSString *_applicationNameForUserAgent;
@property (nonatomic, readonly) NSString *_userAgent WK_API_AVAILABLE(macos(10.11), ios(9.0));
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
- (void)_getContentsAsStringWithCompletionHandler:(void (^)(NSString *, NSError *))completionHandler WK_API_AVAILABLE(macos(10.13), ios(11.0));
- (void)_getApplicationManifestWithCompletionHandler:(void (^)(_WKApplicationManifest *))completionHandler WK_API_AVAILABLE(macos(WK_MAC_TBA), ios(WK_IOS_TBA));
@property (nonatomic, readonly) NSURL *_unreachableURL;
@property (nonatomic, readonly) NSURL *_committedURL;
@property (nonatomic, readonly) NSString *_MIMEType;

@property (nonatomic, weak, setter=_setDiagnosticLoggingDelegate:) id <_WKDiagnosticLoggingDelegate> _diagnosticLoggingDelegate WK_API_AVAILABLE(macos(10.11), ios(9.0));

@property (nonatomic, weak, setter=_setFindDelegate:) id <_WKFindDelegate> _findDelegate;
- (void)_findString:(NSString *)string options:(_WKFindOptions)options maxCount:(NSUInteger)maxCount;
- (void)_countStringMatches:(NSString *)string options:(_WKFindOptions)options maxCount:(NSUInteger)maxCount;
- (void)_hideFindUI;

@property (nonatomic, weak, setter=_setInputDelegate:) id <_WKInputDelegate> _inputDelegate WK_API_AVAILABLE(macos(10.12), ios(10.0));

@property (nonatomic, weak, setter=_setHistoryDelegate:) id <WKHistoryDelegatePrivate> _historyDelegate;

// Icon delegate https://github.com/WebKit/webkit/commit/583510ef68c8aa56558c17263791b5cd8f762f99
@property (nonatomic, weak, setter=_setIconLoadingDelegate:) id <_WKIconLoadingDelegate> _iconLoadingDelegate;

@property (strong, nonatomic, setter=_setInspectorAttachmentView:) NSView *_inspectorAttachmentView WK_API_AVAILABLE(macos(10.13.4));

// https://github.com/WebKit/webkit/commit/cabc571fb1a8b5d599592662d4823af181f5dab3#diff-8e23aa6fa7b7953093696656facbb583
@property (nonatomic, setter=_setThumbnailView:) _WKThumbnailView *_thumbnailView WK_API_AVAILABLE(macos(10.13.4));
@property (nonatomic, setter=_setIgnoresAllEvents:) BOOL _ignoresAllEvents WK_API_AVAILABLE(macos(10.13.4));

// Defaults to YES; if set to NO, WebKit will draw the grey wash and highlights itself.
@property (nonatomic, setter=_setUsePlatformFindUI:) BOOL _usePlatformFindUI WK_API_AVAILABLE(macos(10.15));

@property (nonatomic, setter=_setScrollPerformanceDataCollectionEnabled:) BOOL _scrollPerformanceDataCollectionEnabled WK_API_AVAILABLE(macos(10.11), ios(9.0));
@property (nonatomic, readonly) NSArray *_scrollPerformanceData WK_API_AVAILABLE(macos(10.11), ios(9.0));

- (void)_saveBackForwardSnapshotForItem:(WKBackForwardListItem *)item WK_API_AVAILABLE(macos(10.11), ios(9.0));

@property (nonatomic, getter=_allowsMediaDocumentInlinePlayback, setter=_setAllowsMediaDocumentInlinePlayback:) BOOL _allowsMediaDocumentInlinePlayback;

@property (nonatomic, readonly) BOOL _webProcessIsResponsive WK_API_AVAILABLE(macos(10.12), ios(10.0));

//@property (nonatomic, setter=_setFullscreenDelegate:) id<_WKFullscreenDelegate> _fullscreenDelegate WK_API_AVAILABLE(macos(10.13), ios(11.0));
@property (nonatomic, readonly) BOOL _isInFullscreen WK_API_AVAILABLE(macos(10.12.3));

- (void)_muteMediaCapture WK_API_AVAILABLE(macos(10.13), ios(11.0));
- (void)_setPageMuted:(_WKMediaMutedState)mutedState WK_API_AVAILABLE(macos(10.13), ios(11.0));

@property (nonatomic, setter=_setMediaCaptureEnabled:) BOOL _mediaCaptureEnabled WK_API_AVAILABLE(macos(10.13), ios(11.0));

#if !TARGET_OS_IPHONE
@property (nonatomic, readonly) BOOL _hasInspectorFrontend WK_API_AVAILABLE(macos(10.14.4), ios(12.2));
@property (nonatomic, readonly) _WKInspector *_inspector WK_API_AVAILABLE(macos(10.14.4), ios(12.2));
@property (nonatomic, readonly) _WKFrameHandle *_mainFrame WK_API_AVAILABLE(macos(10.14.4), ios(12.2));
- (void)_dismissContentRelativeChildWindows WK_API_AVAILABLE(macos(WK_MAC_TBA));
- (void)_setFrame:(NSRect)rect andScrollBy:(NSSize)offset WK_API_AVAILABLE(macos(WK_MAC_TBA));
- (void)_beginDeferringViewInWindowChanges WK_API_AVAILABLE(macos(WK_MAC_TBA));
- (void)_endDeferringViewInWindowChanges WK_API_AVAILABLE(macos(WK_MAC_TBA));
- (void)_endDeferringViewInWindowChangesSync WK_API_AVAILABLE(macos(WK_MAC_TBA));
- (void)_gestureEventWasNotHandledByWebCore:(NSEvent *)event WK_API_AVAILABLE(macos(WK_MAC_TBA));
- (void)_setCustomSwipeViews:(NSArray *)customSwipeViews WK_API_AVAILABLE(macos(WK_MAC_TBA));
- (void)_setCustomSwipeViewsTopContentInset:(float)topContentInset WK_API_AVAILABLE(macos(WK_MAC_TBA));
- (NSView *)_fullScreenPlaceholderView WK_API_AVAILABLE(macos(WK_MAC_TBA));
- (NSWindow *)_fullScreenWindow WK_API_AVAILABLE(macos(WK_MAC_TBA));
- (void)_disableFrameSizeUpdates WK_API_AVAILABLE(macos(WK_MAC_TBA));
- (void)_enableFrameSizeUpdates WK_API_AVAILABLE(macos(WK_MAC_TBA));
- (void)_prepareForImmediateActionAnimation WK_API_AVAILABLE(macos(WK_MAC_TBA));
- (void)_cancelImmediateActionAnimation WK_API_AVAILABLE(macos(WK_MAC_TBA));
- (void)_completeImmediateActionAnimation WK_API_AVAILABLE(macos(WK_MAC_TBA));
- (BOOL)_canChangeFrameLayout:(_WKFrameHandle *)frameHandle WK_API_AVAILABLE(macos(WK_MAC_TBA));
- (BOOL)_tryToSwipeWithEvent:(NSEvent *)event ignoringPinnedState:(BOOL)ignoringPinnedState WK_API_AVAILABLE(macos(WK_MAC_TBA));
- (void)_setDidMoveSwipeSnapshotCallback:(void(^)(CGRect))callback WK_API_AVAILABLE(macos(WK_MAC_TBA));
@property (nonatomic, setter=_setTotalHeightOfBanners:) CGFloat _totalHeightOfBanners WK_API_AVAILABLE(macos(WK_MAC_TBA));
@property (nonatomic, copy, setter=_setUnderlayColor:) NSColor *_underlayColor;
@property (nonatomic, readwrite, setter=_setIgnoresNonWheelEvents:) BOOL _ignoresNonWheelEvents WK_API_AVAILABLE(macos(WK_MAC_TBA));
@property (nonatomic, readonly) WKPageRef _pageRefForTransitionToWKWebView WK_API_AVAILABLE(macos(10.13.4));
- (NSPrintOperation *)_printOperationWithPrintInfo:(NSPrintInfo *)printInfo; // prints top frame
- (NSPrintOperation *)_printOperationWithPrintInfo:(NSPrintInfo *)printInfo forFrame:(_WKFrameHandle *)frameHandle WK_API_AVAILABLE(macos(10.12));
#endif

// not really declared but _seems to work_ (lots of magic)
// https://github.com/WebKit/WebKit/commit/192986a334eea1f7194f8a1d336547422c83d08f
// https://github.com/WebKit/WebKit/commit/4eb014db577c56d4184fdbba7c2f4816e6de5fcf
// https://github.com/llvm/llvm-project/commit/d4e1ba3fa9dfec2613bdcc7db0b58dea490c56b1
// https://reviews.llvm.org/D69991
//@property (nonatomic, readonly) WKPageRef *_page __attribute__((objc_direct)) WK_API_AVAILABLE(macos(10.14.4), ios(12.2));

@property (nonatomic, readonly) NSView *_safeBrowsingWarning WK_API_AVAILABLE(macos(10.14.4), ios(12.2));
@end

// https://github.com/WebKit/webkit/commit/1e291e88d96caa8e5421f81bd570e90b1af02ff4
#if TARGET_OS_OSX
@interface WKWebView (WKNSTextFinderClient) <NSTextFinderClient>
@end

@interface WKTextFinderMatch : NSObject <NSTextFinderAsynchronousDocumentFindMatch>
@property (nonatomic, readonly) unsigned index;
@end

@interface WKWebView (NSTextFinderSupport)
- (void)findMatchesForString:(NSString *)targetString relativeToMatch:(id <NSTextFinderAsynchronousDocumentFindMatch>)relativeMatch findOptions:(NSTextFinderAsynchronousDocumentFindOptions)findOptions maxResults:(NSUInteger)maxResults resultCollector:(void (^)(NSArray *matches, BOOL didWrap))resultCollector;
- (void)getSelectedText:(void (^)(NSString *selectedTextString))completionHandler;
- (void)selectFindMatch:(id <NSTextFinderAsynchronousDocumentFindMatch>)findMatch completionHandler:(void (^)(void))completionHandler;
@end
#endif
