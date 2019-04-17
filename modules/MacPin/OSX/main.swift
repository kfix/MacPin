import Foundation
import AppKit
import os.log // 10.12+
let log = OSLog(subsystem: "com.github.kfix.MacPin", category: "main")
// `log stream --predicate "category=='main'"`
// `log stream --predicate "subsystem like 'com.github.kfix.MacPin'"`

//guard let mainBundle = Bundle.main else {
//	os_log("Could not find self.app", log: log, type: .error)
//	print("Could not find self.app")
//	exit(1)
//}

let mainBundle = Bundle.main
// bundle directory that contains the current executable. This method may return a valid bundle object even for unbundled apps
// lets you access the resources in the same directory as the currently running executable.
// For a running app, the main bundle offers access to the app’s bundle directory.
// For code running in a framework, the main bundle offers access to the framework’s bundle directory.

let fbundleURL: URL

print(mainBundle.executablePath ?? "no exec path")
print(mainBundle.resourcePath ?? "no resource path")
print(mainBundle.sharedFrameworksPath ?? "no frameworks path")

if let framesURL = mainBundle.sharedFrameworksURL, let localfbundleURL = mainBundle.url(forResource: "MacPin", withExtension: "framework", subdirectory: "SharedFrameworks") {
	print("found SharedFramworks/MacPin.framework!")
	fbundleURL = localfbundleURL
} else if let localfbundleURL = Bundle.url(forResource: "MacPin", withExtension: "framework", subdirectory: "Frameworks", in: mainBundle.bundleURL) {
    // The value of this property is nil of the application does not have a bundle structure.
	fbundleURL = localfbundleURL
} else if let bundleMPapp = Bundle(identifier: "com.github.kfix.MacPin") { // find MacPin.app/Frameworks/MacPin.framework

	guard let bundleURL = Bundle.url(forResource: "MacPin", withExtension: "framework", subdirectory: "Frameworks", in: bundleMPapp.bundleURL) else {
		os_log("Could not find %{public}s/MacPin.framework!", log: log, type: .error, bundleMPapp.bundleURL.absoluteString)
		print("Could not find \(bundleMPapp.bundleURL)/MacPin.framework!")
		exit(1)
	}
	fbundleURL = bundleURL

} else {
	os_log("Could not find [com.github.kfix.MacPin].app", log: log, type: .error)
	print("Could not find [com.github.kfix.MacPin].app")
	exit(1)
}

guard let framework = Bundle(url: fbundleURL) else {
	os_log("Could not load %{public}s!", log: log, type: .error, fbundleURL.absoluteString)
	print("Could not load \(fbundleURL)!")
	exit(1)
}

framework.load() // loads MacPin.framework/MacPin

guard NSClassFromString("MacPin.MacPinApp") != nil else {
	os_log("Could not find MacPinApp() in MacPin.framework!", log: log, type: .error)
	print("Could not find MacPinApp() in MacPin.framework!")
	exit(1)
}

print("initializing MacPinApp()")
let app = (NSClassFromString("MacPin.MacPinApp") as! NSApplication.Type).shared

print("initializing MacPinAppDelegateOSX()")
guard let appDelCls = NSClassFromString("MacPin.MacPinAppDelegateOSX") as? NSObject.Type, let applicationDelegate = appDelCls.init() as? NSApplicationDelegate else {
	os_log("Could not init MacPinAppDelegateOSX()!", log: log, type: .error)
	print("failed to initialize MacPinAppDelegateOSX()")
	exit(1)
}
// need to redo this in Obj-C, so the stub exec doesn't need to have swiftlibs in rpath

/*
import MacPin
let app = MacPin.MacPinApp.shared //connect to CG WindowServer, always accessible as var:NSApp
app.setActivationPolicy(.regular) //lets bundle-less binaries (`make test`) get app menu and fullscreen button
let applicationDelegate = MacPin.MacPinAppDelegatePlatform()
*/

app.delegate = applicationDelegate
app.run()
