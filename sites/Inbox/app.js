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

var alwaysAllowRedir = false;

delegate.decideNavigationForURL = function(url, tab) {
	var comps = url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift();
	switch (scheme) {
		case "http":
		case "https":
			if (alwaysAllowRedir) break; //user override
			if ((addr.startsWith("//inbox.google.com/") || addr.startsWith("//mail.google.com/")) && tab.allowAnyRedir) {
				tab.allowAnyRedir = false; // we are back home
			} else if (tab.allowAnyRedir || unescape(unescape(addr)).match("//accounts.google.com/")) {
				// we might be redirected to an external domain for a SSO-integrated Google Apps login
				// https://support.google.com/a/answer/60224#userSSO
				// process starts w/ https://accounts.google.com/ServiceLogin(Auth) and ends w/ /MergeSession
				tab.allowAnyRedir = true;
			} else if (!addr.startsWith("//inbox.google.com") &&
				!addr.startsWith("//docs.google.com") &&
				!addr.startsWith(".docs.google.com") &&
				!addr.startsWith("//mail.google.com") &&
				!addr.startsWith(".mail.google.com") &&
				!addr.startsWith("//clients6.google.com") &&
				!addr.startsWith("//clients5.google.com") &&
				!addr.startsWith("//clients4.google.com") &&
				!addr.startsWith("//clients3.google.com") &&
				!addr.startsWith("//clients2.google.com") &&
				!addr.startsWith("//clients1.google.com") &&
				!addr.startsWith("//clients.google.com") &&
				!addr.startsWith("//plus.google.com") &&
				!addr.startsWith("//hangouts.google.com") &&
				!addr.startsWith("//cello.client-channel.google.com") &&
				!addr.startsWith("//0.client-channel.google.com") &&
				!addr.startsWith("//1.client-channel.google.com") &&
				!addr.startsWith("//2.client-channel.google.com") &&
				!addr.startsWith("//3.client-channel.google.com") &&
				!addr.startsWith("//4.client-channel.google.com") &&
				!addr.startsWith("//5.client-channel.google.com") &&
				!addr.startsWith("//6.client-channel.google.com") &&
				!addr.startsWith("//apis.google.com") &&
				!addr.startsWith("//0.talkgadget.google.com") &&
				!addr.startsWith("//1.talkgadget.google.com") &&
				!addr.startsWith("//2.talkgadget.google.com") &&
				!addr.startsWith("//3.talkgadget.google.com") &&
				!addr.startsWith("//4.talkgadget.google.com") &&
				!addr.startsWith("//5.talkgadget.google.com") &&
				!addr.startsWith("//6.talkgadget.google.com") &&
				!addr.startsWith("//0.docs.google.com") &&
				!addr.startsWith("//1.docs.google.com") &&
				!addr.startsWith("//2.docs.google.com") &&
				!addr.startsWith("//3.docs.google.com") &&
				!addr.startsWith("//4.docs.google.com") &&
				!addr.startsWith("//5.docs.google.com") &&
				!addr.startsWith("//6.docs.google.com") &&
				!addr.startsWith("//7.docs.google.com") &&
				!addr.startsWith("//8.docs.google.com") &&
				!addr.startsWith("//9.docs.google.com") &&
				!addr.startsWith("//content.googleapis.com") &&
				!addr.startsWith("//www.youtube.com") && // yt vids are usually embedded players
				!addr.startsWith("//youtube.googleapis.com/embed/") &&
				!addr.startsWith("//www.google.com/a/") &&
				!addr.startsWith("//myaccount.google.com") &&
				!addr.startsWith("//www.google.com/tools/feedback/content_frame") &&
				!addr.startsWith("//www.google.com/settings")
			) {
				$.app.openURL(url); //pop all external links to system browser
				console.log("opened "+url+" externally!");
				return true; //tell webkit to do nothing
			}
		//case "mailto":
		// break out params
		case "about":
		case "file":
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

delegate.toggleRedirection = function(state) { alwaysAllowRedir = (state) ? true : false; };

delegate.AppFinishedLaunching = function() {
	$.app.registerURLScheme('ginbox');
	//$.app.registerURLScheme('mailto');
	$.browser.addShortcut('Inbox by Gmail', inbox);
	$.browser.addShortcut('Inbox by Gmail (using secondary account)', inboxAlt);
	$.browser.addShortcut('Enable Redirection to external domains', ['toggleRedirection', true]);

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

	$.app.loadAppScript(`file://${$.app.resourcePath}/enDarken.js`);
	$.browser.addShortcut('Paint It Black', ['enDarken']);


};
delegate; //return this to macpin
