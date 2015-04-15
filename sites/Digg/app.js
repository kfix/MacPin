/*eslint-env applescript*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
/*globals $browser:false, $launchedWithURL:true, $osx:false*/
"use strict";

var delegate = {}; // our delegate to receive events from the osx app
var readerTab = $.browser.newTab({postinject: ["styler","add_feed"]});
//var readerTab = $.browser.newTab({postinject: ["styler"]});

delegate.launchURL = function(url) {
	if (!~url.indexOf("rss:") && !~url.indexOf("feed:")) {
		var feed = url.replace(/^(rss|feed|http|https):\/*/, ''); // strip off the scheme
		feed = feed.replace(/^(rss|feed|http|https):\/*/, ''); // strip off the second scheme that safari adds to correctly MIMEd URLs on its own
		feed = encodeURIComponent(feed);
		var addFeedToDigg = "http://digg.com/reader/search/" + feed;
		//WTF: http://en.wikipedia.org/wiki/Feed_URI_scheme
		//$.browser.tabSelected = $.browser.newTab({'url':addFeedToDigg, 'postinject':["styler"]});

		//readerTab.evalJS('alert("app.js redirecting:'+addFeedToDigg+'");');
		$.browser.tabSelected = readerTab;
		readerTab.loadURL(addFeedToDigg);
		$.browser.unhideApp();

		//readerTab.evalJS("inputFeed("+feed+", '\n');");
	} else {
		// just a plain url open
		$.browser.newTab({url: url});
	}


	//readerTab.evalJS("location.href = '"+addFeedToDigg+"';");
	//readerTab.evalJS("history.pushState({}, 'Search for feeds to add', '"+addFeedToDigg+"');");
	// _, require, requirejs, and Backbone.Router.navigate are all present ...
	// bootstrap is used too
	// Backbone.Router.prototype.navigate("search/:feed", {trigger: true});

	//readerTab.evalJS("$('#tooltip-subscription-add-form')[0].submit();");

	//e.pubsub.fire("discovery:load_search", {feed_url: feed}),

	//readerTab.evalJS("$('#tooltip-subscription-add-form-input')[0].value = '"+feed+"';");
	//Backbone.Events.trigger("reader", "discovery:load_search")

	// Backbone.Events.trigger("discovery:load_search", {feed_url: "http://blog.github.io"})
}

delegate.AppFinishedLaunching = function() {
	$.osx.registerURLScheme('feed');
	$.osx.registerURLScheme('rss');

	if ($.launchedWithURL != '') { // app was launched with a feed url
		this.launchURL($.launchedWithURL);
		$.launchedWithURL = '';
	} else {
		readerTab.loadURL("http://digg.com/reader");
	}
};
delegate; //return delegate to app
