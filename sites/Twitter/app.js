/*eslint-env applescript*/
/*eslint-env es6 */
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

var delegate = {}; // our delegate to receive events from the webview app

delegate.AppFinishedLaunching = function() {
	$.browser.addShortcut('stop tab from preloading videos', ['injectTab', 'unpreloader', "preinject please kthx"]);
	// ^ https://hoyois.github.io/safariextensions/universalextension/#html5_blocker
	$.browser.tabSelected = new $.WebView({ url: "http://mobile.twitter.com", agent: "Mozilla/5.0 (iPad; CPU OS 9_3_2 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Mobile/13F69 Twitter for iPad"});
	//"Mozilla/5.0 (iPad; CPU OS 9_3_2 like Mac OS X) AppleWebKit/601.1.46 (KHTML, like Gecko) Mobile/13F69 Twitter for iPad"})
};

let {injectTab} = require(`file://${$.app.resourcePath}/app_injectTab.js`);
delegate; //return this to macpin
