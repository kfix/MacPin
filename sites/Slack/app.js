/*eslint-env applescript*/
/*eslint-env builtins*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

var slackTab, slack = {
	url: 'https://slack.com/signin/',
	subscribeTo: ['receivedHTML5DesktopNotification', "MacPinPollStates"],
	preinject: ['shim_html5_notifications']
};
$.browser.tabSelected = slackTab = new $.WebView(slack);

var delegate = {}; // our delegate to receive events from the webview app

delegate.receivedHTML5DesktopNotification = function(tab, note) {
	console.log(Date() + ' [posted HTML5 notification] ' + note);
	//tag: "mid.1434908822690:d3b8b216631a1b8625"
	$.app.postHTML5Notification(note);
};

delegate.handleClickedNotification = function(title, subtitle, msg, id) {
	console.log("JS: opening notification for: "+ [title, subtitle, msg, id]);
	$.browser.tabSelected = slackTab;
	//slackTab.evalJS();
	return true;
};

delegate.launchURL = function(url) {
	console.log("app.js: launching " + url);
	var comps = url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift();
	switch (scheme) {
		case "slack": //FIXME: support search for find users, channels
			break;
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
		case "https":
			if (
				 (~addr.indexOf(".slack.com/")) &&
				(~addr.indexOf("//slack.com/"))
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
	//$.browser.addShortcut('Slack', slack);
	// FIXME: use LocalStorage to save slackTab's team-domain after sign-in, and restore that on every start up
	// FIXME add themes: https://github.com/fishman/slack
};
delegate; //return this to macpin
