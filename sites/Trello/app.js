var delegate = {}; // our delegate to receive events from the webview app

delegate.launchURL = function(url) {
	comps = url.split(':');
	scheme = comps.shift();
	addr = comps.shift();
	switch (scheme + ':') {
		case 'trello:':
			$.newAppTabWithJS("https://trello.com/search?q="+addr,{'postinject':['styler','dnd']});
			// will prompt user to search boards/cards for phrase
			break;
		default:
	}
}

delegate.decideNavigationForURL = function(url) {
	comps = url.split(':');
	scheme = comps.shift();
	addr = comps.shift();
	switch (scheme) {
		case "http":
		case "https":
			if (!~addr.indexOf("//trello.com") && !~addr.indexOf("//accounts.google.com")) {
				$.sysOpenURL(url); //pop all external links to system browser
				$.conlog("opened "+url+" externally!");
				return true; //tell webkit to do nothing
			}
		case "about":
		case "file":
		default:
			return false;
	}
}

delegate.TrelloNotification = function(msg) {
	// receives events from JS in 1st AppTab
	// -> webkit.messageHandlers.receivedHangoutMessage.postMessage([from, replyTo, msg]);
	//$.postOSXNotification.apply(this, msg); // why no workie?
	$.postOSXNotification(msg[0], msg[1], msg[2]);
	$.conlog(Date() + ' [posted osx notification] ' + msg);
};

delegate.handleClickedNotifcation = function(from, url, msg) { $.sysOpenURL(url); return true; }

delegate.AppFinishedLaunching = function() {
	$.registerURLScheme('trello');
	$.isTransparent = true;

	if ($.lastLaunchedURL != '') {
		 delegate.launchURL($.lastLaunchedURL);
	} else {
		$.newAppTabWithJS("https://trello.com", {
			'preinject':[],
			'postinject':['dnd','styler','notifier'],
			'handlers':['TrelloNotification']
		});
	}

}
delegate; //return this to macpin
