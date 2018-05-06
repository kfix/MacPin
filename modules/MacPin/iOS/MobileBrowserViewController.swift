/// MacPin MobileBrowserViewController
///
/// An iOS rootViewController for containing multiple WKWebViews, akin to MobileSafari

/// This is already a ball of wax...
//  -reconcile childViewControllers. selectedViewController, tabSelected, and tabs
//		https://github.com/codepath/ios_guides/wiki/Container-View-Controllers
//  -break the controlviews into subclasses & controllers
/// http://doing-it-wrong.mikeweller.com/2013/06/ios-app-architecture-and-tdd-1.html

import WebKit
import UIKit
import JavaScriptCore
import ViewPrivates

extension UIView {
	func dumpFrame() {
		let screen = UIScreen.mainScreen().bounds
		warn("screen: \(screen.size.width),\(screen.size.height)")
		warn("frame: @\(frame.origin.x),\(frame.origin.y) \(frame.size.width),\(frame.size.height)")
		warn("bounds: @\(bounds.origin.x),\(bounds.origin.y) \(bounds.size.width),\(bounds.size.height)")
	}
}

@objc class MobileBrowserViewController: UIViewController, BrowserViewController {
	//var frame: CGRect = UIScreen.mainScreen().applicationFrame

	var kvoCtx = "kvo"
	weak var selectedViewController: UIViewController? = nil {
		willSet {
			if let wvc = selectedViewController as? WebViewController {
	        	wvc.removeObserver(self, forKeyPath: "webview.estimatedProgress")
	        	wvc.removeObserver(self, forKeyPath: "webview.URL")
	        	wvc.removeObserver(self, forKeyPath: "webview.title")
			}
		}
		didSet {
			if let vc = selectedViewController {
				tabView = vc.view
			}
			if let wvc = selectedViewController as? WebViewController {
				lastContentOffset = wvc.webview.scrollView.contentOffset.y // update scrolling tracker
	        	wvc.addObserver(self, forKeyPath: "webview.estimatedProgress", options: [.New, .Initial], context: &kvoCtx)
	        	wvc.addObserver(self, forKeyPath: "webview.URL", options: [.New, .Initial], context: &kvoCtx)
	        	wvc.addObserver(self, forKeyPath: "webview.title", options: [.New, .Initial], context: &kvoCtx)
			}
		}
	}
	var tabView = UIView() {
		willSet {
			//newValue.frame = tabView.frame
			newValue.frame = view.bounds
			newValue.hidden = false
		}
		didSet {
			oldValue.hidden = true
			view.addSubview(tabView)
			tabView.addSubview(blurBar) // needs to attach in front of tab to get touch focus
			//tabView.addSubview(navBar) // for focus
			tabView.addSubview(toolBar) // for focus and for target-less responder chain calls to webviews
 		}
	}

	let blurBar = UIVisualEffectView(effect: UIBlurEffect(style: .Light))
	//let blurBarControls = UIVisualEffectView(effect: UIVibrancyEffect(forBlurEffect: UIBlurEffect(style: .Light)))
	let blurBarControls = UIView()
	let navBox = UITextField()

	let progBar = UIProgressView(progressViewStyle: .Bar)

	//let navBar = UISearchBar()
	let toolBar = UIToolbar()

	let tabList = UITableView()

	var showBars = false {
		willSet {
		}
		didSet {
			if oldValue != showBars {
				view.setNeedsLayout()
				view.layoutIfNeeded()
			}
		}
	}

	var defaultUserAgent: String? = nil
	var transparent: Bool = false {	didSet { warn()	} }

	// all scrolling webtabs will hew to this box
	var contentInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
	var lastContentOffset = CGFloat(0.0) // tracks scrolling direction

