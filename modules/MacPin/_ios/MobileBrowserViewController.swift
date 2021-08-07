/// MacPin MobileBrowserViewController
///
/// An iOS rootViewController for containing multiple WKWebViews, akin to MobileSafari

/// This is already a ball of wax...
//  -reconcile childViewControllers. selectedViewController, tabSelected, and tabs
//		https://github.com/codepath/ios_guides/wiki/Container-View-Controllers
//		https://github.com/Ruzard/ContainerSequencedView/blob/master/SampleContainerSequencedView/ContentManagerViewController.swift
//  -break the controlviews into subclasses & controllers
/// http://doing-it-wrong.mikeweller.com/2013/06/ios-app-architecture-and-tdd-1.html

// use rich Enums as model-objects for the Tabs:
//   https://www.47deg.com/blog/swift-enum-oriented-dev-table-views/
//   https://github.com/47deg/enum-oriented-table-view-sample/blob/master/EnumTableViewTest/ViewControllers/MainViewController.swift

import WebKit
import UIKit
import JavaScriptCore
import ViewPrivates

extension UIView {
	func dumpFrame() {
		let screen = UIScreen.main.bounds
		warn("screen: \(screen.size.width),\(screen.size.height)")
		warn("frame: @\(frame.origin.x),\(frame.origin.y) \(frame.size.width),\(frame.size.height)")
		warn("bounds: @\(bounds.origin.x),\(bounds.origin.y) \(bounds.size.width),\(bounds.size.height)")
	}
}

@objc class MobileBrowserViewController: UIViewController, BrowserViewController {
	//var frame: CGRect = UIScreen.main.applicationFrame

	convenience required init?(object: JSValue) {
		self.init()
	}

	var kvoCtx = "kvo"
	weak var selectedViewController: UIViewController? = nil {
		willSet {
			if let wvc = selectedViewController as? WebViewController {
				wvc.removeObserver(self, forKeyPath: "webview.estimatedProgress")
				wvc.removeObserver(self, forKeyPath: "webview.url")
				wvc.removeObserver(self, forKeyPath: "webview.title")
			}
		}
		didSet {
			if let vc = selectedViewController {
				tabView = vc.view
			}
			if let wvc = selectedViewController as? WebViewController {
				lastContentOffset = wvc.webview.scrollView.contentOffset.y // update scrolling tracker
				wvc.addObserver(self, forKeyPath: "webview.estimatedProgress", options: [.new, .initial], context: &kvoCtx)
				wvc.addObserver(self, forKeyPath: "webview.url", options: [.new, .initial], context: &kvoCtx)
				wvc.addObserver(self, forKeyPath: "webview.title", options: [.new, .initial], context: &kvoCtx)
			}
		}
	}
	var tabView = UIView() {
		willSet {
			//newValue.frame = tabView.frame
			newValue.frame = view.bounds
			newValue.isHidden = false
		}
		didSet {
			oldValue.isHidden = true
			view.addSubview(tabView)
			tabView.addSubview(blurBar) // needs to attach in front of tab to get touch focus
			//tabView.addSubview(navBar) // for focus
			tabView.addSubview(toolBar) // for focus and for target-less responder chain calls to webviews
		}
	}

	let blurBar = UIVisualEffectView(effect: UIBlurEffect(style: .light))
	//let blurBarControls = UIVisualEffectView(effect: UIVibrancyEffect(forBlurEffect: UIBlurEffect(style: .Light)))
	let blurBarControls = UIView()
	let navBox = UITextField()

	let progBar = UIProgressView(progressViewStyle: .bar)

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
		view.autoresizingMask = [.flexibleHeight, .flexibleWidth] //resize base view to match superview size (if any)
		view.autoresizesSubviews = true // resize tabbed subviews based on their autoresizingMasks

		// FIXME: sites should be able to override these gesture recognizers
		let swipeLeft = UISwipeGestureRecognizer(target: self, action: Selector("switchToNextTab"))
		swipeLeft.direction = UISwipeGestureRecognizer.Direction.left
		view.addGestureRecognizer(swipeLeft)
		let swipeRight = UISwipeGestureRecognizer(target: self, action: Selector("switchToPreviousTab"))
		swipeRight.direction = UISwipeGestureRecognizer.Direction.right
		view.addGestureRecognizer(swipeRight)

