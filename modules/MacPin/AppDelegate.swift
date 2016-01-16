
#if os(OSX)
import AppKit
#elseif os(iOS)
import UIKit
#endif

import ObjectiveC
import WebKit
import WebKitPrivates
import Darwin

// common AppDelegate code sharable between OSX and iOS (not much)
// FIXME: protocol instead?
protocol MacPinAppDelegate: ApplicationDelegate, _WKDownloadDelegate {
	var window: Window? { get }
	var browserController: BrowserViewController { get }
	var webProcessPool: WKProcessPool! { get }
	static func WebProcessConfiguration() -> _WKProcessPoolConfiguration
}

/*
public class MacPinAppDelegate: NSObject, _WKDownloadDelegate {
	var window: Window? = nil // don't assign up here, first value is persistently used for rotation size calculations!
	var browserController: BrowserViewController

	static func WebProcessConfiguration() -> _WKProcessPoolConfiguration {
		let config = _WKProcessPoolConfiguration()
		//config.injectedBundleURL = NSbundle.mainBundle().URLForAuxillaryExecutable("contentfilter.wkbundle")
		// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/WebProcess/InjectedBundle/API/c/WKBundle.cpp
		return config
	}
	//let webProcessPool = WKProcessPool() // all wkwebviews should share this
	let webProcessPool = WKProcessPool()._initWithConfiguration(MacPinAppDelegate.WebProcessConfiguration()) // all wkwebviews should share this
	//let browserController =

	override init() {
		// browserController.webProcessPool = WKProcessPool
		super.init()
	}

	public func _downloadDidStart(download: _WKDownload!) { warn(download.request.description) }
	public func _download(download: _WKDownload!, didRecieveResponse response: NSURLResponse!) { warn(response.description) }
	public func _download(download: _WKDownload!, didRecieveData length: UInt64) { warn(length.description) }
	public func _download(download: _WKDownload!, decideDestinationWithSuggestedFilename filename: String!, allowOverwrite: UnsafeMutablePointer<ObjCBool>) -> String! {
		warn(download.request.description)
		download.cancel()
		return ""
	}
	public func _downloadDidFinish(download: _WKDownload!) { warn(download.request.description) }
	public func _download(download: _WKDownload!, didFailWithError error: NSError!) { warn(error.description) }
	public func _downloadDidCancel(download: _WKDownload!) { warn(download.request.description) }
}
*/
