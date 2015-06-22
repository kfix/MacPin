/*eslint-env applescript*/
/*eslint-env builtins*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

var messengerTab, messenger = {
	url: 'https://www.messenger.com',
	subscribeTo: ['receivedHTML5DesktopNotification', "MacPinPollStates"],
	preinject: ['shim_html5_notifications']
};

var delegate = {}; // our delegate to receive events from the webview app

delegate.receivedHTML5DesktopNotification = function(tab, note) {
	console.log(Date() + ' [posted HTML5 notification] ' + note);
	//tag: "mid.1434908822690:d3b8b216631a1b8625"
	$.app.postHTML5Notification(note);
};

delegate.handleClickedNotification = function(title, subtitle, msg, id) {
	console.log("JS: opening notification for: "+ [title, subtitle, msg, id]);
	//<time class="_497p _2lpt" data-reactid=".0.1.$1.0.1.$0.0.0.0.0.0.0.2.$db=2mid=11434908822690=2d3b8b216631a1b8625"><span class="_3oh-" data-reactid=".0.1.$1.0.1.$0.0.0.0.0.0.0.2.$db=2mid=11434908822690=2d3b8b216631a1b8625.0">10:47am</span></time>
	$.browser.tabSelected = messengerTab;
	//messengerTab.evalJS();
	return true;
};

delegate.launchURL = function(url) {
	console.log("app.js: launching " + url);
	var comps = url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift();
	switch (scheme + ':') {
		default:
			$.browser.tabSelected = new $.WebView({url: url});
	}
};

delegate.decideNavigationForURL = function(url) {
	var comps = url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift(),
		subpath = addr.split('/')[1];
	switch (scheme) {
		case "http":
		case "https": // https://github.com/rsms/fb-mac-messenger/blob/master/Messenger/AppDelegate.mm#L591
			if (!~addr.indexOf("//www.messenger.com") ||
				(!~addr.indexOf("//www.facebook.com") &&
					(subpath == "login" || subpath == "checkpoint")
				)
			) {
				$.app.openURL(url); //pop all external links to system browser
				console.log("opened "+url+" externally!");
				return true; //tell webkit to do nothing
			}
		case "about":
		case "file":
		default:
			return false;
	}
};

delegate.AppFinishedLaunching = function() {
	$.browser.addShortcut('Messenger', messenger);
	$.browser.tabSelected = messengerTab = new $.WebView(messenger);
};
delegate; //return this to macpin
