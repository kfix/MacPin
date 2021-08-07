/*eslint-env applescript*/
/*eslint-env es6*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

const {app, BrowserWindow, WebView} = require('@MacPin');
let browser = new BrowserWindow();

const mozUA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10.14; rv:68.0) Gecko/20100101 Firefox/68.0'
const mozApp = 'Gecko/20100101 Firefox/68.0'
//    https://blog.mozilla.org/webrtc/firefox-is-now-supported-by-google-hangouts-and-meet/ should we pretend to be FireFox 60?
// https://bloggeek.me/webrtc-adapter-js/ https://github.com/webrtc/adapter
//  https://webkit.org/blog/7763/a-closer-look-into-webrtc/
const mozariUA = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_14_6) Gecko/20100101 Firefox/68.0 (KHTML, like Gecko) Version/13.0 Safari/605.1.15'
// google is looking for AppleWebKit, jsSip is looking for Safari

// (app.libraries['com.apple.WebKit'].CFBundleShortVersionString.startsWith('136') || 
let useChromeAV, useFirefoxAV;
useChromeAV = (!app.pathExists('/Library/Internet Plug-Ins/googletalkbrowserplugin.plugin') && app.doesAppExist("com.google.Chrome"))
useFirefoxAV = (!app.pathExists('/Library/Internet Plug-Ins/googletalkbrowserplugin.plugin') && app.doesAppExist("org.mozilla.firefox"))

const meet = { url: "https://meet.google.com", agent: mozariUA };
const allo = { url: "https://g.co/alloforweb", agent: mozariUA };
// https://www.androidpolice.com/2017/10/03/allo-web-adds-support-firefox-opera-ios/

// https://support.google.com/meet/answer/7353922?hl=en
// ^ HTML5 notifications should work now
// but they dont in classic hangouts???
// https://github.com/NicoSantangelo/hangouts-chrome-notifications/blob/master/content.js would need to wrap chrome.extension & chrome.runtime

const voice = {
	url: "https://voice.google.com",
	//agent: mozariUA
};
// window.JsSip. window._gv
// wss://web.voice.telephony.goog/websocket doesn't work because Goog dgaf about standards
//   https://support.google.com/voice/thread/14998073?msgid=14998073
//   https://bugs.webkit.org/show_bug.cgi?id=202095
//
//   July 2021 update!
//       I get two-way audio when using ether firefox "mozari" UA or standard Safari UA in macOS11.5 "big sur".
//       It appears they learned how to send a proper status line for their websockets:
//       $ curl -si 'https://web.voice.telephony.goog/websocket' -H 'Host: web.voice.telephony.goog' -H 'Upgrade: websocket' -H 'Connection: Upgrade' -H "Sec-WebSocket-Key: $(openssl rand -base64 16)" -H 'Origin: https://voice.google.com' -H 'Sec-WebSocket-Protocol: sip' -H 'Sec-WebSocket-Version: 13' | head -n1
//         > HTTP/1.1 101 Switching Protocols
//
//  voiceTab.evalJS(`JsSIP.debug.enable('JsSIP:*');`);

// http://voice.google.com/messages
// will get in-page RTC calling: https://productforums.google.com/forum/#!topic/voice/aI7m1PrV21Y;context-place=topicsearchin/voice/notifications
let voiceTab = new WebView(voice); // start loading right way, its a big Closure app

/*
 https://support.google.com/voice/answer/168521?hl=en&co=GENIE.Platform%3DDesktop

_gv.Tsa == window.angular.module("voice.service.NotificationSenderModule") // "true"
`new window.Notification` has a hit in the main minified @
	https://www.gstatic.com/_/voice/_/js/k=voice.voice_module_set.en_US.LRmWe0b1qLs.O/am=AAE/rt=j/d=1/rs=AJAOlGkr58y4dSXuNrjlUOOThgCPvCXA3w/m=base
tag starts with 'gv:'

*/

function unhideApp(tab) {
	if (tab) browser.tabSelected = tab;
	browser.unhideApp();
};

// there is also SIP support for GV accounts via asterisk: https://github.com/naf419/asterisk/tree/gvsip

