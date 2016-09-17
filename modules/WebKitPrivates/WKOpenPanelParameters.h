// https://github.com/WebKit/webkit/blob/4b7052ab44fa581810188638d1fdf074e7d754ca/Source/WebKit2/UIProcess/API/Cocoa/WKOpenPanelParameters.h
/*! WKOpenPanelParameters contains parameters that a file upload control has specified.
 */
@interface WKOpenPanelParameters : NSObject

/*! @abstract Whether the file upload control supports multiple files.
 */
@property (nonatomic, readonly) BOOL allowsMultipleSelection;

@end
