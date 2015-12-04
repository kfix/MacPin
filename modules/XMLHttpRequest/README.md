# XMLHTTPRequest

In iOS 7, Apple introduced the possibility to [execute JavaScript via the JavaScriptCore JavaScript 
engine] (http://nshipster.com/javascriptcore/). Unfortunately, JavaScriptCore is missing some 
objects and functions a JavaScript environment of a browser would have. Especially the
`XMLHTTPRequest` (see the [Mozilla documentation]
(https://developer.mozilla.org/en-US/docs/Web/API/XMLHttpRequest) object needed for AJAX reqeuests 
is not provided by JavaScriptCore. This library implements this missing object, so it is possible to 
use JavaScript libraries which were originally developed for in-browser use in your Objective-C 
(or Swift) application without the need to use a hidden WebView.
 
 
## Provided functions
This library tries to implement the full XMLHTTPRequest specification. Curently not all
funcionality is implemented yet. The current limitations are:

* Synchronous calls are not supported.
* The `onload` and `onerror` callbacks are currently not supported.
* The `upload` callback is currently not supported.
* The `timeout` property is currently not supported.

It is planned to support all functionality of the HTML5 specification at some point.

## How to use it
Create a new instance of the `XMLHTTPRequest` class. Then call the `extend:` method and pass either
a `JSContext` instance or a `JSValue` instance. The given object will be extend with the 
`XMLHTTPRequest` object.
 
```objc
#import <XMLHTTPRequest/XMLHTTPRequest.h>

...

JSContext *jsContext = [JSContext new];
XMLHttpRequest *xmlHttpRequest = [XMLHttpRequest new];
[xmlHttpRequest extend:jsContext];
```

The JavaScript context now has a XMLHTTPRequest object you can use like the object found in
browsers. Example (JavaScript):

```JavaScript
request.open('GET', 'http://example.com');
request.setRequestHeader('Accept', 'text/html');
request.setRequestHeader('X-Foo', 'bar');
request.send();
```

### More Stuff

If you are interested in more polyfills for missing browser functionality in JavaScriptCore, there is
a window timers implementation (`setTimeout`, `setInterval`, ...) called [WindowTimers]
(https://github.com/Lukas-Stuehrk/WindowTimers).