const enDarken = require('enDarken.js');

const setAgent = function(agent, tab) { tab.userAgent = agent; };
// looks like a reload has to be done for this to take full effect.

// https://github.com/google/google-api-javascript-client/issues/397
// ^^ see that error all the time when attempting to make calls
// https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Content-Security-Policy/script-src

app.on("decideNavigationForClickedURL", function(url, tab, mainFrame) {
	if (
		!url.startsWith("https://talkgadget.google.com")
		&& !url.startsWith("https://accounts.google.com")
		&& !url.startsWith("https://hangouts.google.com")
		&& !url.startsWith("https://plus.google.com/hangouts/")
		&& !url.startsWith("https://www.google.com/a/")
		&& !url.startsWith(meet.url)
		&& !url.startsWith(allo.url)
		&& !url.startsWith(voice.url)
		&& !url.startsWith("https://g.co")
		) { // open all links externally except those above
			app.openURL(url);
			return true;
	}
	if (url.startsWith("https://www.google.com/url?q=")) {
		// stripping obnoxious google redirector
		url = decodeURIComponent(url.slice(29));
		app.openURL(url);
		return true;
	}
	if (!mainFrame) {
		console.log(`<a href="${url}" target=_blank>`);
	}
	return false;
});

//app.on('decideNavigationForMIME', function() { return false; });

app.on('decideWindowOpenForURL', function(url, tab) {
	// if tab==hangoutsTab || tab==voiceTab
	if (url.startsWith("https://plus.google.com/hangouts/_/")) { //G+ hangouts a/v chat
		if (useFirefoxAV) {
			console.log("firefoxing!")
			app.openURL(url, "org.mozilla.firefox");
			return true;
		} else if (useChromeAV) {
			app.openURL(url, "com.google.Chrome");
			return true;
		}
	}

	/*
	if (url.startsWith("//talkgadget.google.com/u/0/talkgadget/_/frame")) { // hangouts "pop-out"
		browser.tabSelected = new WebView({url: url}); // chat pop-out should change tab to new chat tab, and not change size
		return true; //doesn't work because parent webViewConfig is not passed through
	}
	*/

	return false; // proceed to .didWindowOpenForURL
});

app.on('didWindowOpenForURL', function(url, newTab, tab) {
	//console.log(`window.open() agent inheritance: ${tab.userAgent} =?> ${newTab.userAgent}`);

	if (url.length > 0 && newTab)
		console.log(`window.open(${url})`);

	if (tab==voiceTab && url.startsWith("https://plus.google.com/hangouts/_/")) { //G+ hangouts a/v chat
		//newTab.userAgent = mozUA; // will force use of WebRTC instead of vidyo plugin
		newTab.allowsRecording = true;
		newTab.loadURL(url);
		browser.tabSelected = newTab; // take focus
		return true; // macpin will return the newTab to tab's JS
	}

	return false; // macpin will popup(newTab, url) and return newTab to tab's JS
});

app.on('didWindowClose', function(tab) {
	// if you press ESC or click "cancel" on a/v hangouts url, it will try and close itself
	if (tab != voiceTab)
		browser.closeTab(tab);
		//browser.tabs = browser.tabs.filter(ft => ft != tab);
});

app.on('handleUserInputtedInvalidURL', function(query, tab) {
	if (tab == voiceTab && Number(query)) { // wut about "(555) 867-5309"
		//hangoutsTab.evalJS(`xssRoster(['inputAddress', '${query}']);`);
		delegate.launchURL(`tel:${query}`);
		return true; // tell MacPin to stop validating the URL
	}
	return false;
});

