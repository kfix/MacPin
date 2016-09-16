/*eslint-env applescript*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

var delegate = {}; // our delegate to receive events from the osx app

var digg = { postinject: ["styler"], url: "http://digg.com/reader" };
var diggTab = new $.WebView(digg);

function getAddFeedLink(url) {
	if (!~url.indexOf("rss:") || !~url.indexOf("feed:")) { // this is a rss feed from safari or osx
		//WTF: http://en.wikipedia.org/wiki/Feed_URI_scheme
		var feed = url.replace(/^(rss|feed):\/*/, ''); // strip off bogus schemes
		feed = feed.replace(/^(rss|feed):\/*/, ''); // do it again Sam....sometimes its added twice by Safari or OSX?
		return feed;
	}
	return false;
}

function addFeedViaJS(feedUrl) {
	return "document.getElementById('tooltip-subscription-add-form-input').value = '"+feedUrl+"';" +
		"document.getElementById('tooltip-subscription-add-form').dispatchEvent(new Event('submit', {bubbles: true, cancelable: true}));"
}

// handles cmd-line and LaunchServices openURL()s
delegate.launchURL = function(url) {
	var addURL;
	if (addURL = getAddFeedLink(url)) {
		$.browser.tabSelected = diggTab;
		$.browser.unhideApp();
		diggTab.evalJS(addFeedViaJS(addURL));
	} else {
		$.browser.tabSelected = new $.WebView({url: url});
	}
};

// handles all URLs drag-and-dropped into MacPin.
delegate.handleDragAndDroppedURLs = function(urls) {
	console.log(urls);
	for (var url of urls) {
		var tab = new $.WebView({url: url});
		$.browser.pushTab(tab); // needs to be made visible in order to evalJS on it.
		// search for RSS tags and send to DiggTab if found
		tab.asyncEvalJS("if ( (feed = document.head.querySelector('link[type*=rss]')) ||" +
			" (feed = document.head.querySelector('link[type*=atom]')) ) { feed.href } else { false };",
			2, // delay (in seconds) to wait for tab to load
			function(result) { // callback
				var addURL;
				if (result && (addURL = getAddFeedLink(result))) diggTab.evalJS(addFeedViaJS(addURL));
				tab.close(); //FIXME doesn't do diddly
			}
		);
	}
	return true; // bypass WKWebView's default handler
};

delegate.addCurrentPageToFeeds = function() { delegate.launchURL('feed:' + $.browser.tabSelected.url); }

delegate.AppFinishedLaunching = function() {
	$.app.registerURLScheme('feed');
	$.app.registerURLScheme('rss');

	$.browser.addShortcut("Digg Reader", digg);
	$.browser.addShortcut("Get OSX service for text-selected feeds", "http://github.com/kfix/MacPin/tree/master/extras/Open Feed with Digg.workflow");
	$.browser.addShortcut("Add current page to Digg Reader feeds", ["addCurrentPageToFeeds"]);
	$.browser.addShortcut('Dark Mode', ['enDarken']);

	$.browser.tabSelected = diggTab;

	if ($.launchedWithURL != '') { // app was launched with a feed url
		diggTab.asyncEvalJS( // need to wait for reader.js to load and render DOM
			"true;",
			5, // delay (in seconds) to wait for tab to load
			function(result) { // callback
				delegate.launchURL($.launchedWithURL);
				$.launchedWithURL = '';
			}
		);
	}
};
delegate; //return delegate to app
