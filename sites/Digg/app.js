/*eslint-env applescript*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

var delegate = {}; // our delegate to receive events from the osx app

var digg = { postinject: ["styler", "add_feed"], url: "http://digg.com/reader"};
var diggTab = new $.WebView(digg);

delegate.launchURL = function(url) {
	if (!~url.indexOf("rss:") || !~url.indexOf("feed:")) { // this is a rss feed from safari or osx
		//WTF: http://en.wikipedia.org/wiki/Feed_URI_scheme
		var feed = url.replace(/^(rss|feed|http|https):\/*/, ''); // strip off the scheme
		feed = feed.replace(/^(rss|feed|http|https):\/*/, ''); // strip off the second scheme that safari adds to correctly MIMEd URLs on its own
		feed = encodeURIComponent(feed);

		// redirect to digg's addFeed route, but doing so reloads diggreader.js
		var addFeedToDigg = "http://digg.com/reader/search/" + feed;
		diggTab.loadURL(addFeedToDigg);
		$.browser.tabSelected = diggTab;
		$.browser.unhideApp();

		// would like to script the addition into diggTab's running JS instead
		//readerTab.evalJS("inputFeed("+feed+", '\n');");
	} else {
		// just a plain url open
		$.browser.tabSelected = new $.WebView({url: url});
	}

	//diggTab.evalJS("location.href = '"+addFeedToDigg+"';");
	//diggTab.evalJS("history.pushState({}, 'Search for feeds to add', '"+addFeedToDigg+"');");
	// _, require, requirejs, and Backbone.Router.navigate are all present ...
	// bootstrap is used too
	// Backbone.Router.prototype.navigate("search/:feed", {trigger: true});

	//diggTab.evalJS("$('#tooltip-subscription-add-form')[0].submit();");

	//e.pubsub.fire("discovery:load_search", {feed_url: feed}),

	//diggTab.evalJS("$('#tooltip-subscription-add-form-input')[0].value = '"+feed+"';");
	//Backbone.Events.trigger("reader", "discovery:load_search")

	// Backbone.Events.trigger("discovery:load_search", {feed_url: "http://blog.github.io"})
};

delegate.AppFinishedLaunching = function() {
	$.app.registerURLScheme('feed');
	$.app.registerURLScheme('rss');

	if ($.launchedWithURL != '') { // app was launched with a feed url
		this.launchURL($.launchedWithURL);
		$.launchedWithURL = '';
	} else {
		$.browser.tabSelected = diggTab;
	}
};
delegate; //return delegate to app
