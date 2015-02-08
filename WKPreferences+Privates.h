@import WebKit;
//#import <wtf/RefPtr.h> // https://github.com/WebKit/webkit/blob/master/Source/WTF/wtf/RefPtr.h

/*
// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/Cocoa/WKPreferencesInternal.h
//namespace WebKit {
//class WebPreferences;
//}
@interface WKPreferences () {
@public
//_preferences = WebKit::WebPreferences
RefPtr<WebKit::WebPreferences> _preferences;
}
@end
*/

@interface WKPreferences (Privates)
// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/Cocoa/WKPreferencesPrivate.h
@property (nonatomic, setter=_setDeveloperExtrasEnabled:) BOOL _developerExtrasEnabled;
@property (nonatomic, setter=_setFullScreenEnabled:) BOOL _fullScreenIsEnabled;

// need to be able to compile an ObjC++ class catergory/extension/continuation 
// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/C/WKPreferencesRefPrivate.h
// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/C/WKPreferences.cpp
//@property (nonatomic, setter=_setFileAccessFromFileURLsAllowed:) BOOL _fileAccessFromFileURLsAllowed;
//@property (nonatomic, setter=_setUniversalAccessFromFileURLsAllowed:) BOOL _universalAccessFromFileURLsAllowed;
@end
