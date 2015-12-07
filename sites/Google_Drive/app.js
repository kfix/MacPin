/*eslint-env applescript*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

var delegate = {}; // our delegate to receive events from the webview app
var driveTab, drive = {
	transparent:false,
	url: "https://drive.google.com",
	postinject: [],
	preinject: ['shim_html5_notifications'],
	subscribeTo: ['receivedHTML5DesktopNotification', "MacPinPollStates"]
};
var driveAlt = Object.assign({}, drive, {url: "https://drive.google.com/drive/u/1"});
driveTab = $.browser.tabSelected = new $.WebView(drive);

function search(query) {
	driveTab.evalJS( // hook app.js to perform search
		""
 	);
}

delegate.launchURL = function(url) {
	var comps = url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift();
	switch (scheme + ':') {
		case 'file':
			// prompt to do upload
			driveTab.evalJS('confirm("Upload '+addr+'?");');
			break;
		case 'googledrive:':
		case 'gdrive:':
			$.browser.unhideApp();
			$.browser.tabSelected = driveTab;
			search(decodeURI(addr));
			break;
		default:
	}
};

//this.decideNavigationForURL <- [https://accounts.google.com/ServiceLogin?service=wise&passive=1209600&continue=https://drive.google.com/drive/u/1/&followup=https://drive.google.com/drive/u/1/&emr=1&authuser=1]
delegate.decideNavigationForURL = function(url) {
	var comps = url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift();
	switch (scheme) {
		case "http":
		case "https":
			if (!~addr.indexOf("//drive.google.com") &&
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
				!~addr.indexOf("//plus.google.com") &&
				!~addr.indexOf("//0.client-channel.google.com") &&
				!~addr.indexOf("//1.client-channel.google.com") &&
				!~addr.indexOf("//2.client-channel.google.com") &&
				!~addr.indexOf("//3.client-channel.google.com") &&
				!~addr.indexOf("//4.client-channel.google.com") &&
				!~addr.indexOf("//5.client-channel.google.com") &&
				!~addr.indexOf("//6.client-channel.google.com") &&
				!~addr.indexOf("//apis.google.com") &&
				!~addr.indexOf("//0.talkgadget.google.com") &&
				!~addr.indexOf("//1.talkgadget.google.com") &&
				!~addr.indexOf("//2.talkgadget.google.com") &&
				!~addr.indexOf("//3.talkgadget.google.com") &&
				!~addr.indexOf("//4.talkgadget.google.com") &&
				!~addr.indexOf("//5.talkgadget.google.com") &&
				!~addr.indexOf("//6.talkgadget.google.com") &&
				!~addr.indexOf("//content.googleapis.com") &&
				!~addr.indexOf("//www.youtube.com") && // yt vids are usually embedded players
				!~addr.indexOf("//www.google.com/a/") &&
				!unescape(unescape(addr)).match("//accounts.google.com/")
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

delegate.AppFinishedLaunching = function() {
	$.app.registerURLScheme('gdrive');
	//$.app.registerURLScheme('googledrive'); //iOS
	$.browser.addShortcut('Google Drive', drive);
	$.browser.addShortcut('Google Drive (using secondary account)', driveAlt);

	if ($.launchedWithURL != '') { // app was launched with a search query
		driveTab.asyncEvalJS( // need to wait for app.js to load and render DOM
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
