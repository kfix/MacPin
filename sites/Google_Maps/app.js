/*eslint-env: applescript*/
/*eslint-env: es6*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

var delegate = {}; // our delegate to receive events from the webview app
var mapsTab, maps = {
	url: "https://maps.google.com",
	postinject: [],
	preinject: ['shim_html5_notifications', 'shim_html5_geolocation'],
	subscribeTo: ['receivedHTML5DesktopNotification', "MacPinPollStates"],
	allowsMagnification: false // lets gmaps JS handle pinch-zooms
};
if ($.app.platform == "OSX") maps.subscribeTo.push("MacPinPollStates", "getGeolocation", "watchGeolocation", "deactivateGeolocation");
var mapsAlt = Object.assign({}, maps, {url: "https://www.google.com/maps/?authuser=1"});
var mapsLite = Object.assign({}, maps, {url: "https://www.google.com/maps/?force=lite"});
var mapsGL = Object.assign({}, maps, {url: "https://www.google.com/maps/preview/?force=webgl"});
var myMaps = Object.assign({}, maps, {url: "https://www.google.com/maps/d/u/0"});

// need to map pinchIn to scrollUp, pinchOut to scrollDown
// rotate?
// two-finger slide for tilt?
// templates/Resources/shim_touchpad_gestures.js

mapsTab = $.browser.tabSelected = new $.WebView(maps);

function search(query, mapper) {
	// https://developers.google.com/maps/documentation/ios/urlscheme#search
	if (!mapper) mapper = $.browser.tabSelected;
	mapper.evalJS(`
		document.getElementById('searchboxinput').value = '${query}';
		document.getElementById('searchbox_form').submit();
 	`);
		//"document.getElementById('searchbox_form').dispatchEvent(new Event('submit', {bubbles: true, cancelable: true}));"
		// "document.querySelector('button[aria-label=Search]').click();"
		// append '?q='+encodeURI(query)
}

delegate.launchURL = function(url) {
	var comps = url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift();
	switch (scheme) {
		case 'googlemaps':
		case 'gmaps':
			$.browser.unhideApp();
			$.browser.tabSelected = mapsTab;
			search(decodeURI(addr));
			break;
		default:
			$.app.openURL(url);
			console.log("opened "+url+" externally!");
	}
};

delegate.decideNavigationForURL = function(url, tab) {
	var comps = url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift();
	switch (scheme) {
		case "http":
		case "https":
			if (!addr.startsWith("//maps.google.com") &&
				!addr.startsWith("//google.com/maps/") &&
				!addr.startsWith("//accounts.google.com") &&
				!addr.startsWith("//www.google.com/a/") &&
				!addr.startsWith("//places.google.com") &&
				!addr.startsWith("//plus.google.com") &&
				!addr.startsWith("//docs.google.com/picker?") &&
				!addr.startsWith("//www.google.com/maps") &&
				!addr.startsWith("//google-latlong.blogspot.com") &&
				!addr.startsWith("//gokml.net") &&
				!addr.startsWith("//www.youtube.com") // yt vids are usually embedded players
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

delegate.handleUserInputtedInvalidURL = function(query, tab) {
	// assuming the invalid url is a location search request
	// see if current tab is a mapper, if not then dispatch the original map tab.
	var comps = tab.url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift();
	var mapper = (addr && addr.startsWith('//www.google.com/maps/')) ? tab : mapsTab;
	search(query, mapper);
	return true; // tell MacPin to stop validating the URL so it wont dispatch a URL request
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

$.app.loadAppScript(`file://${$.app.resourcePath}/enDarken.js`);

delegate.AppFinishedLaunching = function() {
	$.app.registerURLScheme('gmaps');
	//$.app.registerURLScheme('googlemaps'); //IOS?
	$.browser.addShortcut('Google Maps', maps);
	$.browser.addShortcut('Google My Maps Editor', myMaps);
	$.browser.addShortcut('Google Maps Lite', mapsLite);
	$.browser.addShortcut('Google Maps +WebGL', mapsGL);
	$.browser.addShortcut('Google Maps (using secondary account)', mapsAlt);
	$.browser.addShortcut('Google Maps Dev Team blog', "http://google-latlong.blogspot.com");
	$.browser.addShortcut('Google Maps API Team blog', "http://googlegeodevelopers.blogspot.com");
	$.browser.addShortcut('Classic gMaps', "http://gokml.net/maps");
	$.browser.addShortcut("Install 'Show Address in Google Maps app' service", `http://github.com/kfix/MacPin/tree/master/extras/${escape('Show Address in Google Maps app.workflow')}`);
	$.browser.addShortcut('Dark Mode', ['enDarken']);

	// TODO: add "Open in Apple Maps", send it http://maps.apple.com lat & long
	// https://developer.apple.com/library/ios/featuredarticles/iPhoneURLScheme_Reference/MapLinks/MapLinks.html
	// GET "http://maps.apple.com/?q=test" User-Agent:"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_3)" will 302 to maps://maps.apple.com/q=?test, other UA's to http://maps.google.com/?q=test

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
