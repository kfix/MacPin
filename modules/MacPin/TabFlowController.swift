#if os(OSX)
import AppKit
typealias CollectionView = NSCollectionView
typealias CollectionViewItem = NSCollectionViewItem
#elseif os(iOS)
import UIKit
typealias CollectionView = UICollectionView
typealias CollectionViewItem = UICollectionViewCell
#endif

/// want a nice expose/coverflow/rolodex tab-picker:
// https://github.com/adow/WKPagesCollectionView
// https://github.com/MikeReining/CoverFlowSwift
// https://github.com/schwa/Coverflow
// https://github.com/tuo/CoverFlow/blob/master/CoverFlow/CoverFlowView.m
// https://github.com/search?l=Objective-C&o=desc&p=1&q=coverflow&ref=searchresults&s=updated&type=Repositories
// http://stackoverflow.com/a/353611/3878712 http://www.thinkandbuild.it/introduction-to-3d-drawing-in-core-animation-part-2/

// https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/CollectionViews/Introduction/Introduction.html#//apple_ref/doc/uid/TP40009030
// https://developer.apple.com/library/mac/documentation/Cocoa/Reference/NSCollectionViewItem_Class/index.html
// https://developer.apple.com/library/mac/documentation/Cocoa/Reference/NSCollectionView_Class/index.html
// http://www.extelligentcocoa.org/embedding-a-nscollectionview-in-a-separate-view/
// https://developer.apple.com/library/mac/samplecode/GridMenu/Listings/ReadMe_txt.html#//apple_ref/doc/uid/DTS40010559-ReadMe_txt-DontLinkElementID_14

// https://github.com/klaas/CollectionViewElCapitan
// https://developer.apple.com/videos/play/wwdc2015-225/

// on OSX, make it a pop-out sidebar to show Preview.app-like thumbnail roll: https://github.com/jerrykrinock/SplitViewSidebar/blob/master/SplitViewSidebar/FixedSidebarSplitViewController.m

class TabGridIcon: NSCollectionViewItem {
	required init?(coder: NSCoder) { super.init(coder: coder) } // conform to NSCoding
	override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) { super.init(nibName:nil, bundle:nil) } // calls loadView()
	//override func loadView() { view = urlbox } // NIBless

	override var isSelected: Bool {
		didSet { warn("Selection changed") }
	}
}
// i think you just make WebViewcontroller inherit from NSCollectionViewItem

class TabGridView: NSCollectionView {
	func viewDidLoad() {
		//super.viewDidLoad()
		isSelectable = true
		allowsMultipleSelection = false
		maxNumberOfRows = 0
		maxNumberOfColumns = 10
		minItemSize = NSSize(width: 0, height: 0)
		maxItemSize = NSSize(width: 0, height: 0)
	}
}

/*
https://developer.apple.com/videos/play/wwdc2017/218/
if doing a one-col sidebar or drawer, perhaps should use NSStackView instead
 https://developer.apple.com/videos/play/wwdc2017/218/?time=273
but the tabs list is mutable (push/pop) so NSTableView might be a must
  https://developer.apple.com/videos/play/wwdc2017/218/?time=1931
   i already impl'd UITableView for iOS MacPin...
*/

class TabGridController: NSViewController {
	fileprivate static let column = "column"

	//var tabGrid = TabGridView()
	let tabTable = NSTableView() //frame: .zero)

	//var tabs: [TabGridIcon] = [] //browser.childViewControllers ?? (representedObject as? TabViewController)?.childViewControllers ?? []

	var tabs: [NSViewController] {
		get {
			//return (representedObject as? TabViewController).flatMap({ $0.childViewControllers }) ?? []
			//return (representedObject as? TabViewController).tabView.tabViewItems.flatMap({ $0.viewController }) ?? []
			return (representedObject as? NSTabView)?.tabViewItems.flatMap({ $0.viewController }) ?? []
		}
	}

	var browser: BrowserViewController? { get {
		if let browser = presenting as? BrowserViewController { return browser }
		if let browser = parent as? BrowserViewController { return browser }
		return nil
	}} // optionally exposes tvc as a browser if it is one ...

