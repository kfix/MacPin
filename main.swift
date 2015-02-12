import MacPin

func main() {
	// gotta set these before MacPin()->NSWindow()
	NSUserDefaults.standardUserDefaults().setBool(true, forKey: "NSQuitAlwaysKeepsWindows") // insist on Window-to-Space/fullscreen persistence between launches
	NSUserDefaults.standardUserDefaults().setInteger(1, forKey: "NSInitialToolTipDelay") // get TTs in 1ms instead of 3s 
	NSUserDefaults.standardUserDefaults().setFloat(12.0, forKey: "NSInitialToolTipFontSize") 
	NSUserDefaults.standardUserDefaults().setInteger(0, forKey: "__WebInspectorPageGroupLevel1__.WebKit2InspectorStartsAttached")
	// ^ inline inspectors are flickery, fixed upstream?: https://github.com/WebKit/webkit/commit/551a9e2f7adcf9663f5d65b93a6279b1ede7f828
	// https://github.com/WebKit/webkit/blob/aefe74816c3a4db1b389893469e2d9475bbc0fd9/Source/WebKit2/UIProcess/mac/WebInspectorProxyMac.mm#L809

	let app = NSApplication.sharedApplication() //connect to CG WindowServer, always accessible as var:NSApp
	app.setActivationPolicy(.Regular) //lets bundle-less binaries (`make test`) get app menu and fullscreen button
	let applicationDelegate = MacPin()
	app.delegate = applicationDelegate
	NSAppleEventManager.sharedAppleEventManager().setEventHandler(applicationDelegate, andSelector: "handleGetURLEvent:replyEvent:", forEventClass: AEEventClass(kInternetEventClass), andEventID: AEEventID(kAEGetURL)) //handle `open url`
	app.run()
}

main()
