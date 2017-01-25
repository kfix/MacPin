import Foundation

class MPURLProtocol: NSURLProtocol {
	// https://gist.github.com/omerlh/2617db3d4116bf46bdeb
	class func canInitWithRequest(request: NSURLRequest!) -> Bool {
		warn()
	    return false // FIXME: WK always throws away the post body: https://bugs.webkit.org/show_bug.cgi?id=138169i#c27
		// NSURLSessionConfiguration ? https://www.objc.io/issues/5-ios7/from-nsurlconnection-to-nsurlsession/
		//   http://stackoverflow.com/a/37466532/3878712
	}
}
