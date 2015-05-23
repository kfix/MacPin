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
@property (nonatomic, setter=_setDiagnosticLoggingEnabled:) BOOL _diagnosticLoggingEnabled;
@property (nonatomic, setter=_setStandalone:, getter=_isStandalone) BOOL _standalone;

// need to be able to compile an ObjC++ to C-API bridge
// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/C/WKPreferencesRefPrivate.h
// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/C/WKPreferences.cpp
// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/Cocoa/WKPreferences.mm
//@property (nonatomic, setter=_setFileAccessFromFileURLsAllowed:) BOOL _fileAccessFromFileURLsAllowed;
//@property (nonatomic, setter=_setUniversalAccessFromFileURLsAllowed:) BOOL _universalAccessFromFileURLsAllowed;
//@property (nonatomic, setter=_setForceFTPDDirectoryListings:) BOOL _forceFTPDDirectoryListings;

@end
