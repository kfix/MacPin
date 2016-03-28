// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/C/WKPage.h
#import "WKBase.h"
#import "WKInspector.h"
WK_EXPORT WKInspectorRef WKPageGetInspector(WKPageRef page);
WK_EXPORT WKContextRef WKPageGetContext(WKPageRef page);
WK_EXPORT WKPageGroupRef WKPageGetPageGroup(WKPageRef page);
WK_EXPORT WKPageConfigurationRef WKPageCopyPageConfiguration(WKPageRef page);

typedef void (*WKPageForceRepaintFunction)(WKErrorRef, void*);
WK_EXPORT void WKPageForceRepaint(WKPageRef page, void* context, WKPageForceRepaintFunction function);
