/*eslint-env es6*/
/*eslint-env applescript*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

var delegate = {}; // our delegate to receive events from the webview app

delegate.AppFinishedLaunching = function() {
	$.browser.tabSelected = new $.WebView({ url: "http://youtube.com/tv" });
};

delegate; //return this to macpin
