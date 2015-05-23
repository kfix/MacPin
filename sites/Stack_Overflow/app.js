/*eslint-env applescript*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

var delegate = {}; // our delegate to receive events from the webview app

delegate.handleUserInputtedInvalidURL = function(query) {
	// assuming the invalid url is a SO search request
	console.log(query);
	$.browser.tabSelected = new $.WebView({
		url: "http://stackoverflow.com/search?q=" + encodeURI(query),
		agent: "Mozilla/5.0 (iPhone; CPU iPhone OS 8_1 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Mobile/12B411" // mobile version uses full screen for content
	});
	return true; // tell MacPin to stop validating the URL
};

delegate.AppFinishedLaunching = function() {
	$.browser.tabSelected = new $.WebView({
		url: "http://stackoverflow.com",
		agent: "Mozilla/5.0 (iPhone; CPU iPhone OS 8_1 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Mobile/12B411" // mobile version uses full screen for content
	});
};

delegate; //return this to macpin
