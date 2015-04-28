[![Join the chat at https://gitter.im/kfix/MacPin](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/kfix/MacPin?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)
# MacPin
MacPin creates a Mac OSX App shell for websites & webapps from a short JavaScript you provide.  
Some call these Apps [Site-specific Browsers](https://en.wikipedia.org/wiki/Site-specific_browser) or Hybrid apps.  

The Browser UI is very minimal, just a tab-bar which disappears in Full-Screen mode, leaving only the site content.   

MacPin apps sit in your Dock, App Switcher, and Launchpad.  
Userscripts can be injected to facilitate posting to the Notification Center & recalling webapp locations/state from those posts.   

Custom URL schemes can also be registered to launch your App from any other app on your Mac.  

OSX 10.10 "Yosemite" is required.  

A suite of apps are prebuilt for download in the GitHub release.

## Included Apps

#### [Hangouts.app](http://plus.google.com/hangouts): SMS/IM/Video chat client for the desktop 
![screenie](/sites/Hangouts/screenshot.jpg?raw=true)
Google Voice and Project Fi users can [make & take phone calls and SMS/MMS messages](http://fi.google.com/about/faq/#talk-and-text-4).  
Load up can take up to 30 seconds, so be patient.   

New incoming messages are shown in OSX's Notification Center,  
which you can click on to reply back in the app.

Under [extras/](/sites/Hangouts/extras) you'll find:  

* `Call via Hangouts.service`: enables selecting and right-clicking a phone number in any App's text to make a Hangout Call
* `HangoutsAddressBookPlugin`: allows click-to-call from Contacts.app phone number fields and Maps results in Spotlight searches

Several browser extensions can also make phone numbers found in webpages clickable.

When receiving a call, Hangouts.app will automatically steal focus so you can quickly answer or reject the call using the keyboard:  

* press Enter or Space to accept the call
* press Escape or Backspace to decline it

Custom URLs: [SMS](sms:5558675309) [Call](tel:18001234567) [IM](hangouts:coolguy@example.com)

#### [Digg.app](http://digg.com/reader): A replacement for Google Reader
If you are surfing a blog in Safari and want to subscribe to it in your Digg Reader account:  

* click Safari's Sharing button
* click "Add to Shared Links"
* Answer "No" when prompted to add it your Safari Shared links.
* If Safari found a feed or rss metatag/mime-type, it will be passed to Digg.app which will prompt you to add it to your subscriptions.  
* PROTIP: [Add the old RSS button back to Safari 8](http://www.red-sweater.com/blog/2624/subscribe-to-feed-safari-extension)

Custom URLs: [feed](feed:http://example.com/sampleblog.xml) [rss](rss://example.com/sampleblog.xml)

#### [Trello.app](http://trello.com): Mind-mapper and project planner
![screenie](/sites/Trello/screenshot.jpg?raw=true)  
Custom URLs: [search your trello for something](trello:search for something)

#### [Vine.app](http://vine.co): Mobile-layout edition for the desktop
Vine has a webpage now, but it is a grid layout and PRECACHES 100% of ALL OF THE VIDEOS on Safari.   
Vine.app shows the mobile stream layout and does not preload any videos.  
Also, it makes the controls mouse-friendly.  

#### [Facebook.app](https://m.facebook.com/home.php): It knows who your friends are.
The mobile version, which differs from the Desktop webpage:

* ~~Facebook-in-your-facebook sidebars~~


Custom URLs: [search your Facebook for something](facebook:search for something)

#### [CloudPebble.app](https://cloudpebble.net/ide): Use the Internet to program your Dick Tracy watch.
[ERMAHGERD](http://knowyourmeme.com/memes/ermahgerd) ClerdPehble mah favrit smurtwerch & IDE evar!


## Creating an App

```
mkdir sites/MySite
vim sites/MySite/app.js
# peruse sites/*/app.js for available commands

make
open apps/MySite.app
# test, tweak, lather, repeat

# find a suitable .png or .icns for the app
cp ~/Pictures/MySite.png icons/
# else WebKit.icns will be used

make install
open -a MySite.app

```

## Hacking MacPin

Its written in Swift using WKWebView and NSTabViewController with a fully programmatic NIB-less UI layout.  
You need Xcode installed on OSX Yosemite to get the Swift compiler and Cocoa headers.  
Otherwise `$EDITOR` and `make` are your fork and knife.

```
vim execs/MacPin.swift
vim modules/MacPin/*.swift
make test.app
```

Web Inspector can be accessed for any tab by right clicking in the page and selecting "Inspect Element" from the context menu.  
Debug builds (`make test|test.app|repl`) can be remotely inspected from Safari->Develop-><ComputerName> 

The JavaScript API for app construction is undocumented and non-final.  
If you want to play with it, run any MacPin app with the `-i` argument in Terminal to get a JS console (or `make repl`).  
Safari can also remotely inspect the `JSContext` of debug builds. 

Some browser functionality is inoperative & unimplementable due to WKWebKit's immaturity:

* File Uploads via File Picker (HTML5 drag & drop is working)
* Geolocation
* Printing

And some things I just haven't had need to write:   

* Global history
* Undo/redo tabs

Independent repos for MacPin-based apps can also be made (examples pending). 

## Other WebKit browsers:

* [Firefox for iOS](https://github.com/mozilla/firefox-ios/): another Swift-based browser for iOS.
* [go-webkit2](https://github.com/sourcegraph/go-webkit2)
* [Puny Browser](https://github.com/ahungry/puny-browser)
