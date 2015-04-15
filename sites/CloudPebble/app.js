/*eslint-env applescript*/
/*eslint-env builtins*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

var delegate = {}; // our delegate to receive events from the webview app

delegate.launchURL = function(url) {
	$.browser.conlog("app.js: launching " + url);
	var comps = url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift();
	switch (scheme + ':') {
		default:
			$.browser.newTab({}).loadURL(url);
	}
};

delegate.AppFinishedLaunching = function() {

	$.browser.addBookmark('CloudPebble IDE', 'https://cloudpebble.net/ide/');
	$.browser.newTab({url: 'https://cloudpebble.net/ide/'});
}
	
delegate; //return this to macpin
