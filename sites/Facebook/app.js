/*eslint-env applescript*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

// Would like to fake Android Chrome 42+ and present "Push Notifications" to Notification Center
// then I can turn off OS-level Facebook integration
// https://goroost.com/try-chrome-push-notifications
// ^my Chrome.app is not signed into Google but Roost test works, so not relying on GCM??

var delegate = {}; // our delegate to receive events from the webview app
var fbTab, fb = {
		url: "https://m.facebook.com/home.php",
		preinject: ['unpreloader'], // this prevents buffering every video in a feed. If you have a fast Mac and Internet, comment out this line
		//postinject: ['styler'], agent: "Mozilla/5.0 (iPad; CPU OS 8_1 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12B410 Safari/600.1.4"
		agent: "Mozilla/5.0 (Linux; Android 5.0; SM-G900P Build/LRX21T) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/35.0.2311.38 Mobile Safari/537.36" //news-feed on Chromedroid is full-width
};
fbTab = $.browser.tabSelected = new $.WebView(fb);
$.browser.addShortcut("Facebook Home", fb);

delegate.setAgent = function(agent) { $.browser.tabSelected.userAgent = agent; };
$.browser.addShortcut('UA: Android 5 / Chrome 36', ["setAgent", "Mozilla/5.0 (Linux; Android 5.0; SM-G900P Build/LRX21T) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/36.0.2311.38 Mobile Safari/537.36"]);
// FB sets margin-* to be 0 on a bunch of elements (header jewels) for chr36

let enDarken = require(`file://${$.app.resourcePath}/enDarken.js`);
$.browser.addShortcut('Dark Mode', [], enDarken);

function search(query) {
	$.browser.tabSelected = fbTab;
	//fbTab.loadURL("https://m.facebook.com/graphsearch/str/" + query + "/keywords_top?ref=content_filter&source=typeahead")
	fbTab.evalJS(
		'document.querySelector("#search_jewel > a").click();' +
		'document.getElementById("main-search-input").value = "'+query+'";' +
		'document.getElementById("main-search-input").focus();' +
		'document.getElementById("main-search-input").dispatchEvent(new Event("input", {bubbles: true, cancelable: true}));'
	);
	// document.getElementById('main-search-input')
}

delegate.launchURL = function(url) {
	console.log("app.js: launching " + url);
	var comps = url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift();
	switch (scheme + ':') {
		//case 'facebook:?':
		case 'fb:':
		case 'facebook:':
			search(decodeURI(addr));
			break;
		default:
	}
};

delegate.handleUserInputtedInvalidURL = function(query) {
	// assuming the invalid url is a search request
	search(query);
	return true; // tell MacPin to stop validating the URL
};

delegate.AppFinishedLaunching = function() {
	$.app.registerURLScheme('facebook');
	//$.app.registerURLScheme('fb'); // claimed by AddressBookUrlForwarder.app http://apple.stackexchange.com/a/105047
	//`open -a AddressBookUrlForwarder.app fb://profile/4` to see the Zuckster in safari ...

	if ($.launchedWithURL != '') { // app was launched with a search query
		fbTab.asyncEvalJS( // need to wait for app.js to load and render DOM
			"true;",
			6, // delay (in seconds) to wait for tab to load
			function(result) { // callback
				delegate.launchURL($.launchedWithURL);
				$.launchedWithURL = '';
			}
		);
	}
};

delegate; //return this to macpin
