@import WebKit;
#import "WebKitPrivates.h"
@import std;

#if !TARGET_OS_IPHONE && !TARGET_IPHONE_SIMULATOR && !TARGET_OS_SIMULATOR
@implementation WKWebViewSnappable
std::unique_ptr<WebKit::WebViewImpl> _impl; // https://github.com/WebKit/webkit/blob/03aae442c5f9a1e32ff96abf4e2595b4a5d8a44c/Source/WebKit2/UIProcess/API/Cocoa/WKWebView.mm#L264

-(_WKThumbnailView *) _thumbnailView { // https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/mac/WKView.mm#L859
	NSLog(@"boom goes the dynamite");
	//return _impl->m_thumbnailView;
	return _impl->thumbnailView();
}
/* SIGSEGV ;-(
0   MacPin                        	0x000000010c590ecc WebKit::WebViewImpl::thumbnailView() const + 12
1   MacPin                        	0x000000010c590bef -[WKWebViewSnappable _thumbnailView] + 79
2   MacPin                        	0x000000010c520379 _TFC6MacPin9MPWebViewg9thumbnailGSqCSo16_WKThumbnailView_ + 41 (WebView.swift:119)
3   MacPin                        	0x000000010c563a86 _TFC6MacPin20WebViewControllerOSX21snapshotButtonClickedfGSqPs9AnyObject__T_ + 198 (WebViewControllerOSX.swift:157)
*/

/*
-(void) _setThumbnailView:(_WKThumbnailView *)thumbnail {
	_impl->setThumbnailView(thumbnail);
	// https://github.com/WebKit/webkit/blob/152410da081c1a638a3c2b8c0f55b5e726fffd15/Source/WebKit2/UIProcess/Cocoa/WebViewImpl.mm#L2708
}
*/
@end
#endif
