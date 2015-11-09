/*eslint-env applescript*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

var delegate = {}; // our delegate to receive events from the webview app

delegate.AppFinishedLaunching = function() {
	    $.browser.tabSelected = new $.WebView({
			    url: "https://web.whatsapp.com/",
		    	    agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_3) AppleWebKit/537.75.14 (KHTML, like Gecko) Version/9.0.1 Safari/7046A194A"

		        });
};

delegate; //return this to macpin