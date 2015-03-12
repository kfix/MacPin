var lastLaunchedURL = '';
var delegate = {}; // our delegate to receive events from the webview app

delegate.launchURL = function(url) {
	comps = url.split(':');
	scheme = comps.shift();
	addr = comps.shift();
	switch (scheme + ':') {
		case 'trello:':
			$browser.newTab({'url':"https://trello.com/search?q="+addr,'postinject':['styler','dnd']});
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
				$osx.openURL(url); //pop all external links to system browser
				$browser.conlog("opened "+url+" externally!");
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
	$osx.postNotification(msg[0], msg[1], msg[2]);
	$browser.conlog(Date() + ' [posted osx notification] ' + msg);
};

delegate.handleClickedNotification = function(from, url, msg) { $osx.openURL(url); return true; }

delegate.AppFinishedLaunching = function() {
	$osx.registerURLScheme('trello');

	if (lastLaunchedURL != '') {
		delegate.launchURL(lastLaunchedURL);
		lastLaunchedURL = '';
	} else {
		$browser.newTab({
			'url': "https://trello.com",
			'postinject': ['dnd','styler','notifier'],
			'handlers': ['TrelloNotification',"MacPinPollStates"] //styler.js does polls
		}).isTransparent = true;
/*
		//$browser.newTab({'url':"about:blank", 'postinject':['dnd']}); allow:blank doesn't take userscripts??!
		$browser.newTab({
			'url':"https://trello.com",
			'postinject': ['dnd','styler','notifier'],
			'handlers': ['TrelloNotification'],
			'icon': "file://"+ $.resourcePath + "/Chrome.icns",
			'agent': "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/40.0.2214.91 Safari/537.36"
		});
*/
	}
}
delegate; //return this to macpin
