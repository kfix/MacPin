/*eslint-env applescript*/
/*eslint-env builtins*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

var messenger = {url: 'https://www.messenger.com'};

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

delegate.decideNavigationForURL = function(url) {
	var comps = url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift(),
		subpath = addr.split('/')[1];
	switch (scheme) {
		case "http":
		case "https": // https://github.com/rsms/fb-mac-messenger/blob/master/Messenger/AppDelegate.mm#L591
			if (!~addr.indexOf("//www.messenger.com") ||
				(!~addr.indexOf("//www.facebook.com") &&
					(subpath == "login" || subpath == "checkpoint")
				)
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

delegate.AppFinishedLaunching = function() {
	$.browser.addShortcut('Messenger', messenger);
	$.browser.tabSelected = new $.WebView(messenger);
};
delegate; //return this to macpin
