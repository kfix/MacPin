import Foundation
class MPURLProtocol: NSURLProtocol {
	class func canInitWithRequest(request: NSURLRequest!) -> Bool {
		warn()
	    return false // FIXME: WK always throws away the post body: https://bugs.webkit.org/show_bug.cgi?id=138169i#c27
		//   registerProtocolClass(NSURLSessionConfiguration) <- that could let you configure ad-hoc CFProxySupport dictionaries: http://stackoverflow.com/a/28101583/3878712
		// NSURLSessionConfiguration ? https://www.objc.io/issues/5-ios7/from-nsurlconnection-to-nsurlsession/

	}
}
