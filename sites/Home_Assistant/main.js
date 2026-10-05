/*eslint-env applescript*/
/*eslint-env es6*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

const {app, BrowserWindow, WebView} = require('@MacPin');
let browser = new BrowserWindow();

const ha = {
	url: "http://homeassistant",
};
let haTab = new WebView(ha); // start loading right away

function unhideApp(tab) {
	if (tab) browser.tabSelected = tab;
	browser.unhideApp();
};

const setAgent = function(agent, tab) { tab.userAgent = agent; };
// looks like a reload has to be done for this to take full effect.

app.on("decideNavigationForClickedURL", function(url, tab, mainFrame) {
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
	browser.addShortcut('UA: default', [false], setAgent);

	AppUI.browserController = browser; // make sure main app menu can get at our shortcuts
});

app.on('AppFinishedLaunching', function(launchURLs) {
	browser.tabSelected = haTab;
});
