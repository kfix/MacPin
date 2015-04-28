/*eslint-env applescript*/
/*eslint-env builtins*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

var cloudpebble = {url: 'https://cloudpebble.net/ide/'};

var delegate = {}; // our delegate to receive events from the webview app

delegate.launchURL = function(url) {
	console.log("app.js: launching " + url);
	var comps = url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift();
	switch (scheme + ':') {
		default:
			$.browser.tabSelected = new $.WebView({url: url});
	}
};

delegate.AppFinishedLaunching = function() {
	$.browser.addShortcut('CloudPebble IDE', cloudpebble);
	$.browser.tabSelected = new $.WebView(cloudpebble);
};
delegate; //return this to macpin
