import Foundation

// this protocol is registered from and runs in the UIProcess ...
// the requests/responses are XPC'd back and forth to the NetworkProcess via CustomProtocolManagerProxy
//  https://github.com/WebKit/webkit/commit/8ebb8c1a8ac3113b982811c75277bbd2ce49a467
//  https://github.com/WebKit/webkit/commit/2cd97a7728493a554d8e7eff33c0efcd8011b58e

class MPURLProtocol: NSURLProtocol {
	// https://gist.github.com/omerlh/2617db3d4116bf46bdeb
	class func canInitWithRequest(request: NSURLRequest!) -> Bool {
		warn()
	    return false // FIXME: WK always throws away the post body: https://bugs.webkit.org/show_bug.cgi?id=138169#c27

		// NSURLSessionConfiguration ? https://www.objc.io/issues/5-ios7/from-nsurlconnection-to-nsurlsession/
		//   http://stackoverflow.com/a/37466532/3878712
	}
}
