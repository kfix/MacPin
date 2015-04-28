import AppKit

// https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/CollectionViews/Introduction/Introduction.html#//apple_ref/doc/uid/TP40009030
// https://developer.apple.com/library/mac/documentation/Cocoa/Reference/NSCollectionViewItem_Class/index.html
// https://developer.apple.com/library/mac/documentation/Cocoa/Reference/NSCollectionView_Class/index.html
// http://www.extelligentcocoa.org/embedding-a-nscollectionview-in-a-separate-view/
// https://developer.apple.com/library/mac/samplecode/GridMenu/Listings/ReadMe_txt.html#//apple_ref/doc/uid/DTS40010559-ReadMe_txt-DontLinkElementID_14

class TabGridIcon: NSCollectionViewItem {
	required init?(coder: NSCoder) { super.init(coder: coder) } // conform to NSCoding
	override init?(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) { super.init(nibName:nil, bundle:nil) } // calls loadView() 
	//override func loadView() { view = urlbox } // NIBless

	override var selected: Bool {
		didSet { warn("Selection changed") }
	}
}
// i think you just make WebViewcontroller inherit from NSCollectionViewItem

class TabGridView: NSCollectionView {
	func viewDidLoad() {
		//super.viewDidLoad()
		selectable = true
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
		if let browser = presentingViewController as? BrowserViewController { return browser }
		if let browser = parentViewController as? BrowserViewController { return browser }
		return nil
	}}

	required init?(coder: NSCoder) { super.init(coder: coder) } // conform to NSCoding
	override init!(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) { super.init(nibName:nil, bundle:nil) } // calls loadView() 
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
