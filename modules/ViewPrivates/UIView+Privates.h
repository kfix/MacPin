@import UIKit;
@interface UIView (Debug)
- (id)recursiveDescription;
- (id)_autolayoutTrace;
@end

@interface UIViewController (Debug)
- (id)_printHierarchy; // IOS8 class meth?
@end
