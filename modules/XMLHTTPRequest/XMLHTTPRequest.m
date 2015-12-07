#import "XMLHttpRequest.h"


@implementation XMLHttpRequest {
    NSURLSession *_urlSession;
    NSString *_httpMethod;
    NSURL *_url;
    bool _async;
    NSMutableDictionary *_requestHeaders;
    NSMutableDictionary *_responseHeaders;
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
		_responseHeaders = [NSMutableDictionary new];
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
    _url = [[NSURL alloc] initWithString:url];
    _async = async;
    self.readyState = @(XMLHTTPRequestOPENED);
}

- (void)send:(id)data {
	//NSLog(@"XMLHTTPRequest send(): %@ %@", _httpMethod, [_url absoluteURL]);
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:_url];
    for (NSString *name in _requestHeaders) {
        [request setValue:_requestHeaders[name] forHTTPHeaderField:name];
    }
    if ([data isKindOfClass:[NSString class]]) {
        request.HTTPBody = [((NSString *) data) dataUsingEncoding:NSUTF8StringEncoding];
    }
    [request setHTTPMethod:_httpMethod];

    __block __weak XMLHttpRequest *weakSelf = self;

    id completionHandler = ^(NSData *receivedData, NSURLResponse *response, NSError *error) {
		if (response != nil) {
	        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
	        weakSelf.readyState = @(XMLHTTPRequestDONE); // TODO
    	    weakSelf.status = @(httpResponse.statusCode);
        	weakSelf.responseText = [[NSString alloc] initWithData:receivedData
                                                  encoding:NSUTF8StringEncoding];
	        [weakSelf setAllResponseHeaders:[httpResponse allHeaderFields]];
	        if (weakSelf.onreadystatechange != nil) {
    	        [weakSelf.onreadystatechange callWithArguments:@[]];
	        }
		} else if (error != nil) {
			NSLog(@"XMLHTTPRequest error: %@", error);
	        if (weakSelf.onerror != nil) { // https://developer.mozilla.org/en-US/docs/Web/Events/error
    	        [weakSelf.onerror callWithArguments:@[[error description]]];
	        }
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
        [responseHeaders appendString:key]; // cast to string!!
        [responseHeaders appendString:@": "];
        [responseHeaders appendString:_responseHeaders[key]];
        [responseHeaders appendString:@"\n"];
    }
    return responseHeaders;
	// FIXME should return JS:null if no response yet received!
}

- (NSString *)getResponseHeader:(NSString *)name {
	NSLog(@"Getting header %@", name);
    return _responseHeaders[name];
}

- (void)setAllResponseHeaders:(NSDictionary *)responseHeaders {
	//NSLog(@"Setting headers %@", responseHeaders);
	[_responseHeaders removeAllObjects];
	NSEnumerator *e = [responseHeaders keyEnumerator];
	NSString *headerName;
	while( headerName = [e nextObject] ) {
		[_responseHeaders setValue:[responseHeaders objectForKey:headerName] forKey:headerName];
	}
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<XMLHttpRequest %p> %@ %@", self, _httpMethod, _url];
}
@end
