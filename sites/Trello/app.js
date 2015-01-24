$.registerURLScheme('trello');

var delegate = {}; // our delegate to receive events from the webview app

delegate.launchURL = function(url) {
	comps = url.split(':');
	scheme = comps.shift();
	addr = comps.shift();
	switch (scheme + ':') {
		case 'trello:':
			$.newAppTabWithJS("https://trello.com/search?q="+addr,{'postinject':['styler']});
			// will prompt user to search boards/cards for phrase
			break;
		default:
	}
}

delegate.decideNavigationForURL = function(url) {
	comps = url.split(':');
	scheme = comps.shift();
	addr = comps.shift();
	switch (scheme + ':') {
		default:
			if (!~addr.indexOf("//trello.com") && !~addr.indexOf("//accounts.google.com")) {
				$.sysOpenURL(url); //pop all external links to system browser
				return false;
			}
	}
}

// gotta handle cross-browser DnD
// https://developer.apple.com/library/safari/documentation/AppleApplications/Conceptual/SafariJSProgTopics/Tasks/CopyAndPaste.html#//apple_ref/doc/uid/30001234-BAJGJJAH
// https://developer.apple.com/library/safari/documentation/AppleApplications/Conceptual/SafariJSProgTopics/Tasks/DragAndDrop.html
//TypeError: null is not an object (evaluating '__indexOf.call(null!=i?i.types:void 0,"text/x-moz-url")') //chrome2trello image drag


if ($.lastLaunchedURL != '')
	 delegate.launchURL($.lastLaunchedURL);
else
	$.newAppTabWithJS("https://trello.com", {'postinject':['styler']});
$.toggleTransparency();
$.log('Trello setup script complete');
delegate; //return this to macpin
