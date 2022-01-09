import Foundation
import AppKit

#if canImport(os)
	import os.log
	// `log stream --predicate "category=='main'"`
	// `log stream --predicate "subsystem like 'com.github.kfix.MacPin'"`

	func warn(_ msg: String) {
		if #available(OSX 10.12, *) {
			let log = OSLog(subsystem: "com.github.kfix.MacPin", category: "main")
			os_log("%{public}s", log: log, type: .error, msg)
		}
		print(msg)
	}
	// import os.signpost
	// let signpostID = OSSignpostID(log: log)
#else
	func warn(_ msg: String) { print(msg); }
#endif

func loadMPframework(fromBundle: Bundle, frameworkName: String = "MacPin") -> Bool {
	if let frames = fromBundle.sharedFrameworksPath, let MPdir = Bundle.path(forResource: frameworkName, ofType: "framework", inDirectory: frames),
		let MPframe = Bundle(path: MPdir), MPframe.load() {
			print("loaded \(MPdir)")
			return true
	} else if let frames = fromBundle.privateFrameworksPath, let MPdir = Bundle.path(forResource: frameworkName, ofType: "framework", inDirectory: frames),
		let MPframe = Bundle(path: MPdir), MPframe.load() {
			print("loaded \(MPdir)")
			return true
	}
	return false
}

let mainBundle = Bundle.main
// bundle directory that contains the current executable. This method may return a valid bundle object even for unbundled apps
// lets you access the resources in the same directory as the currently running executable.
// For a running app, the main bundle offers access to the app’s bundle directory.
// For code running in a framework, the main bundle offers access to the framework’s bundle directory.

print(mainBundle.executablePath ?? "no exec path")
print(mainBundle.resourcePath ?? "no resource path")
print(mainBundle.sharedFrameworksPath ?? "no frameworks path")
print(mainBundle.privateFrameworksPath ?? "no frameworks path")

if let sharedURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "com.github.kfix.MacPin") {
	// https://developer.apple.com/documentation/bundleresources/entitlements/com_apple_security_application-groups
	// print("\(sharedURL)") // could load self-modified, user customized, main.js's from here
}
	
if !loadMPframework(fromBundle: mainBundle) {
	// not found locally, so search for the LaunchServices-registered MacPin.app
	// https://github.com/chromium/chromium/blob/master/chrome/app_shim/chrome_main_app_mode_mac.mm
	// https://github.com/chromium/chromium/blob/master/chrome/browser/apps/app_shim/app_shim_host_manager_mac.mm

	if let MPappPath = NSWorkspace.shared.absolutePathForApplication(withBundleIdentifier: "com.github.kfix.MacPin.MacPin"),
	let MPappBundle = Bundle(path: MPappPath), loadMPframework(fromBundle: MPappBundle) {
		// Chromium Web Apps just use dlopen: https://github.com/chromium/chromium/blob/master/chrome/app_shim/app_mode_loader_mac.mm#L139
		// and parses info.plists itself: https://github.com/chromium/chromium/blob/master/chrome/common/mac/app_mode_chrome_locator.mm
		print("loaded \(MPappPath)!!")
	} else {
		warn("Could not find & load MacPin.framework locally or from [com.github.kfix.MacPin.MacPin].app")
	}
}

guard NSClassFromString("MacPin.MacPinApp") != nil else {
	warn("Could not find MacPinApp() in MacPin.framework!")
	exit(1)
}

print("initializing MacPinApp()")
let app = (NSClassFromString("MacPin.MacPinApp") as! NSApplication.Type).shared

print("initializing MacPinAppDelegateOSX()")
guard let appDelCls = NSClassFromString("MacPin.MacPinAppDelegateOSX") as? NSObject.Type, let applicationDelegate = appDelCls.init() as? NSApplicationDelegate else {
	warn("failed to initialize MacPinAppDelegateOSX()")
	exit(1)
}

app.delegate = applicationDelegate
app.run()
