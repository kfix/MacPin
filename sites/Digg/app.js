var lastLaunchedURL = '';
var delegate = {}; // our delegate to receive events from the osx app
var readerTab;

delegate.launchURL = function(url) {
	$browser.conlog("app.js: launching " + url);
	feed = url.replace(/^(rss|feed|http|https):\/*/,''); // strip off the scheme
	feed = feed.replace(/^(rss|feed|http|https):\/*/,''); // strip off the second scheme that safari adds to correctly MIMEd URLs on its own 
	feed = encodeURIComponent(feed);
	addFeedToDigg = "http://digg.com/reader/search/" + feed;
	//WTF: http://en.wikipedia.org/wiki/Feed_URI_scheme
	//$browser.newTab({'url':addFeedToDigg, 'postinject':["styler"]});

	$browser.tabSelected = readerTab;
	readerTab.loadURL(addFeedToDigg);

	//readerTab.evalJS("location.href = '"+addFeedToDigg+"';");
	//readerTab.evalJS("history.pushState({}, 'Search for feeds to add', '"+addFeedToDigg+"');");
	// _, require, requirejs, and Backbone.Router.navigate are all present ...
	// Backbone.Router.prototype.navigate("search/:feed", {trigger: true});

	//readerTab.evalJS("$('#tooltip-subscription-add-form-input')[0].value = '"+feed+"';");
	//readerTab.evalJS("$('#tooltip-subscription-add-form')[0].submit();");
}

delegate.AppFinishedLaunching = function() {
	$osx.registerURLScheme('feed');
	$osx.registerURLScheme('rss');

	readerTab = $browser.newTab({'url':"http://digg.com/reader", 'postinject':["styler"]});

	// need a app ready event
	if (lastLaunchedURL != '') {
		delegate.launchURL(lastLaunchedURL);
		lastLaunchedURL = '';
	}
}
delegate; //return delegate to app
