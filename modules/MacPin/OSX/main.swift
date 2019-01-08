import Foundation
import MacPin

let app = MacPin.MacPinApp.shared //connect to CG WindowServer, always accessible as var:NSApp

app.setActivationPolicy(.regular) //lets bundle-less binaries (`make test`) get app menu and fullscreen button
let applicationDelegate = MacPin.MacPinAppDelegatePlatform()

/*
let bundleURL = NSBundle.URLForResource("MacPin", withExtension: "framework",
	subdirectory: "Frameworks", inBundleWithURL: NSBundle("MacPin").bundleURL)
let bundle = NSBundle(URL: bundleURL)
bundle.load()

let applicationDelegate = NSClassFromString("MacPin.MacPinAppDelegatePlatform")()
*/

app.delegate = applicationDelegate
app.run()
