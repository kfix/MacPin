/// MacPin ExtsIOS
///
/// Global-scope utility functions for iOS
 
import UIKit

// show an NSError to the user, attaching it to any given view
func displayError(_ error: NSError, _ vc: UIViewController? = nil) {
	warn("`\(error.localizedDescription)` [\(error.domain)] [\(error.code)] `\(error.localizedFailureReason ?? String())` : \(error.userInfo)")
	let alerter = UIAlertController(title: error.localizedFailureReason, message: error.localizedDescription, preferredStyle: .alert) //.ActionSheet
	let OK = UIAlertAction(title: "OK", style: .default) { (_) in }
	alerter.addAction(OK)

	if let vc = vc { 
		vc.present(alerter, animated: true, completion: nil)
	} else {
		UIApplication.shared.keyWindow?.rootViewController?.present(alerter, animated: true, completion: nil)
	}
}

func askToOpenURL(_ url: NSURL?) {
	if let url = url, UIApplication.shared.canOpenURL(url as URL) {
		//if {
		//	// macpin is already the registered handler for this (probably custom) url scheme, so just open it
		//	UIApplication.sharedApplication().openURL(url)
		//	return
		//}

		let alerter = UIAlertController(title: "Open outside MacPin", message: url.description, preferredStyle: .alert) //.ActionSheet
		let OK = UIAlertAction(title: "OK", style: .default) { (_) in UIApplication.shared.openURL(url as URL) }
		alerter.addAction(OK)
		let Cancel = UIAlertAction(title: "Cancel", style: .cancel) { (_) in }
		alerter.addAction(Cancel)
		UIApplication.shared.keyWindow?.rootViewController?.present(alerter, animated: true, completion: nil)

		return
	}

	// all else has failed, complain to user
	let error = NSError(domain: "MacPin", code: 2, userInfo: [
		//NSURLErrorKey: url?,
		NSLocalizedDescriptionKey: "No program present on this system is registered to open this non-browser URL.\n\n\(url?.description)"
	])
	displayError(error, nil)
}
