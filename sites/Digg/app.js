var lastLaunchedURL = '';
var delegate = {}; // our delegate to receive events from the osx app

delegate.launchURL = function(url) {
	feed = url.replace(/^(rss|feed|http|https):\/*/,'');
	feed = feed.replace(/^(rss|feed|http|https):\/*/,''); //yup, safari double-schemes correctly MIMEd URLs on its own 
	//WTF: http://en.wikipedia.org/wiki/Feed_URI_scheme
	$browser.newTab({'url':"http://digg.com/reader/search/"+encodeURIComponent(feed), 'postinject':["styler"]});
	//FIXME: eval some JS to the Digg app to directly input URL?
}

delegate.AppFinishedLaunching = function() {
	$osx.registerURLScheme('feed');
	$osx.registerURLScheme('rss');

	if (lastLaunchedURL != '') {
		delegate.launchURL(lastLaunchedURL);
		lastLaunchedURL = '';
	} else {
		$browser.newTab({'url':"http://digg.com/reader", 'postinject':["styler"]});
	}
}
delegate; //return delegate to app