		tabView.autoresizingMask = [.flexibleHeight, .flexibleWidth] //resize selected VC's view to match superview size (if any)
		tabView.autoresizesSubviews = true // resize tabbed subviews based on their autoresizingMasks
		tabView.backgroundColor = UIColor.red
		view.addSubview(tabView)

		//navBar.autoresizingMask = .flexibleWidth
		//navBar.isTranslucent = true
		//navBar.prompt = "   " // sits under statusBar's time
		//navBar.searchBarStyle = .minimal
		//navBar.showsCancelButton = false
		//navBar.delegate = self
		//navBar.setImage(, forSearchBarIcon: .search, state: .normal)

		blurBar.autoresizingMask = .flexibleWidth
		blurBar.frame = CGRect(x:0, y:0, width: view.bounds.size.width, height: 30)
		blurBarControls.frame = blurBar.bounds
		navBox.autoresizingMask = .flexibleWidth
		navBox.frame = CGRect(x:0, y:0, width: blurBarControls.bounds.size.width, height: 25)
		navBox.placeholder = "Enter URL"
		navBox.font = UIFont.systemFont(ofSize: 10.0)
		navBox.textColor = UIColor.black
		navBox.textAlignment = .center
		//navBox.borderStyle = .roundedRect
		navBox.borderStyle = .none
		navBox.backgroundColor = UIColor.clear
		navBox.delegate = self
		blurBarControls.addSubview(navBox)
		progBar.autoresizingMask = .flexibleWidth
        progBar.trackTintColor = UIColor.lightGray
        progBar.tintColor = UIColor.blue
		//progBar.frame = CGRect(x:0, y:blurBarControls.bounds.size.height - 3, width: blurBarControls.bounds.size.width, height: 3)
		progBar.frame = CGRect(x:0, y:0, width: blurBarControls.bounds.size.width, height: 3)
        blurBarControls.addSubview(progBar)
		blurBar.contentView.addSubview(blurBarControls)

		toolBar.autoresizingMask = .flexibleWidth
		toolBar.setItems([
			//UIBarButtonItem(image:UIImage(named: "toolbar_import"), style: .Plain, target: self, action: Selector("switchToPreviousTab")),
			//UIBarButtonItem(image:UIImage(named: "toolbar_export"), style: .Plain, target: self, action: Selector("switchToNextTab")),
			UIBarButtonItem(image:UIImage(named: "toolbar_back"), style: .plain, target: nil, action: Selector("goBack")), //web
			UIBarButtonItem(image:UIImage(named: "toolbar_forward"), style: .plain, target: nil, action: Selector("goForward")), //web
			UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
			UIBarButtonItem(barButtonSystemItem: .add, target: self, action: Selector("newTabPrompt")),
			//UIBarButtonItem(image:UIImage(named: "toolbar_document"), style: .plain, target: self, action: Selector("newTabPrompt")),
			UIBarButtonItem(image:UIImage(named: "toolbar_virtual_machine"), style: .plain, target: self, action: Selector("toggleTabList")), // tab picker
			//UIBarButtonItem(image:UIImage(named: "toolbar_delete_file"), style: .plain, target: self, action: Selector("closeCurrentTab")),
			UIBarButtonItem(image:UIImage(named: "toolbar_trash"), style: .plain, target: self, action: Selector("closeCurrentTab")),
			UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
			UIBarButtonItem(image:UIImage(named: "toolbar_open_in_browser"), style: .plain, target: nil, action: Selector("askToOpenCurrentURL")), //wvc
			UIBarButtonItem(image:UIImage(named: "toolbar_upload"), style: .plain, target: nil, action: Selector("shareButtonClicked:")), // wvc
			UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
			//UIBarButtonItem(barButtonSystemItem: .refresh, target: nil, action: Selector("reload:")), //web
			UIBarButtonItem(image:UIImage(named: "toolbar_download_from_cloud"), style: .plain, target: nil, action: Selector("reload")), //web
			UIBarButtonItem(image:UIImage(named: "toolbar_cancel"), style: .plain, target: nil, action: Selector("stopLoading")), //web
			//UIBarButtonItem(barButtonSystemItem: .stop, target: nil, action: Selector("stopLoading:")), //web
		], animated: false)
		//toolBar.barTintColor = UIColor.blackColor()
		//toolBar.barStyle = UIBarStyle.Black
		//toolBar.setTranslatesAutoresizingMaskIntoConstraints(false)
		toolBar.isTranslucent = true

