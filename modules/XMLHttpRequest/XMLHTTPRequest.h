#import <Foundation/Foundation.h>
#import <JavaScriptCore/JavaScriptCore.h>

#import "TargetConditionals.h"
#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
#import <UIKit/UIKit.h>
#else 
#import <AppKit/AppKit.h>
#endif

NS_ENUM(NSUInteger , ReadyState) {
    XMLHttpRequestUNSENT =0,	// open()has not been called yet.
    XMLHTTPRequestOPENED,	    // send()has not been called yet.
    XMLHTTPRequestHEADERS,      // RECEIVED	send() has been called, and headers and status are available.
    XMLHTTPRequestLOADING,      // Downloading; responseText holds partial data.
    XMLHTTPRequestDONE          // The operation is complete.
};

@protocol XMLHttpRequest <JSExport>
@property (nonatomic) NSString *responseText;
@property (nonatomic) JSValue *onreadystatechange;
@property (nonatomic) NSNumber *readyState;
@property (nonatomic) JSValue *onload;
@property (nonatomic) JSValue *onerror;
@property (nonatomic) NSNumber *status;


-(void)open:(NSString *)httpMethod :(NSString *)url :(bool)async;
-(void)send:(id)data;
-(void)setRequestHeader: (NSString *)name :(NSString *)value;
-(NSString *)getAllResponseHeaders;
-(NSString *)getReponseHeader:(NSString *)name;
@end



@interface XMLHttpRequest : NSObject <XMLHttpRequest>

- (instancetype)initWithURLSession: (NSURLSession *)urlSession;

- (void)extend:(id)jsContext;
@end
