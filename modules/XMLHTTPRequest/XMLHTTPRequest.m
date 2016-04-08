#import "XMLHttpRequest.h"
@implementation XMLHttpRequest {
    NSURLSession *_urlSession;
    NSString *_httpMethod;
    NSURL *_url;
    bool _async;
    NSMutableDictionary *_requestHeaders;
    NSMutableDictionary *_responseHeaders;
	JSManagedValue *m_onreadystatechange;
	JSManagedValue *m_onload;
	JSManagedValue *m_onerror;
};

@synthesize responseText;
@synthesize readyState;
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

- (JSManagedValue *)m_makeCallback:(JSValue *)value {
	JSManagedValue *managed = [[JSManagedValue alloc] initWithValue:value];
	// FIXME: callback's `this` is JSGlobalContext `GlobalObject` .. should be self
	[value.context.virtualMachine addManagedReference:managed withOwner:self];
	return managed;
}

- (void)setOnerror:(JSValue *)value { m_onerror = [self m_makeCallback:value]; }
- (JSValue *)onerror { return [m_onerror value]; }
- (void)setOnload:(JSValue *)value { m_onload = [self m_makeCallback:value]; }
- (JSValue *)onload { return [m_onload value]; }
- (void)setOnreadystatechange:(JSValue *)value { m_onreadystatechange = [self m_makeCallback:value]; }
- (JSValue *)onreadystatechange { return [m_onreadystatechange value]; }

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

    __block XMLHttpRequest *weakSelf = self;

    id completionHandler = ^(NSData *receivedData, NSURLResponse *response, NSError *error) {
       // request is now complete
       // FIXME: remove compHandler & implement NSURLSessionDataDelegate so we can handle progressive state changes
       if (response != nil) {
           NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *) response;
           weakSelf.readyState = @(XMLHTTPRequestDONE); // FIXME: figure out what state we're really in
           weakSelf.status = @(httpResponse.statusCode);
           weakSelf.responseText = [[NSString alloc] initWithData:receivedData
                                                  encoding:NSUTF8StringEncoding];
           [weakSelf setAllResponseHeaders:[httpResponse allHeaderFields]];
           if (m_onreadystatechange) [self.onreadystatechange callWithArguments:@[]];
           if (m_onload) [self.onload callWithArguments:@[]];
       } else if (error != nil) {
            NSLog(@"XMLHTTPRequest error: %@", error);
            if (m_onerror) [self.onerror callWithArguments:@[[error description]]];
       }
    };
    NSURLSessionDataTask *task = [_urlSession dataTaskWithRequest:request
                                                completionHandler:completionHandler];

    [task resume];
}
//-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler
//-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didBecomeDownloadTask:(NSURLSessionDownloadTask *)downloadTask
//-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
//-(void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask willCacheResponse:(NSCachedURLResponse *)proposedResponse completionHandler:(void (^)(NSCachedURLResponse *cachedResponse))completionHandler

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

- (void)dealloc
{
    if (m_onerror) [[m_onerror value].context.virtualMachine removeManagedReference:m_onerror withOwner:self];
    if (m_onload) [[m_onload value].context.virtualMachine removeManagedReference:m_onload withOwner:self];
    if (m_onreadystatechange) [[m_onreadystatechange value].context.virtualMachine removeManagedReference:m_onreadystatechange withOwner:self];
	[super dealloc];
}
@end
