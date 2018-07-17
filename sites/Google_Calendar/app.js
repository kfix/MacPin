/*eslint-env applescript*/
/*eslint-env es6*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";
/* TODO
 *  a .mailbundle to convert links of gdocs to gdrive:// urls: https://github.com/robertklep/quotefixformac
 *
 */

var delegate = {}; // our delegate to receive events from the webview app
var calTab, calendar = {
	transparent: false,
	url: "https://calendar.google.com"
};
var calendarAlt = Object.assign({}, calendar, {url: "https://calendar.google.com/calendar/b/1"});

/*
// ?authuser=N always overrides /u/N/ in the url!
// authuser= can also be a gmail or google apps email address

func gotoAlternateGoogleAccount(tab, acct) {
    // https://support.google.com/drive/answer/2405894?hl=en
	tab = tab || $.browser.tabSelected
	acct = acct || 1
	url.query['authuser'] = acct
	if (tab.url.test(//)) {
		tab.url = `${tab.url}/u/${acct}/`
	}
}
func gotoNextGoogleAccount(tab) {
    // https://support.google.com/drive/answer/2405894?hl=en
	tab = tab || $.browser.tabSelected
	acct = tab.uri.query["authuser"] || 0
	url.query['authuser'] = acct + 1
	}
}

// do these with JS:gapi.auth2.*?
// https://github.com/google/google-api-javascript-client/issues/13
*/

calTab = $.browser.tabSelected = new $.WebView(calendar);
/* TODO
 * bundle a local html that has uses the gapi JS client to pre-auth as a a cached authuser/user_id (prompt if no username in cache)
 * the username should be stored in localStorage and hopefully will not be shared to other apps or Safari
 * then redirect to drive landing
 *  https://accounts.google.com/ServiceLoginAuth?continue=https://drive.google.com/&Email=yourname@gmail.com
 *  http://stackoverflow.com/a/13379472/3878712
 *  https://groups.google.com/forum/#!topic/google-api-javascript-client/4dS0xL_jb24
 */

// dark mode: https://userstyles.org/styles/105045/google-drive-dark

function search(query) {
	calTab.evalJS( // hook app.js to perform search
		""
 	);
}

delegate.launchURL = function(url) {
	var comps = url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift();
	switch (scheme + ':') {
		case 'file':
			// check to see if its a JSONP .gdoc|gsheet|gslides|gsite|gtable|gmap|glink|gnote|gdraw|gform|gscript from the Google Drive sync app
			//    open{"url": "https://docs.google.com/open?id=HASH", "doc_id": "HASH", "email": "joey@example.com", "resource_id": "spreadsheet:HASH"}
			//        if so, extract the link and pop the doc 
			// else, prompt to do upload
			calTab.evalJS('confirm("Upload '+addr+'?");');
			break;
		case 'googlecalendar:':
		case 'gcal:':
		case 'gcalendar:':
			$.browser.unhideApp();
			$.browser.tabSelected = calTab;
			search(decodeURI(addr));
			break;
		default:
			$.browser.tabSelected = new $.WebView({url: url});
	}
};

var alwaysAllowRedir = false;
delegate.toggleRedirection = function(state) { alwaysAllowRedir = (state) ? true : false; };

delegate.decideNavigationForURL = function(url, tab) {
	var comps = url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift();
	switch (scheme) {
		case "http":
		case "https":
			if (alwaysAllowRedir) break; //user override
			if ((addr.startsWith("//calendar.google.com/") || addr.startsWith("//docs.google.com/")) && tab.allowAnyRedir) {
				tab.allowAnyRedir = false; // we are back home
			} else if (tab.allowAnyRedir || unescape(unescape(addr)).match("//accounts.google.com/")) {
				// we might be redirected to an external domain for a SSO-integrated Google Apps login
				// https://support.google.com/a/answer/60224#userSSO
				// process starts w/ https://accounts.google.com/ServiceLogin(Auth) and ends w/ /MergeSession
				tab.allowAnyRedir = true;
			} else if (!addr.startsWith("//calendar.google.com") &&
				!addr.startsWith("//docs.google.com") &&
				!addr.startsWith(".docs.google.com") &&
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
				!addr.startsWith("//19.client-channel.google.com") &&
				!addr.startsWith("//apis.google.com") &&
				!addr.startsWith("//contacts.google.com") &&
				!addr.startsWith("//notifications.google.com") &&
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

// handles all URLs drag-and-dropped into NON-html5 parts of Drive and Dock icon.
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

let enDarken = require('enDarken.js');

delegate.AppFinishedLaunching = function() {
	//$.app.registerURLScheme('gcalendar');
	//$.app.registerUTI('dyn.???'); // *.ical
	$.browser.addShortcut('Calendar', calendar);
	$.browser.addShortcut('Calendar (using secondary account)', calendarAlt);
	$.browser.addShortcut("Add a Google log-in", 'https://accounts.google.com/AddSession');
	$.browser.addShortcut('Use next Google log-in', ['gotoNextGoogleAccount']);
	$.browser.addShortcut('Enable Redirection to external domains', ['toggleRedirection', true]);
	$.browser.addShortcut('Disable Redirection (default)', ['toggleRedirection', false]);

	if ($.launchedWithURL != '') { // app was launched with a search query
		calTab.asyncEvalJS( // need to wait for app.js to load and render DOM
			"true;",
			5, // delay (in seconds) to wait for tab to load
			function(result) { // callback
				delegate.launchURL($.launchedWithURL);
				$.launchedWithURL = '';
			}
		);
	}

	$.browser.addShortcut('Paint It Black', [], enDarken);

};
delegate; //return this to macpin
