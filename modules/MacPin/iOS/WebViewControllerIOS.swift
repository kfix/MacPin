/// MacPin WebViewControllerIOS
///
/// WebViewController subclass for iOS

import UIKit
import WebKit
	
@objc class WebViewControllerIOS: WebViewController {
	convenience required init(webview: MPWebView) {
		self.init(webview: webview)
	}

	override func viewDidLoad() {
		super.viewDidLoad()
		//view.wantsLayer = true //use CALayer to coalesce views
		//^ default=true:  https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/mac/WKView.mm#L3641
		//view.autoresizingMask = .ViewWidthSizable | .ViewHeightSizable //FIXMEios
	}
	
	override func viewWillAppear(animated: Bool) { // window popping up with this tab already selected & showing
		super.viewWillAppear(animated) // or tab switching into view as current selection
	}

	//override func removeFromParentViewController() { super.removeFromParentViewController() }

	deinit { warn("\(reflect(self).summary)") }
	
	//override func closeTab() { dismissViewControllerAnimated(true, completion: nil); super() }
}

extension WebViewControllerIOS { // AppGUI funcs
	func shareButtonClicked(sender: AnyObject?) {
		// http://nshipster.com/uiactivityviewcontroller/
		if let url = webview.URL, title = webview.title {
			let activityViewController = UIActivityViewController(activityItems: [title, url], applicationActivities: nil)
			presentViewController(activityViewController, animated: true, completion: nil)
		}
	}

	func askToOpenURL(url: NSURL) {
		if UIApplication.sharedApplication().canOpenURL(url) {
			let alerter = UIAlertController(title: "Open non-browser URL", message: url.description, preferredStyle: .ActionSheet)
			let OK = UIAlertAction(title: "OK", style: .Default) { (_) in UIApplication.sharedApplication().openURL(url) }
			alerter.addAction(OK)
			let Cancel = UIAlertAction(title: "Cancel", style: .Cancel) { (_) in }
			alerter.addAction(Cancel)
			presentViewController(alerter, animated: true, completion: nil)
		} else {
			// FIXME: complain
		}
	}

	/*
	func print(sender: AnyObject?) { warn(""); webview.print(sender) }

	//FIXME: support new scaling https://github.com/WebKit/webkit/commit/b40b702baeb28a497d29d814332fbb12a2e25d03
	func zoomIn() { webview.magnification += 0.2 }
	func zoomOut() { webview.magnification -= 0.2 }
	*/
}
