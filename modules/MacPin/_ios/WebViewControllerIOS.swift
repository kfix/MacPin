/// MacPin WebViewControllerIOS
///
/// WebViewController subclass for iOS

import UIKit
import WebKit

@objc class WebViewControllerIOS: WebViewController {
	//var modalPresentationStyle = .OverFullScreen
	//var modalTransitionStyle = .CrossDissolve // .CoverVertical | .CrossDissolve | .FlipHorizontal

	override func viewDidLoad() {
		super.viewDidLoad()
		//view.wantsLayer = true //use CALayer to coalesce views
		//^ default=true:  https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/API/mac/WKView.mm#L3641
		view.autoresizingMask = [.flexibleHeight , .flexibleWidth]
	}

	override func viewWillAppear(_ animated: Bool) { // window popping up with this tab already selected & showing
		super.viewWillAppear(animated) // or tab switching into view as current selection
	}

	//override func removeFromParentViewController() { super.removeFromParentViewController() }

	deinit { warn("\(type(of: self))") }

	//override func closeTab() { dismissViewControllerAnimated(true, completion: nil); super() }

/*
	override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
		warn()
		super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
		view.frame.size = size
		view.layoutIfNeeded()
	}
*/

}

extension WebViewControllerIOS { // AppGUI funcs
	@objc func shareButtonClicked(_ sender: AnyObject?) {
		warn()
		// http://nshipster.com/uiactivityviewcontroller/
		if let url = webview.url, let title = webview.title {
			let activityViewController = UIActivityViewController(activityItems: [title, url], applicationActivities: nil)
			present(activityViewController, animated: true, completion: nil)
		}
	}

	func askToOpenURL(_ url: URL?)  /* -> Bool */ { //uti: UTIType? = nil
		guard let url = url else { return }
		if UIApplication.shared.canOpenURL(url) {
			let alerter = UIAlertController(title: "Open non-browser URL", message: url.absoluteString, preferredStyle: .actionSheet)
			let OK = UIAlertAction(title: "OK", style: .default) { (_) in UIApplication.shared.openURL(url) }
			alerter.addAction(OK)
			let Cancel = UIAlertAction(title: "Cancel", style: .cancel) { (_) in }
			alerter.addAction(Cancel)
			present(alerter, animated: true, completion: nil)
		} else {
			// FIXME: complain
		}
	}

	/*
	func print(sender: AnyObject?) {
if ([UIPrintInteractionController isPrintingAvailable])
{
    UIPrintInfo *pi = [UIPrintInfo printInfo];
    pi.outputType = UIPrintInfoOutputGeneral;
    pi.jobName = @"Print";
    pi.orientation = UIPrintInfoOrientationPortrait;
    pi.duplex = UIPrintInfoDuplexLongEdge;

    UIPrintInteractionController *pic = [UIPrintInteractionController sharedPrintController];
    pic.printInfo = pi;
    pic.showsPageRange = YES;
    pic.printFormatter = self.webView.viewPrintFormatter;
    [pic presentFromBarButtonItem:barButton animated:YES completionHandler:^(UIPrintInteractionController *printInteractionController, BOOL completed, NSError *error) {
        if(error)
            NSLog(@"handle error here");
        else
            NSLog(@"success");
    }];
}
	}

	//FIXME: support new scaling https://github.com/WebKit/webkit/commit/b40b702baeb28a497d29d814332fbb12a2e25d03
	func zoomIn() { webview.magnification += 0.2 }
	func zoomOut() { webview.magnification -= 0.2 }
	*/
}
