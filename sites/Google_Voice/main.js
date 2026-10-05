/*eslint-env applescript*/
/*eslint-env es6*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

const {app, BrowserWindow, WebView} = require('@MacPin');
let browser = new BrowserWindow();

const voice = {
	url: "https://voice.google.com",
	postinject: ["automators"]
};
let voiceTab = new WebView(voice); // start loading right away, its a big gClosure app

function unhideApp(tab) {
	if (tab) browser.tabSelected = tab;
	browser.unhideApp();
};

const setAgent = function(agent, tab) { tab.userAgent = agent; };
// looks like a reload has to be done for this to take full effect.

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
	return false; // proceed to .didWindowOpenForURL
});

app.on('didWindowOpenForURL', function(url, newTab, tab) {
	//console.log(`window.open() agent inheritance: ${tab.userAgent} =?> ${newTab.userAgent}`);

	if (url.length > 0 && newTab)
		console.log(`window.open(${url})`);

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
			unhideApp(); //user might have switched apps while waiting for roster to load
			browser.tabSelected = voiceTab;
			voiceTab.evalJS(`
				inputAddress('${addr}');
				makeCall();
			`);
			break;
		case 'http':
		case 'https':
			if (!url.startsWith("//accounts.google.com")) { browser.tabSelected.load_url(url); break; }
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
	browser.addShortcut("Test call to MCI ANAC", "tel:18004444444");
	browser.addShortcut('UA: default', [false], setAgent);

	AppUI.browserController = browser; // make sure main app menu can get at our shortcuts
	//browser.addShortcut('Enable Redirection to external domains', [true], toggleRedirection);
	voiceTab.allowsRecording = true;
});

app.on('AppFinishedLaunching', function(launchURLs) {
	browser.tabSelected = voiceTab;
});
