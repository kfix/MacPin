#import "TargetConditionals.h"

#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
#else
#import "NSUserNotification+Privates.h"
#endif
