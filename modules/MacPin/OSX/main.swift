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

print(mainBundle.executablePath ?? "no exec path")
print(mainBundle.resourcePath ?? "no resource path")
print(mainBundle.sharedFrameworksPath ?? "no frameworks path")
print(mainBundle.privateFrameworksPath ?? "no frameworks path")

if let frames = mainBundle.sharedFrameworksPath, let MPdir = Bundle.path(forResource: "MacPin", ofType: "framework", inDirectory: frames),
	let MPframe = Bundle(path: MPdir), MPframe.load() {
		print("loaded \(MPdir)")
} else if let frames = mainBundle.privateFrameworksPath, let MPdir = Bundle.path(forResource: "MacPin", ofType: "framework", inDirectory: frames),
	let MPframe = Bundle(path: MPdir), MPframe.load() {
		print("loaded \(MPdir)")
} else if let bundleMPapp = Bundle(identifier: "com.github.kfix.MacPin"),
	let frames = bundleMPapp.sharedFrameworksPath ?? bundleMPapp.privateFrameworksPath { // find MacPin.app/(Shared)Frameworks/MacPin.framework
	guard let MPdir = Bundle.path(forResource: "MacPin", ofType: "framework", inDirectory: frames),
	let MPframe = Bundle(path: MPdir), MPframe.load() else {
		os_log("Could not find %{public}s/MacPin.framework!", log: log, type: .error, bundleMPapp.bundlePath)
		print("Could not find \(bundleMPapp.bundlePath)/MacPin.framework!")
		exit(1)
	}
	print("loaded \(MPdir)")
} else {
	os_log("Could not find [com.github.kfix.MacPin].app", log: log, type: .error)
	print("Could not find MacPin.framework locally or in [com.github.kfix.MacPin].app")
	exit(1)
}

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

app.delegate = applicationDelegate
app.run()