	override func loadView() {
		//definesPresentationContext = true // self.view.frame will be used to size all presentedViewControllers
		//providesPresentationContextTransitionStyle = true
		//modalPresentationStyle = .OverFullScreen
		//modalTransitionStyle = .CrossDissolve // .CoverVertical | .CrossDissolve | .FlipHorizontal

		view = UIView()
		view.backgroundColor = nil // transparent base view
		view.autoresizingMask = [.FlexibleHeight, .FlexibleWidth] //resize base view to match superview size (if any)
		view.autoresizesSubviews = true // resize tabbed subviews based on their autoresizingMasks

		// FIXME: sites should be able to override these gesture recognizers
		let swipeLeft = UISwipeGestureRecognizer(target: self, action: Selector("switchToNextTab"))
		swipeLeft.direction = UISwipeGestureRecognizerDirection.Left
		view.addGestureRecognizer(swipeLeft)
		let swipeRight = UISwipeGestureRecognizer(target: self, action: Selector("switchToPreviousTab"))
		swipeRight.direction = UISwipeGestureRecognizerDirection.Right
		view.addGestureRecognizer(swipeRight)

		tabView.autoresizingMask = [.FlexibleHeight, .FlexibleWidth] //resize selected VC's view to match superview size (if any)
		tabView.autoresizesSubviews = true // resize tabbed subviews based on their autoresizingMasks
		tabView.backgroundColor = UIColor.redColor()
		view.addSubview(tabView)

		//navBar.autoresizingMask = .FlexibleWidth
		//navBar.translucent = true
		//navBar.prompt = "   " // sits under statusBar's time
		//navBar.searchBarStyle = .Minimal
		//navBar.showsCancelButton = false
		//navBar.delegate = self
		//navBar.setImage(, forSearchBarIcon: .Search, state: .Normal)

		blurBar.autoresizingMask = .FlexibleWidth
		blurBar.frame = CGRect(x:0, y:0, width: view.bounds.size.width, height: 30)
		blurBarControls.frame = blurBar.bounds
		navBox.autoresizingMask = .FlexibleWidth
		navBox.frame = CGRect(x:0, y:0, width: blurBarControls.bounds.size.width, height: 25)
		navBox.placeholder = "Enter URL"
		navBox.font = UIFont.systemFontOfSize(10.0)
		navBox.textColor = UIColor.blackColor()
		navBox.textAlignment = .Center
		//navBox.borderStyle = .RoundedRect
		navBox.borderStyle = .None
		navBox.backgroundColor = UIColor.clearColor()
		navBox.delegate = self
		blurBarControls.addSubview(navBox)
		progBar.autoresizingMask = .FlexibleWidth
        progBar.trackTintColor = UIColor.lightGrayColor()
        progBar.tintColor = UIColor.blueColor()
		//progBar.frame = CGRect(x:0, y:blurBarControls.bounds.size.height - 3, width: blurBarControls.bounds.size.width, height: 3)
		progBar.frame = CGRect(x:0, y:0, width: blurBarControls.bounds.size.width, height: 3)
        blurBarControls.addSubview(progBar)
		blurBar.contentView.addSubview(blurBarControls)

		toolBar.autoresizingMask = .FlexibleWidth
		toolBar.setItems([
			//UIBarButtonItem(image:UIImage(named: "toolbar_import"), style: .Plain, target: self, action: Selector("switchToPreviousTab")),
			//UIBarButtonItem(image:UIImage(named: "toolbar_export"), style: .Plain, target: self, action: Selector("switchToNextTab")),
			UIBarButtonItem(image:UIImage(named: "toolbar_back"), style: .Plain, target: nil, action: Selector("goBack")), //web
			UIBarButtonItem(image:UIImage(named: "toolbar_forward"), style: .Plain, target: nil, action: Selector("goForward")), //web
			UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: nil),
			UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: Selector("newTabPrompt")),
			//UIBarButtonItem(image:UIImage(named: "toolbar_document"), style: .Plain, target: self, action: Selector("newTabPrompt")),
			UIBarButtonItem(image:UIImage(named: "toolbar_virtual_machine"), style: .Plain, target: self, action: Selector("toggleTabList")), // tab picker
			//UIBarButtonItem(image:UIImage(named: "toolbar_delete_file"), style: .Plain, target: self, action: Selector("closeCurrentTab")),
			UIBarButtonItem(image:UIImage(named: "toolbar_trash"), style: .Plain, target: self, action: Selector("closeCurrentTab")),
			UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: nil),
			UIBarButtonItem(image:UIImage(named: "toolbar_open_in_browser"), style: .Plain, target: nil, action: Selector("askToOpenCurrentURL")), //wvc
			UIBarButtonItem(image:UIImage(named: "toolbar_upload"), style: .Plain, target: nil, action: Selector("shareButtonClicked:")), // wvc
			UIBarButtonItem(barButtonSystemItem: .FlexibleSpace, target: nil, action: nil),
			//UIBarButtonItem(barButtonSystemItem: .Refresh, target: nil, action: Selector("reload:")), //web
			UIBarButtonItem(image:UIImage(named: "toolbar_download_from_cloud"), style: .Plain, target: nil, action: Selector("reload")), //web
			UIBarButtonItem(image:UIImage(named: "toolbar_cancel"), style: .Plain, target: nil, action: Selector("stopLoading")), //web
			//UIBarButtonItem(barButtonSystemItem: .Stop, target: nil, action: Selector("stopLoading:")), //web
		], animated: false)
		//toolBar.barTintColor = UIColor.blackColor()
		//toolBar.barStyle = UIBarStyle.Black
		//toolBar.setTranslatesAutoresizingMaskIntoConstraints(false)
		toolBar.translucent = true

		tabList.dataSource = self
		tabList.delegate = self
		tabList.rowHeight = 50
		tabList.registerClass(UITableViewCell.self, forCellReuseIdentifier: "TableViewCell")

		view.layoutIfNeeded()

		NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("appWillChangeStatusBarFrameNotification:"), name: UIApplicationWillChangeStatusBarFrameNotification, object: nil)
	}

	override func viewWillAppear(_ animated: Bool) { warn() }

	override func viewWillLayoutSubviews() { // do manual layout of our views
		toolBar.hidden = !showBars

		let statusHeight = UIApplication.sharedApplication().statusBarFrame.size.height
		tabView.frame = view.bounds

		blurBar.frame = showBars ?
			CGRect(x:0, y:0, width: view.bounds.size.width, height: statusHeight + 25) : // show controls
			CGRect(x:0, y:-progBar.frame.size.height, width: view.bounds.size.width, height: statusHeight + progBar.frame.size.height) // hide all controls but sneak progBar into bottom of statusbar
		blurBarControls.frame = CGRect(x:0, y:statusHeight, width: blurBar.bounds.size.width, height: 25)
		progBar.sizeToFit()
		//warn(blurBar.recursiveDescription() as! String)

		//navBar.frame.origin.y = statusHeight
		//navBar.sizeToFit() // stretch width

		toolBar.frame.origin.y = tabView.frame.size.height - toolBar.frame.size.height //align to bottom of contentView
		toolBar.sizeToFit() //stretch width

		tabList.frame = //view.bounds
			CGRect(x:0, y:statusHeight, width: view.bounds.size.width, height: view.bounds.size.height - statusHeight - toolBar.frame.size.height)

		//contentInset.top = statusHeight + navBar.frame.size.height
		contentInset.top = showBars ? blurBar.frame.size.height : statusHeight
		contentInset.bottom = showBars ? toolBar.frame.size.height : 0
	}

	override var description: String { return "<\(self.dynamicType)> `\(title ?? String())`" }

	func indexOfChildViewController(_ vc: UIViewController) -> Int {
		for (index, el) in childViewControllers.enumerate() {
			if el === vc { return index }
		}
		return -3
	}

	override func addChildViewController(_ childController: UIViewController) {
		if indexOfChildViewController(childController) >= 0 { return } // don't re-add existing children, that moves them to back of list
		warn()
		super.addChildViewController(childController)

		if let wvc = childController as? WebViewController {
			wvc.webview.scrollView.delegate = self
			wvc.webview.scrollView.contentInset = contentInset
			wvc.webview.scrollView.scrollIndicatorInsets = contentInset
			tabList.reloadData()
		}

		childController.view.hidden = true
		view.insertSubview(childController.view, belowSubview: tabView) // ensure new tab is in view hierarchy, but behind visible tab & toolBar
	}

	override func presentViewController(_ viewController: UIViewController, animated: Bool, completion: (() -> Void)?) {
		warn()
		super.presentViewController(viewController, animated: animated, completion: completion)
	}

	//override func viewWillAppear(animated: Bool) { warn() }
	//override func viewDidAppear(animated: Bool) { warn() }

	override func viewWillTransitionToSize(_ size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
		view.dumpFrame()
		let oldStatusHeight = UIApplication.sharedApplication().statusBarFrame.size.height
		warn("rotating size to \(size.width),\(size.height)")
		coordinator.animateAlongsideTransition({ (UIViewControllerTransitionCoordinatorContext) -> Void in
		}, completion: { [unowned self] (UIViewControllerTransitionCoordinatorContext) -> Void in
			self.view.frame.size = size
			let newStatusHeight = UIApplication.sharedApplication().statusBarFrame.size.height
			let statusDelta = newStatusHeight - oldStatusHeight
			warn("rotation completed: statusBar changed: \(statusDelta)")
			//self.view.dumpFrame()
			self.view.setNeedsLayout()
			self.view.layoutIfNeeded()
		})
		super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
	}

	func appWillChangeStatusBarFrameNotification(_ notification: NSNotification) {
		if let status = notification.userInfo?[UIApplicationStatusBarFrameUserInfoKey] as? NSValue {
			let statusRect = status.CGRectValue()
			warn("\(statusRect.size.height)") // FIXME: this is off-phase if app started in landscape mode on iPhone
		}
	}

	//override func sizeForChildContentContainer(container: UIContentContainer, withParentContainerSize parentSize: CGSize) -> CGSize {}
	// return view.frame.size - status & toolbars?

	override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask { return .All }

	override func observeValueForKeyPath(_ keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutableRawPointer) {
		if let keyPath = keyPath {
			switch (keyPath) {
				case "webview.estimatedProgress": if let prog = change?[NSKeyValueChangeNewKey] as? Float {
						if prog == 1 {
							progBar.progress = 0.0
							progBar.hidden = true
						} else {
							progBar.hidden = false
							progBar.setProgress(prog, animated: true)
						}
					}
				case "webview.URL":	if let url = change?[NSKeyValueChangeNewKey] as? NSURL {
						//navBar.text = urlstr
						navBox.text = url.absoluteString
					}
				case "webview.title": if let title = change?[NSKeyValueChangeNewKey] as? String where !title.isEmpty {
						//navBar.prompt = title
						navBox.text = title
					}
				default: warn(keyPath)
			}
		}
	}

}

