/*eslint-env applescript*/
/*eslint-env es6*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

const {app, BrowserWindow, WebView} = require('@MacPin');
let browser = new BrowserWindow();

const chat = {
	url: "https://chat.google.com",
};
let chatTab = new WebView(chat); // start loading right way, its a big Closure app

function unhideApp(tab) {
	if (tab) browser.tabSelected = tab;
	browser.unhideApp();
};

const enDarken = require('enDarken.js');

const setAgent = function(agent, tab) { tab.userAgent = agent; };
// looks like a reload has to be done for this to take full effect.

app.on("decideNavigationForClickedURL", function(url, tab, mainFrame) {
	if (
		!url.startsWith("https://accounts.google.com")
		&& !url.startsWith("https://hangouts.google.com")
		&& !url.startsWith("https://www.google.com/a/")
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
	browser.addShortcut("Log into Google Account", "https://accounts.google.com/signin");
	browser.addShortcut('Dark Mode', [], enDarken);
	browser.addShortcut('UA: default', [false], setAgent);

	AppUI.browserController = browser; // make sure main app menu can get at our shortcuts
	enDarken(chatTab);
});


app.on('AppFinishedLaunching', function(launchURLs) {
	browser.tabSelected = chatTab;
});
