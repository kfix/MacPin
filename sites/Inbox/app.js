/*eslint-env applescript*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

var delegate = {}; // our delegate to receive events from the webview app
var inboxTab, inbox = {
	transparent:false,
	url: "https://inbox.google.com",
	postinject: [],
	preinject: ['shim_html5_notifications'],
	subscribeTo: ['receivedHTML5DesktopNotification', "MacPinPollStates"]
};
var inboxAlt = Object.assign({}, inbox, {url: "https://inbox.google.com/u/1"});
inboxTab = $.browser.tabSelected = new $.WebView(inbox);

function search(query) {
	inboxTab.evalJS( // hook app.js to perform search
		"" 
 	);
	// document.querySelector('input[aria-label="Search"]').value = query
	// https://inbox.google.com/search/stuff%20find?pli=1
}

delegate.launchURL = function(url) {
	var comps = url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift();
	switch (scheme + ':') {
		case 'googleinbox:':
		case 'ginbox:':
			$.browser.unhideApp();
			$.browser.tabSelected = inboxTab;
			search(decodeURI(addr));
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
			if (!~addr.indexOf("//inbox.google.com") &&
				!~addr.indexOf("//accounts.google.com") &&
				!~addr.indexOf("//docs.google.com") &&
				!~addr.indexOf(".docs.google.com") &&
				!~addr.indexOf("//clients6.google.com") &&
				!~addr.indexOf("//clients5.google.com") &&
				!~addr.indexOf("//clients4.google.com") &&
				!~addr.indexOf("//clients3.google.com") &&
				!~addr.indexOf("//clients2.google.com") &&
				!~addr.indexOf("//clients1.google.com") &&
				!~addr.indexOf("//clients.google.com") &&
				!~addr.indexOf("//0.client-channel.google.com") &&
				!~addr.indexOf("//talkgadget.google.com") &&
				!~addr.indexOf("//plus.google.com") &&
				!~addr.indexOf("//www.google.com/tools/feedback/content_frame") &&
				!~addr.indexOf("//www.youtube.com") // yt vids are usually embedded players
			) {
				$.app.openURL(url); //pop all external links to system browser
				console.log("opened "+url+" externally!");
				return true; //tell webkit to do nothing
			}
		//case "mailto":
		// break out params
		case "about":
		default:
			return false;
	}
};

delegate.handleUserInputtedInvalidURL = function(query) {
	// assuming the invalid url is a search request
	search(query);
	return true; // tell MacPin to stop validating the URL
};

// handles all URLs drag-and-dropped into NON-html5 parts of Inbox and Dock icon.
delegate.handleDragAndDroppedURLs = function(urls) {
	console.log(urls);
	for (var url of urls) {
		this.launchURL(url);
		//$.browser.tabSelected = new $.WebView({url: url});
	}
}

delegate.receivedHTML5DesktopNotification = function(tab, note) {
	console.log(Date() + ' [posted HTML5 notification] ' + note);
	$.app.postHTML5Notification(note);
};

delegate.handleClickedNotification = function(from, url, msg) { $.app.openURL(url); return true; };

delegate.AppFinishedLaunching = function() {
	$.app.registerURLScheme('ginbox');
	//$.app.registerURLScheme('mailto');
	$.browser.addShortcut('Inbox by Gmail', inbox);
	$.browser.addShortcut('Inbox by Gmail (using secondary account)', inboxAlt);

	if ($.launchedWithURL != '') { // app was launched with a search query
		inboxTab.asyncEvalJS( // need to wait for app.js to load and render DOM
			"true;",
			5, // delay (in seconds) to wait for tab to load
			function(result) { // callback
				delegate.launchURL($.launchedWithURL);
				$.launchedWithURL = '';
			}
		);
	}

};
delegate; //return this to macpin
