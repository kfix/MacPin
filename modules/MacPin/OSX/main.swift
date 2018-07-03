import Foundation

// tag the GCD's main queue so we can conditionally reroute UI-mutating calls, when triggered by JS, back to it
// http://blog.benjamin-encz.de/post/main-queue-vs-main-thread/#the-safer-solution
// https://github.com/apple/swift-evolution/blob/master/proposals/0088-libdispatch-for-swift3.md
let mainQueueKey = DispatchSpecificKey<Int>()
let mainQueueValue = 42 //DispatchSpecificKey<Int>()
// Associate a key-value pair with the main queue
DispatchQueue.main.setSpecific(key: mainQueueKey, value: mainQueueValue)

let app = MacPinApp.shared //connect to CG WindowServer, always accessible as var:NSApp
app.setActivationPolicy(.regular) //lets bundle-less binaries (`make test`) get app menu and fullscreen button
let applicationDelegate = MacPinAppDelegatePlatform()
app.delegate = applicationDelegate
app.run()
