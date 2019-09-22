/*eslint-env applescript*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

var delegate = {}; // our delegate to receive events from the webview app

delegate.AppFinishedLaunching = function() {
	$.browser.tabSelected = new $.WebView({
		url: "https://web.whatsapp.com/"
	});
};

delegate; //return this to macpin