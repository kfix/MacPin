# MacPin
<center>
MacPin creates pseudo-browsers managed with internal JavaScripts.  

![screenie](/dock_screenshot.png?raw=true "screen shot")  
</center>

While less featureful than Electron-based apps (no Node and Chromium here),   
they are slimmer due to nearly-exclusive use of OS-shipped components.  

```
$ du -hs build/macosx-x86_64-apple-macosx10.13/apps/{Slack,MacPin}.app/
2.0M	build/macosx-x86_64-apple-macosx10.13/apps/Slack.app/  (mostly Assets.car icons)
4.0M	build/macosx-x86_64-apple-macosx10.13/apps/MacPin.app/ (icons + 1.5MB MacPin.framework)
```

## Project Status
Uses swift 5 & WKWebView.
`sites/**/main.js` tries to support some Electron idioms.  
* federation of the applet packaging using ES6 modules [is being explored](https://github.com/kfix/MacPin/issues/31)

Apps present within a semi-featured Browser UI, having just an ["OmniBox"](https://www.chromium.org/user-experience/omnibox) and tab buttons.  

MacPin-built apps are normal .app bundles that show in the Dock, App Switcher, & Launchpad.  

They are dependent on the core MacPin.app (4.5MB) to be registered on the system, since it contains the MacPin.framework.  

Custom URL schemes can also be registered to launch a MacPin App from any other app on your Mac.  

## Included Apps in the [Release](https://github.com/kfix/MacPin/releases)

### Gooblers
* [Google Drive.app](https://drive.google.com)
* [Google Photos.app](https://photos.google.com)
* [Google Chat.app](https://chat.google.com)
* [Google Voice.app](https://voice.google.com)
* [Google Maps.app](https://www.google.com/maps)

### MetaVerses
* [Facebook.app](https://m.facebook.com/home.php) (mobile version!)
* [Messenger.app](https://www.messenger.com/hangouts)
* [WhatsApp.app](https://web.whatsapp.com)

### et cetera
* [Twitter.app](https://mobile.twitter.com) (mobile version!)
* [Slack.app](https://slack.com)
* [Trello.app](http://trello.com)
* [DevDocs.app](https://devdocs.io)
* [Stack Overflow.app](https://stackoverflow.com) (mobile version!)

## Creating an App
Some call these Apps [Site-specific Browsers](https://en.wikipedia.org/wiki/Site-specific_browser).  

"Psuedo-browser" has a better ring to it and MacPin tries to support "normal" browsing behavior,   
(address/status bars, middle-click, pop-ups) complementary to any scripts managing the app.  

```
cd ~/src/MacPin
mkdir sites/MySite
$EDITOR sites/MySite/main.js

# find a large & square .png for the app, like an App Store image.
# ideally it should have a transparent back field
cp ~/Pictures/MySite.png sites/MySite/icon.png

make test_MySite
# test, tweak, repeat

make install
open -a MySite.app
```

Work is ongoing to make editing and creating app scripts easier, without requiring Xcode:CLI tools.

## App porting issues

* DRM: Many sites (Spotify, Netflix) are using Chrome/FF only DRMs (Widevine) but Apple-built WebKit only supports FairPlay DRM.
* WebRTC: WebKit is compatible with [H264 & VP8 codecs](https://webkit.org/blog/8672/on-the-road-to-webrtc-1-0-including-vp8/), but Google Chrome is pushing hardware-unaccelerated VP9 on all fronts (incl. general `<video>`).

### sample main.js
```
/*eslint-env es6*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

const {app, WebView, BrowserWindow} = require("@MacPin");

const browser = new BrowserWindow();

app.on('AppFinishedLaunching', function() {
	browser.tabSelected = new WebView({
		url: "http://vine.co",
		transparent: true
	});
});
```

## Hacking MacPin
Building `main` branch requires macOS 11 "Big Sur" with Xcode 12.
* The built apps *should* be compatible Catalina/10.15 but there is a bug atm preventing compiling down that far.

All other branches are obsolete & archived for users locked on older macOS (hardware),  
but they will recieve no updates.  

The UI is fully-programmatic (no NIBs or storyboard) using NSTabViewController APIs to containing tab's WKWebViews.   
The AppScriptRuntime that evalutuates `main.js` scripts is cobbled together from JavaScriptCore's C and ObjC APIs.  

MacPin's UI ClassTypes are bridged to ObjC by SwiftCore and once more into Javascript space using the JSWrapperMap facility in the Apple JSC.  

Swift Package Manager and GNU Make are the actual builders of the project, Xcode and `xxcodebuild` are not used or supported.  

### basic workflow
```
vim Sources/MacPin/*.swift
vim sites/MacPin/main.js
make test.app
# CTRL-D when finished debugging ...
```

### JavaScript environment
The JavaScript API for `*.app/main.js` vaguely mimics Electron's `main.js`.  
If you want to play with it, run any MacPin app with the `-i` argument in Terminal to get a JS console (or `make repl`).  

~~Debug builds (`make test|test.app|apirepl`) can also be remotely inspected from Safari->Develop-><ComputerName>~~
* Remote Inspection appears broken ATM

### TODOs
Some things I just haven't had need to write, but wouldn't mind having:

* Global history
* Undo/redo for Tab closings
* UI wizard to generate MacPin apps from MacPin.app itself (no Command Line Tools or Xcode!)
  * maybe using JavaScript-for-Automation (JXA)?
* ReactNative, Vue/Weex, or NativeScript bindings in main.js for custom Browser UIs

## Other WebKit browsers:

* [Electrino](https://github.com/pojala/Electrino): inspiration for the revamp of MacPin's `main.js`
* [Firefox for iOS](https://github.com/mozilla/firefox-ios/): another Swift-based browser for iOS.
* [Chrome for iOS](https://chromium.googlesource.com/chromium/src/+/master/docs/ios/build_instructions.md)[*](https://chromium.googlesource.com/chromium/src.git/+/master/ios/chrome/app/main_application_delegate.mm)
* [yue](https://github.com/yue/yue-sample-apps/tree/master/browser) on [Mac](https://github.com/yue/yue/blob/master/nativeui/mac/browser_mac.mm) & [Linux](https://github.com/yue/yue/blob/master/nativeui/gtk/browser_gtk.cc)
