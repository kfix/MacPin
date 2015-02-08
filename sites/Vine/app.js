var delegate = {}; // our delegate to receive events from the webview app

delegate.AppFinishedLaunching = function() {
	$.newAppTabWithJS("http://vine.co", {
		'preinject':['unpreloader'], // this prevents buffering every video in a feed. If you have a fast Mac and Internet, comment out this line
		'postinject':['styler']
	}, "", "Mozilla/5.0 (iPhone; CPU iPhone OS 8_1 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Mobile/12B411"); // mobile version doesnt autoplay on mouseover
}

delegate; //return this to macpin
