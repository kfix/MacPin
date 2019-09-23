# MacPin
<center>
MacPin creates pseudo-browsers managed with internal JavaScripts.  

![screenie](/dock_screenshot.png?raw=true "screen shot")  
</center>

the GitHub released apps are runnable under macOS 10.14.

While less featureful than Electron (no Node and Chromium here),   
they are [slim and fast like MacGap](https://discuss.atom.io/t/app-too-big/28845), thanks to use of macOS-shipped components.  

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

MacPin-built apps are normal .app bundles that show in the Dock (or Springboard on iOS), tabbing App Switcher, & Launchpad.  

They are dependent on the core MacPin.app (4.5MB) to be registered on the system, since it contains the MacPin.framework.  
* future work could create an easy-button "exporter" to vendor the framework

Custom URL schemes can also be registered to launch a MacPin App from any other app on your Mac.  

Building `swift5.0` branch requires macOS 10.14 "Mojave" with Xcode 10.2 installed.  

All other branches are obsolete & archived for users locked on older macOS (hardware),  
but they will recieve no updates.  

## Included Apps in the [Release](https://github.com/kfix/MacPin/releases)

### Gooblers
* [Google Drive.app](https://drive.google.com)
* [Google Photos.app](https://photos.google.com)
* [Hangouts.app](https://plus.google.com/hangouts): SMS/IM/Video chat client for the desktop
* [Google Voice.app](https://voice.google.com): SMS client for the desktop
  * calling is broken because Google is [loose with web standards](https://support.google.com/voice/thread/14998073?msgid=14998073).

### FaceHoles
* [Facebook.app](https://m.facebook.com/home.php): Mobilized for efficiency
* [Messenger.app](https://www.messenger.com/hangouts)
* [WhatsApp.app](https://web.whatsapp.com)

### et cetera
* [Slack.app](https://signin.slack.com): A hackable runtime for Slack (your co-workers will be thrilled)
* [Trello.app](http://trello.com): Mind-mapper and project planner
* [DevDocs.app](http://devdocs.io): Code documentaion browser for most front-end frameworks

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
* WebRTC: WebKit is compatible with [H264 & VP8 codecs](https://webkit.org/blog/8672/on-the-road-to-webrtc-1-0-including-vp8/), but Google Chrome is pushing hardware-unaccelerated VP9 on all fronts (incl. general <video>).

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
Its written in Swift using WKWebView and NSTabViewController with a fully programmatic NIB-less UI layout.  
The AppScriptRuntime is purely based on JavaScriptCore's C and ObjC APIs.
MacPin's UI ClassTypes are bridged to ObjC by SwiftCore and once more into Javascript space using the JSWrapperMap facility in the Apple JSC.  
You need [Xcode 10](https://developer.apple.com/xcode/) installed on macOS 12.13+ to get the Swift compiler and Cocoa headers.  
`make` & `$EDITOR` are your hammer and chisel.  

```
vim modules/MacPin/*.swift
vim sites/MacPin/main.js
make test.app
# CTRL-D when finished debugging ...
```
The JavaScript API for `*.app/main.js` vaguely mimics Electron's `main.js`.  
If you want to play with it, run any MacPin app with the `-i` argument in Terminal to get a JS console (or `make repl`).  

Debug builds (`make test|test.app|repl`) can also be remotely inspected from Safari->Develop-><ComputerName>

Some things I just haven't had need to write, but wouldn't mind having:

* Global history
* Undo/redo for Tab closings
* UI wizard to generate MacPin apps from MacPin.app itself (no Command Line Tools or Xcode!)
  * maybe using JavaScript-for-Automation (JXA)?
* ReactNative, Vue/Weex, or NativeScript bindings in main.js for custom Browser UIs

#### use MacPin to make hybrid apps from existing projects
```
cd ~/src/SomeWebApp
test -d browser/SomeWebApp.com &&
  make -C ~/src/MacPin macpin_sites=$PWD/browser appdir=$PWD/hybrid xcassetdir=$PWD/hybrid $PWD/hybrid/SomeWebApp.com.app
open hybrid/SomeWebApp.com.app
```

#### iOS
~~Basic support has landed for generating iOS apps.~~  
the iOS port has not been migrated to swift4 yet.   
I keep it in the tree because there should be no blocking issues to bring it back up to parity with macOS.  
iOS 10 has some PWA support now and macOS 10.15 will ship with UIKit-on-Mac (aka Project Catalyst aka Marzipan)
which should accelerate the compile->test dev-cycle and provide a native macOS app.

Anyhow, its kinda pointless for most of `sites/*` since native apps exist for all of them.  
But maybe you want to quickly package a React.js application for offline mobile use...  

#### can i haz LinPin? WinPin?
Ok! A stubby port running `/Lin/main.swift + AppScriptRuntime()` using a ["JSConly"](https://bugs.webkit.org/show_bug.cgi?id=154512) [build](http://constellation.github.io/blog/2016/05/02/how-to-build-javascriptcore-on-your-machine/) of JavaScriptCore  
would be a good proof of concept for new MacPin platforms to spawn from.  

[(lol, y u no like V8 google?)](https://lists.webkit.org/pipermail/webkit-dev/2018-June/030045.html)

Swift runs on Lin/Win now and so do platform-ports of JavaScriptCore and WebKit, although without supported/prebuilt libs.  

However, ObjC bindings for both Swift and the WebKit frameworks are not enabled (or possible?) outside of macOS.  
So some additional pure-Swift bindings to the WebKit C/++ APIs will be needed before implementing symmetric platform-classes  
And a some refactoring in `AppScriptRuntime.swift` to totally strip it of ObjC...  

Also NSWindow & NSTabViewController aren't cross-platform but could be straightforwardly implement equivalent UIs from MFC or GTK.  
Swift bindings to those toolkits would also be needed.  

tvPin? No [WKWebView on tvOS](https://github.com/lionheart/openradar-mirror/issues/6085) *[officially](https://github.com/jvanakker/tvOSBrowser/master/_Project)*   

## Other WebKit browsers:

* [Electrino](https://github.com/pojala/Electrino): inspiration for the revamp of MacPin's `main.js`
* [Firefox for iOS](https://github.com/mozilla/firefox-ios/): another Swift-based browser for iOS.
* [Chrome for iOS](https://chromium.googlesource.com/chromium/src/+/master/docs/ios/build_instructions.md)[*](https://chromium.googlesource.com/chromium/src.git/+/master/ios/chrome/app/main_application_delegate.mm)
* [go-webkit2](https://github.com/sourcegraph/go-webkit2)
* [Puny Browser](https://github.com/ahungry/puny-browser)
* [yue](https://github.com/yue/yue-sample-apps/tree/master/browser) on [Mac](https://github.com/yue/yue/blob/master/nativeui/mac/browser_mac.mm) & [Linux](https://github.com/yue/yue/blob/master/nativeui/gtk/browser_gtk.cc)
