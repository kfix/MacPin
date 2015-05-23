#import "TargetConditionals.h"
#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
#import "UIView+Privates.h"
#else 
#import "NSView+Privates.h"
#endif
