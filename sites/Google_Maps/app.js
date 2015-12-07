/*eslint-env applescript*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

var delegate = {}; // our delegate to receive events from the webview app
var mapsTab, maps = {
	url: "https://maps.google.com",
	postinject: [],
	preinject: ['shim_html5_notifications', 'shim_html5_geolocation'],
	subscribeTo: ['receivedHTML5DesktopNotification', "MacPinPollStates", "getGeolocation", "watchGeolocation, deactivateGeolocation"],
	allowsMagnification: false // lets gmaps JS handle pinch-zooms
};
var mapsAlt = Object.assign({}, drive, {url: "https://www.google.com/maps/?authuser=1"});

// need to map pinchIn to scrollUp, pinchOut to scrollDown
// rotate?
// two-finger slide for tilt?
// https://github.com/ekryski/caress-client

mapsTab = $.browser.tabSelected = new $.WebView(maps);

function search(query) {
	// https://developers.google.com/maps/documentation/ios/urlscheme#search
	var mapper = (~$.browser.tabSelected.url.indexOf('//www.google.com/maps/')) ? $.browser.tabSelected : mapsTab;
	mapper.evalJS( // hook app.js to perform search
		"document.getElementById('searchboxinput').value = '" + query + "';" + 
		 "document.getElementById('searchbox_form').submit();"
		//"document.getElementById('searchbox_form').dispatchEvent(new Event('submit', {bubbles: true, cancelable: true}));"
		// "document.querySelector('button[aria-label=Search]').click();"
		// append '?q='+encodeURI(query)
 	);
}

delegate.launchURL = function(url) {
	var comps = url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift();
	switch (scheme + ':') {
		case 'googlemaps:':
		case 'gmaps:':
			$.browser.unhideApp();
			$.browser.tabSelected = mapsTab;
			search(decodeURI(addr));
			break;
		default:
	}
};

delegate.decideNavigationForURL = function(url) {
	var comps = url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift();
	switch (scheme) {
		case "http":
		case "https":
			if (!~addr.indexOf("//maps.google.com") &&
				!~addr.indexOf("//accounts.google.com") &&
				!~addr.indexOf("//www.google.com/a/") &&
				!~addr.indexOf("//places.google.com") &&
				!~addr.indexOf("//plus.google.com") &&
				!~addr.indexOf("//www.google.com/maps/") &&
				!~addr.indexOf("//google-latlong.blogspot.com") &&
				!~addr.indexOf("//gokml.net") &&
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

// handles all URLs drag-and-dropped into NON-html5 parts of Drive and Dock icon.
delegate.handleDragAndDroppedURLs = function(urls) {
	console.log(urls);
	for (var url of urls) {
		//$.browser.tabSelected = new $.WebView({url: url});
	}
}

delegate.receivedHTML5DesktopNotification = function(tab, note) {
	console.log(Date() + ' [posted HTML5 notification] ' + note);
	$.app.postHTML5Notification(note);
};

delegate.handleClickedNotification = function(from, url, msg) { $.app.openURL(url); return true; };

//delegate.getGeolocation = function(tab, opts) { $.app.getGeolocation(); };

//delegate.watchGeolocation = function(tab, msg) { $.app.watchGeolocation(); }; // msg = [opts, id]

//delegate.deactivateGeolocation = function(tab, id) { $.app.deactivateGeolocation(id); };

delegate.updateGeolocation = function(lat, lon) {
	// fire custom geolocation event in mapsTab (or all tabs?) with lat, lon
}

delegate.AppFinishedLaunching = function() {
	$.app.registerURLScheme('gmaps');
	//$.app.registerURLScheme('googlemaps'); //IOS?
	$.browser.addShortcut('Google Maps', maps);
	$.browser.addShortcut('Google Maps (using secondary account)', mapsAlt);
	$.browser.addShortcut('Google Maps Dev Team blog', "http://google-latlong.blogspot.com");
	$.browser.addShortcut('Classic gMaps', "http://gokml.net/maps");
	$.browser.addShortcut("Install 'Show Address in Google Maps app' service", 'file://'+$.app.resourcePath+'/'+escape('Show Address in Google Maps app.workflow'));

	if ($.launchedWithURL != '') { // app was launched with a search query
		mapsTab.asyncEvalJS( // need to wait for app.js to load and render DOM
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
