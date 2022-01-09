import Foundation
import MacPin

#if os(macOS)
import AppKit
let app = MacPin.MacPinApp.shared
print("initializing MacPinAppDelegateOSX()")
let appDel = MacPin.MacPinAppDelegateOSX()
app.delegate = appDel
app.run()
#elseif os(iOS)
import UIKit
print("initializing MacPinAppDelegateIOS()")
UIApplicationMain(
    CommandLine.argc,
    CommandLine.unsafeArgv,
    NSStringFromClass(MacPinApp.self),
    NSStringFromClass(MacPinAppDelegateIOS.self)
)
#endif