		tabList.dataSource = self
		tabList.delegate = self
		tabList.rowHeight = 50
		tabList.register(UITableViewCell.self, forCellReuseIdentifier: "TableViewCell")

		view.layoutIfNeeded()

		NotificationCenter.default.addObserver(self, selector: Selector("appWillChangeStatusBarFrameNotification:"), name: UIApplication.willChangeStatusBarFrameNotification, object: nil)
	}

	override func viewWillAppear(_ animated: Bool) { warn() }

	override func viewWillLayoutSubviews() { // do manual layout of our views
		toolBar.isHidden = !showBars

		let statusHeight = UIApplication.shared.statusBarFrame.size.height
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

	override var description: String { return "<\(type(of: self))> `\(title ?? String())`" }

	func indexOfChildViewController(_ vc: UIViewController) -> Int {
		for (index, el) in children.enumerated() {
			if el === vc { return index }
		}
		return -3
	}

	override func addChild(_ childController: UIViewController) {
		if indexOfChildViewController(childController) >= 0 { return } // don't re-add existing children, that moves them to back of list
		warn()
		super.addChild(childController)

		if let wvc = childController as? WebViewController {
			wvc.webview.scrollView.delegate = self
			wvc.webview.scrollView.contentInset = contentInset
			wvc.webview.scrollView.scrollIndicatorInsets = contentInset
			tabList.reloadData()
		}

		childController.view.isHidden = true
		view.insertSubview(childController.view, belowSubview: tabView) // ensure new tab is in view hierarchy, but behind visible tab & toolBar
	}

	override func present(_ viewController: UIViewController, animated: Bool, completion: (() -> Void)?) {
		warn()
		super.present(viewController, animated: animated, completion: completion)
	}

	//override func viewWillAppear(animated: Bool) { warn() }
	//override func viewDidAppear(animated: Bool) { warn() }

	override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
		view.dumpFrame()
		let oldStatusHeight = UIApplication.shared.statusBarFrame.size.height
		warn("rotating size to \(size.width),\(size.height)")
		coordinator.animate(alongsideTransition: { (UIViewControllerTransitionCoordinatorContext) -> Void in
		}, completion: { [unowned self] (UIViewControllerTransitionCoordinatorContext) -> Void in
			self.view.frame.size = size
			let newStatusHeight = UIApplication.shared.statusBarFrame.size.height
			let statusDelta = newStatusHeight - oldStatusHeight
			warn("rotation completed: statusBar changed: \(statusDelta)")
			//self.view.dumpFrame()
			self.view.setNeedsLayout()
			self.view.layoutIfNeeded()
		})
		super.viewWillTransition(to: size, with: coordinator)
	}

    // class let willChangeStatusBarFrameNotification: NSNotification.Name (deprecated...)
	func appWillChangeStatusBarFrameNotification(_ notification: NSNotification) {
		if let status = notification.userInfo?[UIApplication.statusBarFrameUserInfoKey] as? NSValue {
			let statusRect = status.cgRectValue
			warn("\(statusRect.size.height)") // FIXME: this is off-phase if app started in landscape mode on iPhone
		}
	}

	//override func sizeForChildContentContainer(container: UIContentContainer, withParentContainerSize parentSize: CGSize) -> CGSize {}
	// return view.frame.size - status & toolbars?

	override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
		get { return .all }
	}

	override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
		if let keyPath = keyPath {
			switch (keyPath) {
				case "webview.estimatedProgress": if let prog = change?[.newKey] as? Float {
						if prog == 1 {
							progBar.progress = 0.0
							progBar.isHidden = true
						} else {
							progBar.isHidden = false
							progBar.setProgress(prog, animated: true)
						}
					}
				case "webview.url":	if let url = change?[.newKey] as? URL {
						//navBar.text = urlstr
						navBox.text = url.absoluteString
					}
				case "webview.title": if let title = change?[.newKey] as? String, !title.isEmpty {
						//navBar.prompt = title
						navBox.text = title
					}
				default: warn(keyPath)
			}
		}
	}

}

extension MobileBrowserViewController {
	var tabs: [MPWebView] { return children.filter({ $0 is WebViewControllerIOS }).map({ ($0 as! WebViewControllerIOS).webview }) }

