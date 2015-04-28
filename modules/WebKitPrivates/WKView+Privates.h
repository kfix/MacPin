//https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/Cocoa/WKView.h
// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/Cocoa/WKViewPrivate.h
// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/mac/WKViewInternal.h
// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/mac/WKView.mm
@import WebKit;

//https://github.com/WebKit/webkit/blob/master/Source/WebKit2/Shared/API/c/WKBase.h
typedef const struct OpaqueWKFrame* WKFrameRef; //no Cocoa bridge for this at all, expecting `WKFrame`

#if TARGET_OS_IPHONE
@interface WKView : UIView {
#else
@interface WKView : NSView <NSTextInputClient> {
#endif
}
@property BOOL drawsBackground;
@property BOOL drawsTransparentBackground;
@end

@interface WKView (Private)
@property (readwrite) CGFloat minimumLayoutWidth;
@property (readwrite) CGFloat minimumWidthForAutoLayout;
//@property (readwrite) NSSize minimumSizeForAutoLayout;
@property (readwrite) BOOL shouldClipToVisibleRect;
@property (readwrite) BOOL shouldExpandToViewHeightForAutoLayout;

@property (nonatomic) CGSize minimumLayoutSizeOverride;

//@property (readonly) NSColor *_pageExtendedBackgroundColor;
//@property (copy, nonatomic) NSColor *underlayColor;

- (void)updateLayer;

// https://github.com/WebKit/webkit/blob/72b18a0525ffb78247aa1951efc17129f8390f37/Source/WebKit2/UIProcess/API/mac/WKView.mm#L2312
#if TARGET_OS_OSX
- (NSPrintOperation *)printOperationWithPrintInfo:(NSPrintInfo *)printInfo forFrame:(WKFrameRef)frameRef;
- (NSDragOperation)draggingEntered:(id <NSDraggingInfo>)draggingInfo;
- (NSDragOperation)draggingUpdated:(id <NSDraggingInfo>)draggingInfo;
- (void)draggingExited:(id <NSDraggingInfo>)draggingInfo;
- (BOOL)prepareForDragOperation:(id <NSDraggingInfo>)draggingInfo;
- (BOOL)performDragOperation:(id <NSDraggingInfo>)draggingInfo;
#endif
@end

