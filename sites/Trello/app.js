/*eslint-env applescript*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
/*globals $browser:false, $launchedWithURL:true, $osx:false*/
"use strict";

var delegate = {}; // our delegate to receive events from the webview app

delegate.launchURL = function(url) {
	var comps = url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift();
	switch (scheme + ':') {
		case 'trello:':
			$.browser.newTab({url: "https://trello.com/search?q="+addr, postinject: ['styler']});
			// will prompt user to search boards/cards for phrase
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
				!~add.indexOf("//www.youtube.com") // yt vids are usually embedded players
			) {
				$.osx.openURL(url); //pop all external links to system browser
				$.browser.conlog("opened "+url+" externally!");
				return true; //tell webkit to do nothing
			}
		case "about":
		case "file":
		default:
			return false;
	}
};

delegate.TrelloNotification = function(tab, msg) {
	$.osx.postNotification(msg[0], msg[1], msg[2]); //(...msg) //spread it
	$.browser.conlog(Date() + ' [posted osx notification] ' + msg);
};

delegate.handleClickedNotification = function(from, url, msg) { $.osx.openURL(url); return true; };

delegate.AppFinishedLaunching = function() {
	$.osx.registerURLScheme('trello');

	if ($.launchedWithURL != '') { // app was launched with a feed url
		this.launchURL($.launchedWithURL);
		$.launchedWithURL = '';
	} else {
		$.browser.newTab({
			transparent: true,
			//url: "https://trello.com",
			url: "file://"+ $.osx.resourcePath + "/trello.webarchive",
			postinject: ['styler'], //dnd
			preinject: ['notifier'], //navigator
			//agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2272.104 Smafari/537.36",
			handlers: ['TrelloNotification', "MacPinPollStates"] //styler.js does polls
		}).loadURL("https://trello.com");
	}
};
delegate; //return this to macpin