	var selectedViewControllerIndex: Int {
		get {
			if let vc = selectedViewController { return indexOfChildViewController(vc) }
			return -2
		}
		set {
			if newValue >= 0 && children.count > newValue {
				warn(newValue.description)
				tabSelected = children[newValue]
			}
		}
	}

	var tabSelected: AnyObject? {
		get { return selectedViewController?.view }
		set(obj) {
			switch (obj) {
				case let vc as UIViewController:
					if selectedViewController != vc {
						addChild(vc)
						selectedViewController = vc
					}
					//warn("\n\(_printHierarchy() as! String)")
				case let wv as MPWebView: // convert to VC ref and reassign
					self.tabSelected = children.filter({ ($0 as? WebViewControllerIOS)?.webview === wv }).first as? WebViewControllerIOS ?? WebViewControllerIOS(webview: wv)
				default:
					warn("invalid object")
			}
			//warn(view.recursiveDescription() as! String) // hangs on really complex webview sites
		}
	}

	func newTabPrompt() {
		warn()
		showBars = true
		tabSelected = MPWebView(url: URL(string: "about:blank")!)
		navBox.becomeFirstResponder() //pop-up keyboard
	}
	func newIsolatedTabPrompt() {}
	func newPrivateTabPrompt() {}

	@objc func pushTab(_ webview: AnyObject) { if let webview = webview as? MPWebView { addChild(WebViewControllerIOS(webview: webview)) } }

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
			//if children.count > 2 { newTabPrompt() }
			switchToNextTab()
			if idx == selectedViewControllerIndex { switchToPreviousTab() }
			if idx == selectedViewControllerIndex { newTabPrompt() }
			if idx == selectedViewControllerIndex { warn("something's wrong!"); return }
			vc.removeFromParent()
			tabList.reloadData()
		}
	}

	static func exportSelf(_ mountObj: JSValue, _ name: String = "Browser") {
		// get ObjC-bridged wrapping of Self
		let wrapper = MobileBrowserViewController.self.wrapSelf(mountObj.context, name)
		mountObj.setObject(wrapper, forKeyedSubscript: name as NSString)
	}

	static func wrapSelf(_ context: JSContext, _ name: String = "Browser") -> JSValue {
		// make MacPin.BrowserWindow() constructable with a wrapping ES6 class
		// https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Classes#Sub_classing_with_extends
		return JSValue(undefinedIn: context)
	}
}

extension MobileBrowserViewController: UISearchBarDelegate {
	func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
		warn()
		if let wvc = selectedViewController as? WebViewController, let url = validateURL(searchBar.text ?? "") {
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
		if let wvc = selectedViewController as? WebViewController, let url = validateURL(textField.text ?? "") {
			textField.resignFirstResponder()
			textField.text = url.absoluteString
			wvc.webview.gotoURL(url as NSURL)
		} else {
			warn("invalid url was requested!")
		}
		return true
	}
	func textFieldDidBeginEditing(_ textField: UITextField) {
		if let wvc = selectedViewController as? WebViewController, let urlstr = wvc.webview.url?.absoluteString {
			textField.text = urlstr
		}
	}
}

extension MobileBrowserViewController: UIScrollViewDelegate {
	func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { warn("\(lastContentOffset)") }

	func scrollViewDidScroll(_ scrollView: UIScrollView) {
		let drag = scrollView.contentOffset.y
		if (scrollView.isDragging || scrollView.isTracking) && !scrollView.isDecelerating { //active-touch scrolling in progress
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
		//return children.count

		// section: 1 could be for addShortcuts ...
	}

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TableViewCell", for: indexPath)

        let wv = tabs[indexPath.row]
        if let wti = wv.title, !wti.isEmpty { title = wti }
			else if let urlstr = wv.url?.absoluteString, !urlstr.isEmpty { title = urlstr }
			else { title = "Untitled" }
		//title = children[indexPath.row].title

        cell.textLabel?.text = title
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
		tabSelected = tabs[indexPath.row]
		//if let newVC = children[indexPath.row] as? UIViewController { selectedViewController = newVC }
		tabList.removeFromSuperview()
    }

	func toggleTabList() {
		if let sv = tabList.superview, sv == tabView {
			tabList.removeFromSuperview()
		} else {
			tabView.insertSubview(tabList, aboveSubview: toolBar)
			view.setNeedsLayout()
			view.layoutIfNeeded()
		}
	}
}