	required init?(coder: NSCoder) { super.init(coder: coder) } // conform to NSCoding
	override init(nibName nibNameOrNil: NSNib.Name?, bundle nibBundleOrNil: Bundle?) { super.init(nibName:nil, bundle:nil) } // calls loadView()
	override func loadView() { view = tabTable; warn() } // NIBless
	//required init!(tvc: TabViewController) {
	convenience init(tvc: TabViewController? = nil) {
		self.init(nibName: nil, bundle: nil)
		preferredContentSize = CGSize(width: 200, height: 400) //app hangs on view presentation without this!
		if let tvc = tvc {
			warn()
			representedObject = tvc.tabView
			//addChildViewController(tvc)
			//bind("tabs", toObject: tvc, withPath: "childViewControllers")
			//tvc.bind("selectedItemIndex", toObject: tabGrid, keyPath: "selected")
			//view = tabTable // obviates call to loadView()
		}
	}

	override func viewDidLoad() { // tasks to immediately follow the setting of the view property
		// For a view controller created programmatically, this method is called immediately after the loadView() method completes.
		super.viewDidLoad()

		//definesPresentationContext = true // self.view.frame will be used to size all presentedViewControllers
		//providesPresentationContextTransitionStyle = true
		//modalPresentationStyle = .OverFullScreen
		//modalTransitionStyle = .CrossDissolve // .CoverVertical | .CrossDissolve | .FlipHorizontal

		//view.backgroundColor = .clear // transparent base view
		//view.autoresizingMask = [.width, .height] //resize base view to match superview size (if any)
		//view.autoresizesSubviews = true // resize tabbed subviews based on their autoresizingMasks

		//tabTable.rowSizeStyle = .large
		//tabTable.backgroundColor = .clear

		let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(TabGridController.column))
		tabTable.headerView = nil
		column.width = 1
		tabTable.addTableColumn(column)

		tabTable.delegate = self

		tabTable.autoresizingMask = [.height, .maxXMargin] // resize height and padded-width in sync with superview/window
		//tabTable.autoresizingMask = [.height, .width] // resize height and width in sync with superview/window
		//tabTable.autoresizesSubviews = true // resize  subviews based on their autoresizingMasks
		//tabTable.frame = view.bounds
		//view.addSubview(tabTable)
		tabTable.needsDisplay = true
		warn()
		tabTable.reloadData()
	}

}

@objc extension TabGridController: NSTableViewDataSource, NSTableViewDelegate {
	func tableView(_ tableView: NSTableView, numberOfRowsInSection section: Int) -> Int {
		//section: 0
		warn(String(tabs.count))
		return tabs.count
		//return childViewControllers.count

		// section: 1 could be for addShortcuts ...
	}

	func numberOfRows(in tableView: NSTableView) -> Int {
		warn(tabs.description)
		warn(String(tabs.count))
		return tabs.count
	}

	func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
		if let colname = tableColumn?.identifier {
			return tabs[row].value(forKey: String(colname.rawValue))
		} else {
			return tabs[row]
		}
	}

/*
    func tableView(_ tableView: NSTableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> NSTableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("TableViewCell", forIndexPath: indexPath)

        let wv = tabs[indexPath.row]
        if let wti = wv.title, !wti.isEmpty { title = wti }
			else if let urlstr = wv.URL?.absoluteString, !urlstr.isEmpty { title = urlstr }
			else { title = "Untitled" }
		//title = childViewControllers[indexPath.row].title

        cell.textLabel?.text = title
        return cell
    }
*/

/*
    func tableView(_ tableView: NSTableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
		tabSelected = tabs[indexPath.row]
		//if let newVC = childViewControllers[indexPath.row] as? UIViewController { selectedViewController = newVC }
		tabList.removeFromSuperview()
    }
*/

	func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
		guard (tableColumn?.identifier)!.rawValue == TabGridController.column else { warn("identifier not found"); return nil }
		// FIXME use Key-Value-Coding advanced operators (valueForKey) to generically query tabs.@ for .url, .icon, etc
		warn(String(row))
		if let name = tabs[row].title {
			warn(tabs[row].description)
			let view = NSTextField(string: name)
			view.isEditable = false
			view.isBordered = false
			view.backgroundColor = .clear
			return view
		}
		return nil
	}

/*
	func toggleTabList() {
		if let sv = tabList.superview, sv == tabView {
			tabList.removeFromSuperview()
		} else {
			tab.insertSubview(tabList, aboveSubview: toolBar)
			view.setNeedsLayout()
			view.layoutIfNeeded()
		}
	}
*/

	func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
		warn()
		return 10.0
	}
	func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
		warn()
		return true
	}
}
