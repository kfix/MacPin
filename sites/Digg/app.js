var delegate = {}; // our delegate to receive events from the osx app

delegate.launchURL = function(url) {
	feed = url.replace(/^(rss|feed|http|https):\/*/,'');
	feed = feed.replace(/^(rss|feed|http|https):\/*/,''); //yup, safari double-schemes correctly MIMEd URLs on its own 
	//WTF: http://en.wikipedia.org/wiki/Feed_URI_scheme
	$.newAppTabWithJS("http://digg.com/reader/search/"+encodeURIComponent(feed), {'postinject':["styler"]});
}

delegate.AppFinishedLaunching = function() {
	$.registerURLScheme('feed');
	$.registerURLScheme('rss');

	if ($.lastLaunchedURL != '')
		delegate.launchURL($.lastLaunchedURL);
	else
		$.newAppTabWithJS("http://digg.com/reader", {'postinject':["styler"]});
}
delegate; //return delegate to app
