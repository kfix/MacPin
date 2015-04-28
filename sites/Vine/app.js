/*eslint-env applescript*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

var delegate = {}; // our delegate to receive events from the webview app

delegate.AppFinishedLaunching = function() {
	$.browser.tabSelected = new $.WebView({
		url: "http://vine.co",
		preinject: ['unpreloader'], // this prevents buffering every video in a feed. If you have a fast Mac and Internet, comment out this line
		postinject: ['styler'],
		agent: "Mozilla/5.0 (iPhone; CPU iPhone OS 8_1 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Mobile/12B411" // mobile version doesnt autoplay on mouseover
	});
};

delegate; //return this to macpin
