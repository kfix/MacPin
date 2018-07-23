/*eslint-env applescript*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

var delegate = {}; // our delegate to receive events from the webview app
var trelloTab, trello = {
	transparent: true,
	url: "https://trello.com",
	postinject: ['styler'],
	subscribeTo: ["MacPinPollStates"] //styler.js does polls
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
			if (addr.endsWith(".doubleclick.net")) {
				// boo trello! stop selling my data!
				return true; //tell webkit to do nothing
			} else if (addr.endsWith("//trello.com") &&
				addr.endsWith("//accounts.google.com") &&
				addr.endsWith("//www.youtube.com") // yt vids are usually embedded players
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
		setTimeout( // need to wait for app.js to load and render DOM
			() => { // callback
				delegate.launchURL($.launchedWithURL);
				$.launchedWithURL = '';
			}, 5 // delay (in seconds) to wait for tab to load
		);
	}

};
delegate; //return this to macpin