extension MobileBrowserViewController {
	var tabs: [MPWebView] { return childViewControllers.filter({ $0 is WebViewControllerIOS }).map({ ($0 as! WebViewControllerIOS).webview }) }

	var selectedViewControllerIndex: Int {
		get {
			if let vc = selectedViewController { return indexOfChildViewController(vc) }
			return -2
		}
		set {
			if newValue >= 0 && childViewControllers.count > newValue {
				warn(newValue.description)
				tabSelected = childViewControllers[newValue]
			}
		}
	}

	var tabSelected: AnyObject? {
		get { return selectedViewController?.view }
		set(obj) {
			switch (obj) {
				case let vc as UIViewController:
					if selectedViewController != vc {
						addChildViewController(vc)
						selectedViewController = vc
					}
					//warn("\n\(_printHierarchy() as! String)")
				case let wv as MPWebView: // convert to VC ref and reassign
					self.tabSelected = childViewControllers.filter({ ($0 as? WebViewControllerIOS)?.webview === wv }).first as? WebViewControllerIOS ?? WebViewControllerIOS(webview: wv)
				default:
					warn("invalid object")
			}
			//warn(view.recursiveDescription() as! String) // hangs on really complex webview sites
		}
	}

	func newTabPrompt() {
		warn()
		showBars = true
		tabSelected = MPWebView(url: NSURL(string: "about:blank")!)
		navBox.becomeFirstResponder() //pop-up keyboard
	}
	func newIsolatedTabPrompt() {}
	func newPrivateTabPrompt() {}

