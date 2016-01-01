let app = MacPinApp.sharedApplication() //connect to CG WindowServer, always accessible as var:NSApp
app.setActivationPolicy(.Regular) //lets bundle-less binaries (`make test`) get app menu and fullscreen button
let applicationDelegate = MacPinAppDelegatePlatform()
app.delegate = applicationDelegate
app.run()
