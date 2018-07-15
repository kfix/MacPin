/*eslint-env applescript*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

var delegate = {}; // our delegate to receive events from the webview app

function search(query) {
	console.log(query);
	$.browser.tabSelected = new $.WebView({
		url: "http://stackoverflow.com/search?q=" + query,
		agent: "Mozilla/5.0 (iPhone; CPU iPhone OS 8_1 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Mobile/12B411" // mobile version uses full screen for content
	});
}
delegate.launchURL = function(url) {
	console.log("app.js: launching " + url);
	var comps = url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift();
	switch (scheme + ':') {
		case 'stackoverflow:':
			search(addr);
			break;
		default:
			$.browser.tabSelected = new $.WebView({url: url});
	}
};

delegate.decideNavigationForURL = function(url) {
	var comps = url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift();
	switch (scheme) {
		case "http":
		case "https":
			if (!addr.startsWith("//stackoverflow.com") &&
				!addr.startsWith("//stackexchange.com") &&
				!addr.startsWith("//tpc.googlesyndication.com")
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

delegate.AppFinishedLaunching = function() {
	$.app.registerURLScheme('stackoverflow');
	if ($.launchedWithURL != '') { // app was launched with a feed url
		this.launchURL($.launchedWithURL);
		$.launchedWithURL = '';
	} else {
		$.browser.tabSelected = new $.WebView({
			url: "http://stackoverflow.com",
			agent: "Mozilla/5.0 (iPhone; CPU iPhone OS 8_1 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Mobile/12B411" // mobile version uses full screen for content
		});
	}
};

delegate; //return this to macpin
