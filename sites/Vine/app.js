/*eslint-env applescript*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

var delegate = {}; // our delegate to receive events from the webview app

delegate.AppFinishedLaunching = function() {
	$.browser.addShortcut('stop tab from preloading videos', ['injectTab', 'unpreloader', "preinject please kthx"]);
	// ^ https://hoyois.github.io/safariextensions/universalextension/#html5_blocker
	$.browser.tabSelected = new $.WebView({ url: "http://vine.co" });
};

let injectTab = require('app_injectTab.js');
delegate; //return this to macpin
