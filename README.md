MacPin
=======
MacPin creates a hybrid OSX & Web app from a simple Javascript.  
It appears as a very stripped down browser with just a tab-bar (aka. "Site Specific Browser").  
You can see it in your App Switcher and it can post to Notification Center and recieve custom-scheme URLs opened on your Mac via Launch Services.

(OSX 10.10 "Yosemite" required)

Included Apps
======

* [Hangouts.app](http://plus.google.com/hangouts)
===
Chrome-less Hangouts client for your desktop.  
![screenie](/sites/Hangouts/screenshot.jpg?raw=true)
  Load up does take about 30 secs, so be patient.
  New incoming messages are shown in OSX's Notification Center, clicking them will popup the contact in the app so you can reply quickly.

```
# URLs:
sms:5558675309
tel:18001234567
hangouts:coolguy@example.com
```
  Included is an OSX Service that allows highlighting a phone number in any text and right clicking to open a Hangout Call for it.  
  Several browser extensions can also make phone numbers found in webpages clickable.

  If you have a Google Voice number linked to your Hangouts account, incoming calls will popup in the roster.
  * press Enter or Space to Accept the call
  * press ESC or Backspace to Decline it

* [Digg.app](http://digg.com/reader)  
===
  My chosen replacement for Google Reader.
```
# URLs:
feed:http://example.com/sampleblog.xml
rss://example.com/sampleblog.xml
```

  If you are surfing a blog in Safari and want to subscribe to it in your Digg Reader account:
  * click Safari's Sharing button
  * click "Add to Shared Links"
  * Answer "No" when prompted to add it your Safari Shared links.
  * If Safari found a feed or rss metatag/mime-type, it will be passed to the Digg app which will prompt you to add it to your subscriptions.  
  * PROTIP: [Add the old RSS button back to Safari 8](http://www.red-sweater.com/blog/2624/subscribe-to-feed-safari-extension)

* [Trello.app](http://trello.com)
===
Mind-mapper and project planner extraordinaire. Pinterest for geeks :-)
  ![screenie](/sites/Trello/screenshot.jpg?raw=true)
```
URLs:
trello:<search keywords>
```

Opening these urls will pop a tab with a search of your Trello boards and cards for the supplied keywords.
PROTIP: Install Alfred, Quicksilver, or Spotlight to facilitate really fast searches.

* [Vine.app](http://vine.co)
===
It shows the mobile version of the site and does not preload any videos,  
so you can choose how to spend your bandwidth & time.

Creating an App
====
```
mkdir sites/MySite
vim sites/MySite/app.js
# look at other sites/*/app.js and WebAppScriptExports for available commands

make
open apps/MySite.app
# test, tweak, repeat

make install
open -a MySite.app

#to customize the icon, find a suitable .png or .icns and place it in icons/ and remake
cp ~/Pictures/MySite.png icons/
```

Develop
===
It's mostly written in Swift using WKWebView and NSTabViewController.
No NIBs, fully programmatic UI layout.
You need Xcode installed on OSX Yosemite to get the Swift compiler and Cocoa headers.
```
vim webview.swift
make test
```
Web Inspector is available in the app, and remote debugging via Safari too when debug= is set in the Makefile.

Check out https://github.com/mozilla/firefox-ios/ to see a another Swift-based browser for iOS.
