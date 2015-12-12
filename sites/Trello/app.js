/*eslint-env applescript*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

var delegate = {}; // our delegate to receive events from the webview app
var trelloTab, trello = {
	transparent: true,
	url: "https://trello.com",
	postinject: ['styler'],
	preinject: ['shim_html5_notifications'],
	subscribeTo: ['receivedHTML5DesktopNotification', "MacPinPollStates"] //styler.js does polls
};
trelloTab = $.browser.tabSelected = new $.WebView(trello);

function search(query) {
	//$.browser.tabSelected = new $.WebView({url: trello.url + "/search?q="+query, postinject: ['styler']});
	// will prompt user to search boards/cards for phrase

	trelloTab.evalJS( // hook app.js to perform search
		//"document.getElementsByClassName('js-open-search-page')[0].click();" + // goes to dedicated search screen instead of in-header
		"document.getElementsByClassName('js-search-input')[0].focus();" +
		"document.getElementsByClassName('js-search-input')[0].value = '"+query+"';" +
		"var kev = new KeyboardEvent('keydown', { bubbles: true, cancelable: true, view: window, detail: 0, keyIdentifier: 'enter', location: KeyboardEvent.DOM_KEY_LOCATION_STANDARD, ctrlKey: false, altKey: false, shiftKey: false, metaKey: false });" +
		"document.getElementsByClassName('js-search-input')[0].dispatchEvent(kev);" // ^ fire keydown event to start search
		//"document.getElementsByClassName('js-search-suggestions-list')[0].focus();"
 	);
}

delegate.launchURL = function(url) {
	var comps = url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift();
	switch (scheme + ':') {
		case 'trello:':
			$.browser.unhideApp();
			$.browser.tabSelected = trelloTab;
			search(decodeURI(addr));
			break;
		default:
	}
};

delegate.decideNavigationForURL = function(url, webview) {
	var comps = url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift();
	switch (scheme) {
		case "http":
		case "https":
			if (!~addr.indexOf("//trello.com") &&
				!~addr.indexOf("//accounts.google.com") &&
				!~addr.indexOf("//www.youtube.com") // yt vids are usually embedded players
			) {
				$.app.openURL(url); //pop all external links to system browser
				console.log("opened "+url+" externally!");
				return true; //tell webkit to do nothing
			}
		case "about":
		case "file":
		default:
			return false;
	}
};

delegate.handleUserInputtedInvalidURL = function(query) {
	// assuming the invalid url is a search request
	search(query);
	return true; // tell MacPin to stop validating the URL
};

// handles all URLs drag-and-dropped into NON-html5 parts of Trello and Dock icon.
delegate.handleDragAndDroppedURLs = function(urls) {
	console.log(urls);
	for (var url of urls) {
		//$.browser.tabSelected = new $.WebView({url: url});
	}
}

// http://help.trello.com/article/793-receiving-trello-notifications
delegate.receivedHTML5DesktopNotification = function(tab, note) {
	console.log(Date() + ' [posted HTML5 notification] ' + note);
	$.app.postHTML5Notification(note);
};

delegate.handleClickedNotification = function(from, url, msg) { $.app.openURL(url); return true; };

delegate.overrideBG = function(bgcolor) { trelloTab.evalJS('\
	localStorage.overrideStockTrelloBlue ? delete localStorage.overrideStockTrelloBlue : localStorage.overrideStockTrelloBlue = "'+bgcolor+'";\
	localStorage.darkMode ? delete localStorage.darkMode : localStorage.darkMode = "true";\
	customizeBG();');
};
// https://github.com/MikoMagni/Trello-Monochrome-Safari/blob/master/Monochrome/trello_monochrome.css

delegate.AppFinishedLaunching = function() {
	$.app.registerURLScheme('trello');
	$.browser.addShortcut('Trello', trello);

	$.browser.addShortcut('Toggle Dark Mode', ['overrideBG', '125, 126, 244, 0.07']); // deep-purple
	// window.TrelloVersion

	if ($.launchedWithURL != '') { // app was launched with a search query
		trelloTab.asyncEvalJS( // need to wait for app.js to load and render DOM
			"true;",
			5, // delay (in seconds) to wait for tab to load
			function(result) { // callback
				delegate.launchURL($.launchedWithURL);
				$.launchedWithURL = '';
			}
		);
	}

};
delegate; //return this to macpin
