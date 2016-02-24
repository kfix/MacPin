// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/C/WKPage.h
#import "WKBase.h"
#import "WKInspector.h"
WK_EXPORT WKInspectorRef WKPageGetInspector(WKPageRef page);
