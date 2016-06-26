// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/Cocoa/WebViewImpl.h
// WebViewImplDelegate
//
#if !TARGET_OS_IPHONE && !TARGET_IPHONE_SIMULATOR && !TARGET_OS_SIMULATOR

// Compiler.h
/* OBJC_CLASS */
#if !defined(OBJC_CLASS) && defined(__OBJC__)
#define OBJC_CLASS @class
#endif

OBJC_CLASS NSImmediateActionGestureRecognizer;
OBJC_CLASS NSTextInputContext;
OBJC_CLASS NSView;
OBJC_CLASS WKBrowsingContextController;
OBJC_CLASS WKEditorUndoTargetObjC;
OBJC_CLASS WKFullScreenWindowController;
OBJC_CLASS WKImmediateActionController;
OBJC_CLASS WKViewLayoutStrategy;
OBJC_CLASS WKWebView;
OBJC_CLASS WKWindowVisibilityObserver;
OBJC_CLASS _WKThumbnailView;

@protocol WebViewImplDelegate

- (NSTextInputContext *)_web_superInputContext;
- (void)_web_superQuickLookWithEvent:(NSEvent *)event;
- (void)_web_superRemoveTrackingRect:(NSTrackingRectTag)tag;
- (void)_web_superSwipeWithEvent:(NSEvent *)event;
- (void)_web_superMagnifyWithEvent:(NSEvent *)event;
- (void)_web_superSmartMagnifyWithEvent:(NSEvent *)event;
- (id)_web_superAccessibilityAttributeValue:(NSString *)attribute;
- (void)_web_superDoCommandBySelector:(SEL)selector;
- (BOOL)_web_superPerformKeyEquivalent:(NSEvent *)event;
- (void)_web_superKeyDown:(NSEvent *)event;
- (NSView *)_web_superHitTest:(NSPoint)point;

//- (id)_web_immediateActionAnimationControllerForHitTestResultInternal:(API::HitTestResult*)hitTestResult withType:(uint32_t)type userData:(API::Object*)userData;
- (void)_web_prepareForImmediateActionAnimation;
- (void)_web_cancelImmediateActionAnimation;
- (void)_web_completeImmediateActionAnimation;

- (void)_web_dismissContentRelativeChildWindows;
- (void)_web_dismissContentRelativeChildWindowsWithAnimation:(BOOL)animate;

- (void)_web_gestureEventWasNotHandledByWebCore:(NSEvent *)event;

- (void)_web_didChangeContentSize:(NSSize)newSize;

@optional
- (void)_web_didAddMediaControlsManager:(id)controlsManager;
- (void)_web_didRemoveMediaControlsManager;
@end

@interface WKWebView (ImplDel) <WebViewImplDelegate, NSTextInputClient>
@end

#ifdef __cplusplus
// http://stackoverflow.com/questions/32541268/can-i-have-swift-objective-c-c-and-c-files-in-the-same-xcode-project/32546879#32546879
// http://www.pierre.chachatelier.fr/programmation/fichiers/cpp-objc-en.pdf
@import std;
#include <functional>
// https://github.com/WebKit/webkit/blob/152410da081c1a638a3c2b8c0f55b5e726fffd15/Source/WebKit2/UIProcess/Cocoa/WebViewImpl.h#L366
namespace WebKit { // ObjC++
class WebViewImpl { // ObjC++ <WebKit::WebViewImpl>
    //WTF_MAKE_FAST_ALLOCATED;
    //WTF_MAKE_NONCOPYABLE(WebViewImpl);
public:
	//WebViewImpl(NSView <WebViewImplDelegate> *, WKWebView *outerWebView, WebProcessPool&, Ref<API::PageConfiguration>&&);
	//~WebViewImpl();

	// https://github.com/WebKit/webkit/blob/152410da081c1a638a3c2b8c0f55b5e726fffd15/Source/WebKit2/UIProcess/Cocoa/WebViewImpl.h#L365
	void setThumbnailView(_WKThumbnailView *);
    _WKThumbnailView *thumbnailView(); // const { return m_thumbnailView; }
/*
/Applications/Safari Technology Preview.app/Contents/Frameworks/WebKit.framework/WebKit [i386, 0.000728 seconds]:
 symbols matching [*keyUp*]:
     873F541E-4B2A-3B6C-B33C-74FC605D2656 /Applications/Safari Technology Preview.app/Contents/Frameworks/WebKit.framework/WebKit [DYLIB, ObjC-RR, FaultedFromDisk, MMap32]
             0x0000149c (0x295278) __TEXT __text
                 0x0004125e (    0x24) -[WKView keyUp:] [FUNC, OBJC, NameNList, MangledNameNList, Merged, NList, FunctionStarts]
                 0x0026ec5a (    0x64) WebKit::WebViewImpl::keyUp(NSEvent*) [FUNC, PEXT, NameNList, MangledNameNList, Merged, NList, FunctionStarts]
*/
//private: // http://stackoverflow.com/questions/6873138/calling-private-method-in-c
	// ^ need to friend this class so I can call privates from outside
	// http://stackoverflow.com/questions/2391679/why-do-we-need-virtual-functions-in-c
	//NSView <WebViewImplDelegate> *m_view;
//	_WKThumbnailView *m_thumbnailView { nullptr }; // ;-( no symbol in vtable
	//bool m_requiresUserActionForEditingControlsManager { false };
};
} // namespace WebKit
#endif // __cplusplus

@interface WKWebView (WithImpl)
@property (nonatomic, readonly) void* _impl; // export to swift as unsafe pointer
//FOUNDATION_EXPORT void* _impl;
//@property (nonatomic, setter=_setThumbnailView:) _WKThumbnailView *_thumbnailView; // https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/mac/WKViewInternal.h
@property (nonatomic, readonly) _WKThumbnailView *_thumbnailView; // https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/mac/WKViewInternal.h
@end

@interface WKWebViewSnappable: WKWebView
#ifdef __cplusplus
{
@public // can't find it in the vtable
	std::unique_ptr<WebKit::WebViewImpl> _impl; // can only add instance variables in subclasses, not extension. same in swift as ObjC(++)
	// https://github.com/WebKit/webkit/blob/03aae442c5f9a1e32ff96abf4e2595b4a5d8a44c/Source/WebKit2/UIProcess/API/Cocoa/WKWebView.mm#L264
}
#endif // __cplusplus
//@property (nonatomic, setter=_setThumbnailView:) _WKThumbnailView *_thumbnailView; // https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/mac/WKViewInternal.h
@property (nonatomic, readonly) _WKThumbnailView *_thumbnailView; // https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/mac/WKViewInternal.h
@end
#endif // !IOS