	func pushTab(_ webview: AnyObject) { if let webview = webview as? MPWebView { addChildViewController(WebViewControllerIOS(webview: webview)) } }

	func addShortcut(_ title: String, _ obj: AnyObject?) {} // FIXME: populate bottom section of tabList with App shortcuts
	// + Force Touch AppIcon menu?

	func focusOnBrowser() {}
	func unhideApp() {}
	func bounceDock() {}

	func switchToPreviousTab() { selectedViewControllerIndex -= 1 }
	func switchToNextTab() { selectedViewControllerIndex += 1 }
	func closeCurrentTab() {
		if let vc = selectedViewController {
			let idx = selectedViewControllerIndex
			//if childViewControllers.count > 2 { newTabPrompt() }
			switchToNextTab()
			if idx == selectedViewControllerIndex { switchToPreviousTab() }
			if idx == selectedViewControllerIndex { newTabPrompt() }
			if idx == selectedViewControllerIndex { warn("something's wrong!"); return }
			vc.removeFromParentViewController()
			tabList.reloadData()
		}
	}
}

extension MobileBrowserViewController: UISearchBarDelegate {
	func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
		warn()
		if let wvc = selectedViewController as? WebViewController, url = validateURL(searchBar.text ?? "") {
			searchBar.text = url.absoluteString
			wvc.webview.gotoURL(url as NSURL)
		} else {
			warn("invalid url was requested!")
		}
	}

	func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
		warn()
	}
}

