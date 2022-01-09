// https://github.com/WebKit/webkit/blob/main/Source/WebKit/UIProcess/API/C/WKPage.h
#import "WKBase.h"
#import "WKInspector.h"
#import "WKPageUIClient.h"

WK_EXPORT WKInspectorRef WKPageGetInspector(WKPageRef page);
WK_EXPORT WKContextRef WKPageGetContext(WKPageRef page);
WK_EXPORT WKPageGroupRef WKPageGetPageGroup(WKPageRef page);
WK_EXPORT WKPageConfigurationRef WKPageCopyPageConfiguration(WKPageRef page);

typedef void (*WKPageForceRepaintFunction)(WKErrorRef, void*);
WK_EXPORT void WKPageForceRepaint(WKPageRef page, void* context, WKPageForceRepaintFunction function);

WK_EXPORT void WKPageTerminate(WKPageRef page);
WK_EXPORT WKFrameRef WKPageGetMainFrame(WKPageRef page);
WK_EXPORT WKFrameRef WKPageGetFocusedFrame(WKPageRef page); // The focused frame may be inactive.
WK_EXPORT bool WKPageTryClose(WKPageRef page);
WK_EXPORT bool WKPageClose(WKPageRef page);
WK_EXPORT bool WKPageIsClosed(WKPageRef page);
WK_EXPORT void WKPageReloadWithoutContentBlockers(WKPageRef page);

WK_EXPORT void WKPageSetPageUIClient(WKPageRef page, const WKPageUIClientBase* client);
//WK_EXPORT void WKPageSetPageInjectedBundleClient(WKPageRef page, const WKPageInjectedBundleClientBase* client);

WK_EXPORT WKStringRef WKPageCopyTitle(WKPageRef page);

WK_EXPORT WKURLRef WKPageCopyPendingAPIRequestURL(WKPageRef page);

WK_EXPORT WKURLRef WKPageCopyActiveURL(WKPageRef page);
WK_EXPORT WKURLRef WKPageCopyProvisionalURL(WKPageRef page);
WK_EXPORT WKURLRef WKPageCopyCommittedURL(WKPageRef page);

WK_EXPORT void WKPageSetUserContentExtensionsEnabled(WKPageRef, bool);
  
WK_EXPORT void WKPageTryRestoreScrollPosition(WKPageRef page);

typedef bool (*WKPageSessionStateFilterCallback)(WKPageRef page, WKStringRef valueType, WKTypeRef value, void* context);

// FIXME: This should return a WKSessionStateRef object, not a WKTypeRef.
// It currently returns a WKTypeRef for backwards compatibility with Safari.
WK_EXPORT WKTypeRef WKPageCopySessionState(WKPageRef page, void* context, WKPageSessionStateFilterCallback urlAllowedCallback);

// FIXME: This should take a WKSessionStateRef object, not a WKTypeRef.
// It currently takes a WKTypeRef for backwards compatibility with Safari.
WK_EXPORT void WKPageRestoreFromSessionState(WKPageRef page, WKTypeRef sessionState);

// This API is poorly named. Even when these values are set to false, rubber-banding will
// still be allowed to occur at the end of a momentum scroll. These values are used along
// with pin state to determine if wheel events should be handled in the web process or if
// they should be passed up to the client.
WK_EXPORT bool WKPageRubberBandsAtLeft(WKPageRef);
WK_EXPORT void WKPageSetRubberBandsAtLeft(WKPageRef, bool rubberBandsAtLeft);
WK_EXPORT bool WKPageRubberBandsAtRight(WKPageRef);
WK_EXPORT void WKPageSetRubberBandsAtRight(WKPageRef, bool rubberBandsAtRight);
WK_EXPORT bool WKPageRubberBandsAtTop(WKPageRef);
WK_EXPORT void WKPageSetRubberBandsAtTop(WKPageRef, bool rubberBandsAtTop);
WK_EXPORT bool WKPageRubberBandsAtBottom(WKPageRef);
WK_EXPORT void WKPageSetRubberBandsAtBottom(WKPageRef, bool rubberBandsAtBottom);
    
// Rubber-banding is enabled by default.
WK_EXPORT bool WKPageVerticalRubberBandingIsEnabled(WKPageRef);
WK_EXPORT void WKPageSetEnableVerticalRubberBanding(WKPageRef, bool enableVerticalRubberBanding);
WK_EXPORT bool WKPageHorizontalRubberBandingIsEnabled(WKPageRef);
WK_EXPORT void WKPageSetEnableHorizontalRubberBanding(WKPageRef, bool enableHorizontalRubberBanding);
    
WK_EXPORT void WKPageSetBackgroundExtendsBeyondPage(WKPageRef, bool backgroundExtendsBeyondPage);
WK_EXPORT bool WKPageBackgroundExtendsBeyondPage(WKPageRef);

// https://github.com/WebKit/webkit/blob/main/Source/WebKit/UIProcess/API/C/WKPagePrivate.h
WK_EXPORT void WKPageLoadURLWithShouldOpenExternalURLsPolicy(WKPageRef page, WKURLRef url, bool shouldOpenExternalURLs);
WK_EXPORT bool WKPageGetAddsVisitedLinks(WKPageRef page);
WK_EXPORT void WKPageSetAddsVisitedLinks(WKPageRef page, bool visitedLinks);

// https://github.com/WebKit/webkit/blob/main/Source/WebKit/UIProcess/API/C/mac/WKPagePrivateMac.h
WK_EXPORT bool WKPageIsURLKnownHSTSHost(WKPageRef page, WKURLRef url);
#if !TARGET_OS_IPHONE
WK_EXPORT bool WKPageIsPlayingVideoInEnhancedFullscreen(WKPageRef page);
#endif
