/*eslint-env applescript*/
/*eslint-env builtins*/
/*eslint-env es6*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
//"use strict";

// official Slack.app uses MacGap

var slackTab, slack = {
	url: 'https://slack.com/signin/',
	subscribeTo: ['receivedHTML5DesktopNotification', "MacPinPollStates"],
	agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_6) AppleWebKit/603.1.6 (KHTML, like Gecko) Slack/600.5.17",
	// ^ having "Safari" makes Slack's JS peg the CPU...
	//agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_6) AppleWebKit/601.7.7 (KHTML, like Gecko) Slack_SSB/2.0.3',
	preinject: ['shim_html5_notifications'],
	postinject: ['slack_notifications'] //, 'styler']
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

delegate.receivedRedirectionToURL = function(url, tab) {
	var comps = url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift();
	switch (scheme) {
		case "http":
		case "https":
			if (tab.allowAnyRedir || unescape(unescape(addr)).match("//accounts.google.com/")) {
				// we might be redirected to an external domain for a SSO-integrated Google Apps login
				// https://support.google.com/a/answer/60224#userSSO
				// process starts w/ https://accounts.google.com/ServiceLogin(Auth) and ends w/ /MergeSession
				tab.allowAnyRedir = true;
			} else if (addr.endsWith(".slack.com//signin?ssb_success=1")) {
				tab.allowAnyRedir = false; // we are back home
				// if login was success, navigate to team page
				host = addr.split('/')[2]
				redir = `${scheme}://${host}/`
				$.app.openURL(url); //pop all external links to system browser
				console.log(`redirecting from ${url} to ${redir}!`);
				tab.gotoURL(redir);
				return true; //tell webkit that we handled this
			}
		case "about":
		case "file":
		default:
			return false; // tell webkit that we did not handle this
	}
};

delegate.decideNavigationForClickedURL = function(url, tab) {
	console.log(`click-navigation-delegating ${url} ...`);
	var comps = url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift(),
		subpath = addr.split('/')[1];
	switch (scheme) {
		case "http":
		case "https":
			if (addr.startsWith("//slack-redir.net/link?url=")) {
				// stripping obnoxious redirector
				redir = decodeURIComponent(addr.slice(27));
				//$.app.openURL(`$(scheme):$(redir)`);
				$.app.openURL(redir); //pop all external links to system browser
				return true; //tell webkit to do nothing
			} else if (!url.startsWith("https://slack.com")) {
				$.app.openURL(url);
				return true;
			}
	}
	return false;
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

delegate.decideNavigationForURL = function(url, tab) {
	console.log(`navigation-delegating ${url} ...`);
	var comps = url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift(),
		subpath = addr.split('/')[1];
	switch (scheme) {
		case "http":
		case "https":
			if (addr.startsWith("//slack-redir.net/link?url=")) {
				// stripping obnoxious redirector
				redir = decodeURIComponent(addr.slice(27));
				//$.app.openURL(`$(scheme):$(redir)`);
				$.app.openURL(redir); //pop all external links to system browser
				return true; //tell webkit that we handled this
			} else if (
				 (~addr.indexOf(".slack.com/")) &&
				(~addr.indexOf("//slack.com/"))
			) {
				$.app.openURL(url); //pop all external links to system browser
				console.log("opened "+url+" externally!");
				return true; //tell webkit that we handled this
			}
		case "about":
		case "file":
		default:
			return false;
	}
};

// $.app.loadAppScript(`file://${$.app.resourcePath}/enDarken.js`);
// ^^ uses CSS filters, CPU intensive
delegate.enDarken = function(tab) {
	let idx = tab.styles.indexOf('dark');
	(idx >= 0) ? tab.popStyle(idx) : tab.style('dark');
	return;
};

delegate.tabTransparencyToggled = function(transparent, tab) {
	console.log(transparent, tab);
	let idx = tab.styles.indexOf('transparent');
	(!transparent && idx >= 0) ? tab.popStyle(idx) : tab.style('transparent');
	return; // cannot affect built-in transperatizing of tab
};

delegate.AppFinishedLaunching = function() {
	//$.browser.addShortcut('Slack', slack);
	// FIXME: use LocalStorage to save slackTab's team-domain after sign-in, and restore that on every start up
	$.browser.addShortcut('Dark Mode', ['enDarken']);
	// FIXME add themes: https://gist.github.com/DrewML/0acd2e389492e7d9d6be63386d75dd99
};

delegate; //return this to macpin
