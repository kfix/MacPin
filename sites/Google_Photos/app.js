/*eslint-env applescript*/
/*eslint-env builtins*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

var photosTab, photos = {url: 'https://photos.google.com'};

var delegate = {}; // our delegate to receive events from the webview app

function search(query) {
	$.browser.tabSelected = photosTab = new $.WebView({url: "https://photos.google.com/search/"+query}); // FIXME: do this in JS
}

delegate.launchURL = function(url) {
	console.log("app.js: launching " + url);
	var comps = url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift();
	switch (scheme + ':') {
		case 'file:':
			// prompt to do upload
			photosTab.evalJS('confirm("Upload '+addr+'?");');
			break;
		case 'googlephotos:':
		case 'gphotos:':
			search(addr);
			break;
		default:
			$.browser.tabSelected = new $.WebView({url: url});
	}
};

delegate.handleUserInputtedInvalidURL = function(query) {
	// assuming the invalid url is a search request
	search(encodeURI(query));
	return true; // tell MacPin to stop validating the URL
};

// handles all URLs drag-and-dropped into NON-html5 parts of Photos and Dock icon.
delegate.handleDragAndDroppedURLs = function(urls) {
	console.log(urls);
	for (var url of urls) {
		this.launchURL(url);
		//$.browser.tabSelected = new $.WebView({url: url});
	}
	//return true;
}

delegate.AppFinishedLaunching = function() {
	$.app.registerURLScheme('googlephotos'); //IOS?
	$.app.registerURLScheme('gphotos');
	$.browser.addShortcut('Google Photos', photos);
	$.browser.addShortcut('Picasa Web Albums', 'http://picasaweb.google.com/lh/myphotos?noredirect=1');

	if ($.launchedWithURL != '') { // app was launched with a feed url
		this.launchURL($.launchedWithURL);
		$.launchedWithURL = '';
	} else {
		$.browser.tabSelected = new $.WebView(photos);
	}
};
delegate; //return this to macpin
