/*eslint-env applescript*/
/*eslint-env builtins*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

// need derivative logo: https://github.com/jupyter/design/issues/21
//   or overlay netloc on dock icon at runtime ?

var lab = {url: "https://joey-lxd:8888"};
// FIXME: source from ENV or NSUserDefaults...
// could also grab system's username and add "-lab" to it...

var delegate = {}; // our delegate to receive events from the webview app

delegate.decideNavigationForClickedURL = function(url, tab) {
	var comps = url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift(),
		subpath = addr.split('/')[1];
	switch (scheme) {
		case "http":
		case "https":
			if (!addr.startsWith("//joey-lxd:8888/")) {
				$.app.openURL(url);
				return true;
			}
	}
	return false;
};

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
	$.browser.addShortcut('JuyterLab', lab);
	$.browser.addShortcut('Dark Mode', ['enDarken']);
	$.browser.tabSelected = new $.WebView(lab);
};
$.app.loadAppScript(`file://${$.app.resourcePath}/enDarken.js`);

delegate; //return this to macpin
