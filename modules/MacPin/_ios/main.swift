import Foundation
import UIKit
import MacPin
UIApplicationMain(
    CommandLine.argc,
    CommandLine.unsafeArgv,
    NSStringFromClass(MacPinApp.self),
    NSStringFromClass(MacPinAppDelegateIOS.self)
)
// FIXME: just annotate a func with @main ?
// https://swiftrocks.com/entry-points-swift-uiapplicationmain-main
