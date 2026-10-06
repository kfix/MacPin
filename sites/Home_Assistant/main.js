/*eslint-env applescript*/
/*eslint-env es6*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

const {app, BrowserWindow, WebView} = require('@MacPin');
let browser = new BrowserWindow();

const ha_redir = {
	url: `file://${app.resourcePath}/ha_redirector.html`,
	useSystemAppearance: true,
};
let haTab = new WebView(ha_redir); // start loading right away

function navToPage(url, tab) {
	tab.load_url(url)
};

app.on("decideNavigationForClickedURL", function(url, tab, mainFrame) {
	if (!tab.allowAnyRedir) {
		tab.allowAnyRedir = false
		tab.load_url(url);
		return true;
	}
	if (
		!url.startsWith(`file://${app.resourcePath}`)
		&& !url.startsWith("https://homeassistant")
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
	browser.addShortcut('Reset Home Assistant URL', [`file://${app.resourcePath}/ha_redirector.html#reset`], navToPage); // maybe per-tab shortcuts could be a thing...
	AppUI.browserController = browser; // make sure main app menu can get at our shortcuts
});

app.on('AppFinishedLaunching', function(launchURLs) {
	browser.tabSelected = haTab;
});
