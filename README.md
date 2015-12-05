[![Join the chat at https://gitter.im/kfix/MacPin](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/kfix/MacPin?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)
# MacPin
<center>
MacPin creates OSX & [iOS](#iOS) apps for websites & webapps, configured with JavaScript.  
![screenie](/dock_screenshot.png?raw=true)  
</center>

The Browser UI is very minimal, just a toolbar (with site tabs) that disappears in Full-Screen mode.

MacPin apps are shown in OSX's Dock, App Switcher, and Launchpad.  

Custom URL schemes can also be registered to launch a MacPin App from any other app on your Mac.  

OSX 10.11 "El Capitan" or iOS 9 is required.  

## Included Apps in the [Release](https://github.com/kfix/MacPin/releases)

#### [Hangouts.app](http://plus.google.com/hangouts): SMS/IM/Video chat client for the desktop

Google Voice and Project Fi users can [make & take phone calls and SMS/MMS messages](http://fi.google.com/about/faq/#talk-and-text-4).  
Load up can take up to 30 seconds, so be patient.

New incoming messages are shown in the system's Notification Center,  
which you can click on to reply back in the app.

Some optional goodies you can install:  
* [`Call Phone with Hangouts`](extras/Call Phone with Hangouts.workflow): (_OSX_) Call text-selected phone numbers from the context menu (right-click)
* [`AddressBookHangoutsPlugin`](extras/AddressBookHangoutsPlugin): (_OSX_) click-to-call phone number fields in Contacts and Spotlight

Several browser extensions can also make phone numbers found in webpages clickable.

When receiving a call, Hangouts.app will automatically steal focus so you can quickly answer or reject the call using the keyboard:  

* press Enter or Spacebar to accept the call
* press Escape or Backspace to decline it

Hooked URLs:
* [`sms:`](sms:5558675309)
* [`tel:`](tel:18001234567)
* [`hangouts:`](hangouts:coolguy@example.com)

#### [Messenger.app](https://www.messenger.com/hangouts): RIP *WhatsApp in your Facebook while you Facebook*

#### [Digg.app](http://digg.com/reader): A replacement for Google Reader
If you are surfing a blog in Safari and want to subscribe to it in your Digg Reader account:  

* click Safari's Sharing button ![halp](templates/xcassets/iOS/icons8/toolbar_upload.png?raw=true)
* click **Add to Shared Links**
* click **Cancel** when asked to add to Shared Links.
* `Digg.app` will popup and prompt you to subscribe if Safari found a feed or RSS metatag/mime-type.

You can further streamline this process with any of these extras:

* [Add the old RSS button back to Safari 8](http://www.red-sweater.com/blog/2624/subscribe-to-feed-safari-extension)
* [`Open Feed with Digg`](extras/Open Feed with Digg.workflow): (_OSX_) Subscribe to Feed URLs with Digg Reader from the context-menu (right-click)

Hooked URLs:
* [`feed:`](feed:http://example.com/sampleblog.xml)
* [`rss:`](rss://example.com/sampleblog.xml)

#### [Trello.app](http://trello.com): Mind-mapper and project planner
Hooked URLs:
* [`trello:`](trello:search for something)

#### [Vine.app](http://vine.co): Mobile-layout edition for the desktop

* shows a single-column stream
* does not preload any videos
* makes the controls mouse-friendly

#### [Facebook.app](https://m.facebook.com/home.php): It knows who your friends are.

* mobile edition
* ~~Facebook-in-your-facebook sidebars~~


Hooked URLs:
* [`facebook:`](facebook:search for something)

#### [CloudPebble.app](https://cloudpebble.net/ide): Use the Interweb to program your Dick Tracy watch.
[ERMAHGERD](http://knowyourmeme.com/memes/ermahgerd) ClerdPehble mah favrit smurtwerch & IDE evar!

#### [DevDocs.app](http://devdocs.io): Code documentaion browser for most front-end frameworks
Hooked URLs:
* [`devdocs:`](devdocs:someFuncName)

## Creating an App

Some call these Apps [Site-specific Browsers](https://en.wikipedia.org/wiki/Site-specific_browser) or Hybrid apps.  
They are configured with an imperative JavaScript which you need to copy-paste and customize.  

Userscripts can be added to facilitate posting to the Notification Center & recalling webapp locations/state from those posts.

Eventually, I plan to make a UI wizard to generate MacPin apps from MacPin. But for now:  

```
cd ~/src/MacPin
mkdir sites/MySite
cp sites/MacPin/app.js sites/MySite
$EDITOR sites/MySite/app.js

# find a large & square .png for the app, like an App Store image.
cp ~/Pictures/MySite.png sites/MySite/icon.png

make MySite.app
open builds/macosx-x86*/apps/MySite.app
# test, tweak, lather, repeat

make install
open -a MySite.app
```

### sample app.js
```
/*eslint-env applescript*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

var delegate = {}; // our delegate to receive events from the webview app

delegate.AppFinishedLaunching = function() {
	$.browser.tabSelected = new $.WebView({
		url: "http://vine.co",
		preinject: ['unpreloader'], // this prevents buffering every video in a feed. If you have a fast Mac and Internet, comment out this line
		postinject: ['styler'],
		agent: "Mozilla/5.0 (iPhone; CPU iPhone OS 8_1 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Mobile/12B411" // mobile version doesnt autoplay on mouseover
	});
};

delegate; //return this to macpin
```

## Hacking MacPin


Its written in Swift using WKWebView and NSTabViewController with a fully programmatic NIB-less UI layout.  
You need Xcode installed on OSX Yosemite to get the Swift compiler and Cocoa headers.  
Otherwise `$EDITOR` and `make` are your fork and knife.

```
vim execs/MacPin.swift
vim modules/MacPin/*.swift
make test.app
make SIM_ONLY=1 test.ios
```

Web Inspector can be accessed for any tab by right clicking in the page and selecting "Inspect Element" from the context menu.  
Debug builds (`make test|test.app|repl`) can be remotely inspected from Safari->Develop-><ComputerName>

The JavaScript API for app construction is undocumented and non-final.  
If you want to play with it, run any MacPin app with the `-i` argument in Terminal to get a JS console (or `make repl`).  
Safari can also remotely inspect the `JSContext` of debug builds.

Some browser functionality is currently unimplementable in WKWebKit:
* File Picker for upload via HTML4 `<input type="file">` buttons
  * Workaround: drag files onto the buttons, it works!
* Printing
  * Workaround: Tab->Save Web Archive, open in Safari and then Print.

And some things I just haven't had need to write:

* Global history
* Undo/redo tabs

#### use MacPin to make hybrid apps from existing projects
```
cd ~/src/SomeWebApp
test -d browser/SomeWebApp.com &&
  make -C ~/src/MacPin macpin_sites=$PWD/browser appdir=$PWD/hybrid xcassetdir=$PWD/hybrid $PWD/hybrid/SomeWebApp.com.app
open hybrid/SomeWebApp.com.app
```

#### iOS

Basic support has landed for generating iOS apps.  
Its kinda pointless for most of `sites/*` since native apps exist for all of them.  
But maybe you want to quickly package a React.js application for offline mobile use...


## Other WebKit browsers:

* [Firefox for iOS](https://github.com/mozilla/firefox-ios/): another Swift-based browser for iOS.
* [go-webkit2](https://github.com/sourcegraph/go-webkit2)
* [Puny Browser](https://github.com/ahungry/puny-browser)
