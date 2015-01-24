@import WebKit;
// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/Cocoa/WKPreferencesPrivate.h
@interface WKPreferences (Privates)
@property (nonatomic, setter=_setDeveloperExtrasEnabled:) BOOL _developerExtrasEnabled;
@end
