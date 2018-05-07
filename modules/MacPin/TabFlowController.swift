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
	override init?(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) { super.init(nibName:nil, bundle:nil) } // calls loadView()
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
		//itemPrototype = NSCollectionViewItem
	}
}

class TabGridController: NSViewController {
	var tabGrid = TabGridView()
	var tabs: [TabGridIcon] = [] //browser.childViewControllers ?? (representedObject as? TabViewController)?.childViewControllers ?? []

	var browser: BrowserViewController? { get {
		if let browser = presenting as? BrowserViewController { return browser }
		if let browser = parent as? BrowserViewController { return browser }
		return nil
	}}

	required init?(coder: NSCoder) { super.init(coder: coder) } // conform to NSCoding
	override init!(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) { super.init(nibName:nil, bundle:nil) } // calls loadView()
	override func loadView() { view = tabGrid } // NIBless

	convenience init(tvc: TabViewController? = nil) {
		self.init(nibName: nil, bundle: nil)
		preferredContentSize = CGSize(width: 300, height: 300) //app hangs on view presentation without this!
		if let tvc = tvc {
			representedObject = tvc
			//bind("tabs", toObject: tvc, withPath: "childViewControllers")
			//tvc.bind("selectedItemIndex", toObject: tabGrid, keyPath: "selected")
		}
	}

}
