#import "XMLHttpRequest.h"


@implementation XMLHttpRequest {
    NSURLSession *_urlSession;
    NSString *_httpMethod;
    NSURL *_url;
    bool _async;
    NSMutableDictionary *_requestHeaders;
    NSDictionary *_responseHeaders;
};

@synthesize responseText;
@synthesize onreadystatechange;
@synthesize readyState;
@synthesize onload;
@synthesize onerror;
@synthesize status;


- (instancetype)init {
    return [self initWithURLSession:[NSURLSession sharedSession]];
}


- (instancetype)initWithURLSession:(NSURLSession *)urlSession {
    if (self = [super init]) {
        _urlSession = urlSession;
        self.readyState = @(XMLHttpRequestUNSENT);
        _requestHeaders = [NSMutableDictionary new];
    }
    return self;
}

- (void)extend:(id)jsContext {

    // Simulate the constructor.
    jsContext[@"XMLHTTPRequest"] = ^{
        return self;
    };
    jsContext[@"XMLHTTPRequest"][@"UNSENT"] = @(XMLHttpRequestUNSENT);
    jsContext[@"XMLHTTPRequest"][@"OPENED"] = @(XMLHTTPRequestOPENED);
    jsContext[@"XMLHTTPRequest"][@"LOADING"] = @(XMLHTTPRequestLOADING);
    jsContext[@"XMLHTTPRequest"][@"HEADERS"] = @(XMLHTTPRequestHEADERS);
    jsContext[@"XMLHTTPRequest"][@"DONE"] = @(XMLHTTPRequestDONE);

}

- (void)open:(NSString *)httpMethod :(NSString *)url :(bool)async {
    // TODO should throw an error if called with wrong arguments
    _httpMethod = httpMethod;
    _url = [NSURL URLWithString:url];
    _async = async;
    self.readyState = @(XMLHTTPRequestOPENED);
}

- (void)send:(id)data {
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:_url];
    for (NSString *name in _requestHeaders) {
        [request setValue:_requestHeaders[name] forHTTPHeaderField:name];
    }
    if ([data isKindOfClass:[NSString class]]) {
        request.HTTPBody = [((NSString *) data) dataUsingEncoding:NSUTF8StringEncoding];
    }
    [request setHTTPMethod:_httpMethod];

    __block __weak XMLHttpRequest *weakSelf = self;

    id completionHandler = ^(NSData *receivedData, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
        weakSelf.readyState = @(XMLHTTPRequestDONE); // TODO
        weakSelf.status = @(httpResponse.statusCode);
        weakSelf.responseText = [[NSString alloc] initWithData:receivedData
                                                  encoding:NSUTF8StringEncoding];
        [weakSelf setAllResponseHeaders:[httpResponse allHeaderFields]];
        if (weakSelf.onreadystatechange != nil) {
            [weakSelf.onreadystatechange callWithArguments:@[]];
        }
    };
    NSURLSessionDataTask *task = [_urlSession dataTaskWithRequest:request
                                                completionHandler:completionHandler];
    [task resume];
}

- (void)setRequestHeader:(NSString *)name :(NSString *)value {
    _requestHeaders[name] = value;
}

- (NSString *)getAllResponseHeaders {
    NSMutableString *responseHeaders = [NSMutableString new];
    for (NSString *key in _responseHeaders) {
        [responseHeaders appendString:key];
        [responseHeaders appendString:@": "];
        [responseHeaders appendString:_responseHeaders[key]];
        [responseHeaders appendString:@"\n"];
    }
    return responseHeaders;
}

- (NSString *)getReponseHeader:(NSString *)name {
    return _responseHeaders[name];
}

- (void)setAllResponseHeaders:(NSDictionary *)responseHeaders {
    _responseHeaders = responseHeaders;
}

@end
