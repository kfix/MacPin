/*eslint-env applescript*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

var delegate = {}; // our delegate to receive events from the webview app
var trello = {
	transparent: true,
	url: $.app.pathExists($.app.resourcePath + '/trello.webarchive') ? "file://"+ $.app.resourcePath + "/trello.webarchive" : "https://trello.com",
	postinject: ['styler'], //dnd
	preinject: ['notifier'], //navigator
	subscribeTo: ['TrelloNotification', "MacPinPollStates"] //styler.js does polls
};

function search(query) {
	$.browser.tabSelected = new $.WebView({url: "https://trello.com/search?q="+query, postinject: ['styler']});
	// will prompt user to search boards/cards for phrase
}

delegate.launchURL = function(url) {
	var comps = url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift();
	switch (scheme + ':') {
		case 'trello:':
			search(addr);
			break;
		default:
	}
};

delegate.decideNavigationForURL = function(url) {
	var comps = url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift();
	switch (scheme) {
		case "http":
		case "https":
			if (!~addr.indexOf("//trello.com") &&
				!~addr.indexOf("//accounts.google.com") &&
				!~addr.indexOf("//www.youtube.com") // yt vids are usually embedded players
			) {
				$.app.openURL(url); //pop all external links to system browser
				console.log("opened "+url+" externally!");
				return true; //tell webkit to do nothing
			}
		case "about":
		case "file":
		default:
			return false;
	}
};

delegate.handleUserInputtedInvalidURL = function(query) {
	// assuming the invalid url is a search request
	search(encodeURI(query));
	return true; // tell MacPin to stop validating the URL
};

// Fluid API hook should trigger this
delegate.TrelloNotification = function(tab, msg) {
	$.app.postNotification(msg[0], msg[1], msg[2]); //(...msg) //spread it
	console.log(Date() + ' [posted user notification] ' + msg);
};

delegate.handleClickedNotification = function(from, url, msg) { $.app.openURL(url); return true; };

delegate.AppFinishedLaunching = function() {
	$.app.registerURLScheme('trello');

	if ($.launchedWithURL != '') { // app was launched with a feed url
		this.launchURL($.launchedWithURL);
		$.launchedWithURL = '';
	} else {
		$.browser.tabSelected = new $.WebView(trello);
	}
};
delegate; //return this to macpin
