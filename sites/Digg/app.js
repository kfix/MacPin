$.registerURLScheme('feed');
$.registerURLScheme('rss');

var delegate = {}; // our delegate to receive events from the osx app

delegate.launchURL = function(url) {
	feed = url.replace(/^(rss|feed|http|https):\/*/,'');
	feed = feed.replace(/^(rss|feed|http|https):\/*/,''); //yup, safari double-schemes correctly MIMEd URLs on its own 
	//WTF: http://en.wikipedia.org/wiki/Feed_URI_scheme
	$.newAppTabWithJS("http://digg.com/reader/search/"+encodeURIComponent(feed), {'postinject':["styler"]});
}

if ($.lastLaunchedURL != '')
	delegate.launchURL($.lastLaunchedURL);
else
	$.newAppTabWithJS("http://digg.com/reader", {'postinject':["styler"]});
$.log('Digg setup script complete');
delegate; //return this to osx
