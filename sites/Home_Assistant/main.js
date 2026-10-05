/*eslint-env applescript*/
/*eslint-env es6*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

const {app, BrowserWindow, WebView} = require('@MacPin');
let browser = new BrowserWindow();

const ha_redir = {
	url: "https://my.home-assistant.io/redirect/overview/",
	// FIXME: bundle a local html that functions as a redirector
	useSystemAppearance: true,
};
let haTab = new WebView(ha_redir); // start loading right away

function unhideApp(tab) {
	if (tab) browser.tabSelected = tab;
	browser.unhideApp();
};

app.on("decideNavigationForClickedURL", function(url, tab, mainFrame) {
	if (!tab.allowAnyRedir) {
		tab.allowAnyRedir = false
		tab.load_url(url);
		return true;
	}
	if (
		!url.startsWith("https://homeassistant")
		&& !url.startsWith("http://homeassistant")
		&& !url.startsWith("https://my.home-assistant.io")
		) { // open all links externally except those above
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
	AppUI.browserController = browser; // make sure main app menu can get at our shortcuts
});

app.on('AppFinishedLaunching', function(launchURLs) {
	browser.tabSelected = haTab;
});