extension MobileBrowserViewController: UITextFieldDelegate {
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		if let wvc = selectedViewController as? WebViewController, url = validateURL(textField.text ?? "") {
			textField.resignFirstResponder()
			textField.text = url.absoluteString
			wvc.webview.gotoURL(url as NSURL)
		} else {
			warn("invalid url was requested!")
		}
		return true
	}
	func textFieldDidBeginEditing(_ textField: UITextField) {
		if let wvc = selectedViewController as? WebViewController, urlstr = wvc.webview.URL?.absoluteString {
			textField.text = urlstr
		}
	}
}

extension MobileBrowserViewController: UIScrollViewDelegate {
	func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { warn("\(lastContentOffset)") }

	func scrollViewDidScroll(_ scrollView: UIScrollView) {
		let drag = scrollView.contentOffset.y
		if (scrollView.dragging || scrollView.tracking) && !scrollView.decelerating { //active-touch scrolling in progress
			if (lastContentOffset > drag) { // scrolling Up
				showBars = true
			} else if (lastContentOffset <= drag) { // scrolling Down
				showBars = false
			}
		}
		lastContentOffset = drag
	}
	func scrollViewWillEndDragging(_ scrollView: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset: UnsafeMutablePointer<CGPoint>) { warn() }
	func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) { decelerate ? warn("finger flicked off") : warn("finger lifted off") }
}

extension MobileBrowserViewController: UITableViewDataSource, UITableViewDelegate {
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		//section: 0
		return tabs.count
		//return childViewControllers.count

		// section: 1 could be for addShortcuts ...
	}

    func tableView(_ tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("TableViewCell", forIndexPath: indexPath)

        let wv = tabs[indexPath.row]
        if let wti = wv.title where !wti.isEmpty { title = wti }
			else if let urlstr = wv.URL?.absoluteString where !urlstr.isEmpty { title = urlstr }
			else { title = "Untitled" }
		//title = childViewControllers[indexPath.row].title

        cell.textLabel?.text = title
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
		tabSelected = tabs[indexPath.row]
		//if let newVC = childViewControllers[indexPath.row] as? UIViewController { selectedViewController = newVC }
		tabList.removeFromSuperview()
    }

	func toggleTabList() {
		if let sv = tabList.superview where sv == tabView {
			tabList.removeFromSuperview()
		} else {
			tabView.insertSubview(tabList, aboveSubview: toolBar)
			view.setNeedsLayout()
			view.layoutIfNeeded()
		}
	}
}
