/*eslint-env applescript*/
/*eslint-env builtins*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

var devdocs = {url: 'http://devdocs.io'};

var delegate = {}; // our delegate to receive events from the webview app

function search(query) {
	$.browser.tabSelected = new $.WebView({url: "http://devdocs.io/#q="+query});
}
delegate.launchURL = function(url) {
	console.log("app.js: launching " + url);
	var comps = url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift();
	switch (scheme + ':') {
		case 'devdocs:':
			search(addr);
			break;
		default:
			$.browser.tabSelected = new $.WebView({url: url});
	}
};

delegate.handleUserInputtedInvalidURL = function(query) {
	// assuming the invalid url is a search request
	search(encodeURI(query));
	return true; // tell MacPin to stop validating the URL
};

delegate.AppFinishedLaunching = function() {
	$.app.registerURLScheme('devdocs');
	if ($.launchedWithURL != '') { // app was launched with a feed url
		this.launchURL($.launchedWithURL);
		$.launchedWithURL = '';
	} else {
		$.browser.addShortcut('DevDocs', devdocs);
		$.browser.tabSelected = new $.WebView(devdocs);
	}
};
delegate; //return this to macpin
