// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/C/WKPage.h
#import "WKBase.h"
#import "WKInspector.h"
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


// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/C/WKPagePrivate.h
WK_EXPORT void WKPageLoadURLWithShouldOpenExternalURLsPolicy(WKPageRef page, WKURLRef url, bool shouldOpenExternalURLs);
WK_EXPORT bool WKPageGetResourceCachingDisabled(WKPageRef page);
WK_EXPORT void WKPageSetResourceCachingDisabled(WKPageRef page, bool disabled);
WK_EXPORT bool WKPageGetAddsVisitedLinks(WKPageRef page);
WK_EXPORT void WKPageSetAddsVisitedLinks(WKPageRef page, bool visitedLinks);