app.on('launchURL', function(url) { // app.openURL(/[sms|hangouts|tel]:.*/) calls this
	console.log("app.js: launching " + url);
	var comps = url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift().replace(/\//g, ''); // de-slashed
	switch (scheme) {
		case 'tel':
			// TODO: interpret commas as 2-sec delays and pounds as pounds
			if (app.libraries['com.apple.WebKit'].CFBundleShortVersionString.startsWith('9136') || app.pathExists('/Library/Internet Plug-Ins/googletalkbrowserplugin.plugin')) {
				// have either WebRTC'd WebKit on High Sierra or can use NPAPI GoogleVoice & Video (Vidyo) plugin in the WebView
				// window.a also seems to have a list of loaded plugins
				unhideApp(); //user might have switched apps while waiting for roster to load
				browser.tabSelected = voiceTab;
				voiceTab.evalJS(`
					window.open("https://plus.google.com/hangouts/_/?hl=en&hpn=${addr}&hip=${addr}&hnc=0");
				`);
			} else if (app.doesAppExist("org.mozilla.firefox")) {
				// use Chrome's NaCL+WebRTC Hangouts client for A/V chats ( https://webrtchacks.com/hangout-analysis-philipp-hancke/ )
				app.openURL("https://plus.google.com/hangouts/_/?hl=en&hpn="+addr+"&hip="+addr+"&hnc=0", "org.mozilla.firefox");
			} else if (app.doesAppExist("com.google.Chrome")) {
				// use Chrome's NaCL+WebRTC Hangouts client for A/V chats ( https://webrtchacks.com/hangout-analysis-philipp-hancke/ )
				app.openURL("https://plus.google.com/hangouts/_/?hl=en&hpn="+addr+"&hip="+addr+"&hnc=0", "com.google.Chrome");
			} else {
				// no plugin or chrome ...
				browser.tabSelected = new WebView({url: "https://encrypted.google.com/tools/dlpage/hangoutplugin"}); //prompt to install plugin
				app.openURL("tel:"+addr, "com.apple.facetime"); // maybe they have iPhone w/Handoff, so try call w/ facetime
			}
			break;
		case 'https':
			if (!url.startsWith("//accounts.google.com")) { browser.tabSelected.loadURL(url); break; }
		default:
			app.openURL(url);
	}
});

app.on("postedDesktopNotification", (note, tab) => {
	console.log(Date() + `[${tab.url}] posted HTML5 desktop notification: ${note.id}`);
	console.log(JSON.stringify(note));
	return false
});

app.on('handleClickedNotification', (note) => {
	console.log("App signals a clicked notification: "+ JSON.stringify(note));
	return false;
});


app.on('AppWillFinishLaunching', (AppUI) => {
	browser.addShortcut("Google Voice", voice);
	browser.addShortcut("Log into Google Account", "https://accounts.google.com/signin");
	browser.addShortcut("Install Google Voice & Video plugin", "https://encrypted.google.com/tools/dlpage/hangoutplugin");
	//    `brew cask install google-hangouts`
	//browser.addShortcut("Hangouts Meet", meet);
	//browser.addShortcut("Allo for Web", allo);
	browser.addShortcut('Dark Mode', [], enDarken);
	//browser.addShortcut("Test call to MCI ANAC", "tel:18004444444");
	browser.addShortcut('UA: Mac Firefox', [mozariUA], setAgent);
	browser.addShortcut('UA: default', [false], setAgent);

	AppUI.browserController = browser; // make sure main app menu can get at our shortcuts
	//browser.addShortcut('Enable Redirection to external domains', [true], toggleRedirection);
	enDarken(voiceTab);
	voiceTab.allowsRecording = true;
});


app.on('AppFinishedLaunching', function(launchURLs) {
	//app.registerURLScheme('sms'); // `open -a Messages.app imessage:18004444444` still works
	//app.registerURLScheme('tel'); // `open -a Facetime.app tel:18004444444` still works
	//app.registerURLScheme('googlevoice');
	// OSX Yosemite safari recognizes and launches sms and tel links to any associated app
	// https://github.com/WebKit/webkit/blob/ce77bdb93dbd24df1af5d44a475fe29b5816f8f9/Source/WebKit2/UIProcess/mac/WKActionMenuController.mm#L691
	// https://developer.apple.com/library/ios/featuredarticles/iPhoneURLScheme_Reference/Introduction/Introduction.html#//apple_ref/doc/uid/TP40007899
	browser.tabSelected = voiceTab;
});
