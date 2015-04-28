/*eslint-env applescript*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
/*globals $browser:false, $launchedWithURL:true, $osx:false*/
"use strict";

var delegate = {}; // our delegate to receive events from the webview app
var fb = {
		preinject: ['unpreloader'], // this prevents buffering every video in a feed. If you have a fast Mac and Internet, comment out this line
		postinject: ['styler'],
		agent: "Mozilla/5.0 (iPad; CPU OS 8_1 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12B410 Safari/600.1.4"
};
var fbTab = new $.WebView(fb);

delegate.launchURL = function(url) {
	console.log("app.js: launching " + url);
	var comps = url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift();
	switch (scheme + ':') {
		//case 'facebook:?':
		case 'fb:':
		case 'facebook:':
			//fbTab.loadURL("https://m.facebook.com/home.php?soft=search");
			fbTab.loadURL("https://m.facebook.com/graphsearch/str/" + addr + "/keywords_top?ref=content_filter&source=typeahead")
			$.browser.tabSelected = fbTab;
			break;
		default:
	}
};

delegate.AppFinishedLaunching = function() {
	$.osx.registerURLScheme('facebook');
	//$.osx.registerURLScheme('fb');
	//fb: is taken http://apple.stackexchange.com/a/105047
	//`open fb://profile/afirstname.alastname` will pop that profile in safari ...

	if ($.launchedWithURL != '') { // app was launched with a feed url
		this.launchURL($.launchedWithURL);
		$.launchedWithURL = '';
	} else {
		$.browser.tabSelected = fbTab;
	}
};

delegate; //return this to macpin
