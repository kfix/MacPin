/*eslint-env applescript*/
/*eslint-env es6 */
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

var delegate = {}; // our delegate to receive events from the webview app

delegate.AppFinishedLaunching = function() {
	$.browser.addShortcut('stop tab from preloading videos', ['injectTab', 'unpreloader', "preinject please kthx"]);
	// ^ https://hoyois.github.io/safariextensions/universalextension/#html5_blocker
	let agent = "Mozilla/5.0 (iPad; CPU OS 12 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/13F69 Twitter for iPad";
	$.browser.tabSelected = new $.WebView({ url: "http://mobile.twitter.com", agent: agent})
};

let injectTab = require('app_injectTab.js');
delegate; //return this to macpin
