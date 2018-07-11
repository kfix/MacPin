/*eslint-env applescript*/
/*eslint-env builtins*/
/*eslint-env es6*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

const {app, BrowserWindow, WebView} = require('@MacPin');

let slackTab, slack = {
	url: 'https://slack.com/ssb/',
	//agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_11_6) AppleWebKit/601.7.7 (KHTML, like Gecko) Slack_SSB/2.0.3', // MacGap app
	//agent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_4) AppleWebKit/537.36 (KHTML, like Gecko) AtomShell/2.5.2 Chrome/53.0.2785.143 Electron/1.4.15 Safari/537.36 MacAppStore/16.5.0 Slack_SSB/2.5.2', // new Electron app (env SLACK_DEVELOPER_MENU=true)
	//preinject: ['shim_notification_promises'],
	postinject: ['slack_notifications'] //, 'styler']
};
slackTab = new WebView(slack); // get it started early

let browser = new BrowserWindow();

app.messageHandlers["receivedHTML5DesktopNotification"] = (tab, note) => {
	console.log(Date() + ' [posted HTML5 notification] ' + note);
	//tag: "mid.1434908822690:d3b8b216631a1b8625"
	app.postHTML5Notification(note);
};

app.on('handleClickedNotification', (title, subtitle, msg, id) => {
	console.log("JS: opening notification for: "+ [title, subtitle, msg, id]);
	browser.tabSelected = slackTab;
	//slackTab.evalJS();
	return true;
});

app.on('networkIsOffline', (url, tab) => {
	// Slack.app might be set to start at boot but wifi lags behind
	// so this is crazy, but here's my number, so call me maybe?
	console.log("reloading from offline!");
	slackTab.loadURL(slack.url);
});

app.on('receivedRedirectionToURL', (url, tab) => {
	var comps = url.split('/'),
		scheme = comps.shift();
	comps.shift();
	var	host = comps.shift(),
		path = comps.shift();

	switch (scheme) {
		case "http":
		case "https":
			if (alwaysAllowRedir) break; //user override
			if (tab.allowAnyRedir || unescape(unescape(url)).match("//accounts.google.com/")) {
				// match(".slack.com/sso/saml/start?redir=") || slack.com/checkcookie
				// we might be redirected to an external domain for a SSO-integrated Google Apps login
				// https://support.google.com/a/answer/60224#userSSO
				// process starts w/ https://accounts.google.com/ServiceLogin(Auth) and ends w/ /MergeSession
				tab.allowAnyRedir = true;
			} else if (url.endsWith(".slack.com//signin?ssb_success=1")) {
				tab.allowAnyRedir = false; // we are back home
				// if login was success, navigate to team page
				host = url.split('/')[2]
				let redir = `${scheme}://${host}/`
				console.log(`redirecting from ${url} to ${redir}!`);
				tab.gotoURL(redir);
				return true; //tell webkit that we handled this
			}
			if (host.endsWith('.slack.com')) break;
		case "about":
		case "file":
		default:
			return false; // tell webkit that we did not handle this
	}
});

let clicker = (url, tab) => {
	console.log(`(click)navigation-delegating ${url} ...`);
	var comps = url.split('/'),
		scheme = comps.shift();
	comps.shift();
	var	host = comps.shift(),
		path = comps.shift();
	switch (scheme) {
		case "http:":
		case "https:":
			if (alwaysAllowRedir) break; //user override
			if ((host == "slack-redir.net") && path.startsWith("link?url=")) {
				// stripping obnoxious redirector
				let redir = decodeURIComponent(path.slice(9));
				//$.app.openURL(`$(scheme):$(redir)`);
				app.openURL(redir); //pop all external links to system browser
				return true; //tell webkit to do nothing
			} else if ((host != "slack.com")
				&& !host.endsWith('.slack.com')
				&& !host.endsWith('.cedexis-test.com')
				&& !host.endsWith('.cloudfront.net')
				&& !host.endsWith('.doubleclick.net')
				&& !host.endsWith('.perf.linkedin.com')
				&& !host.endsWith('.youtube.com')
				&& !host.endsWith('.giphy.com')
				&& !host.endsWith('.imgur.com')
				&& !host.endsWith('.vimeo.com')
				&& !host.endsWith('.fbcdn.net')
			) {
				app.openURL(url);
				return true;
			}
		default:
			return false;
	}
};
app.on('decideNavigationForURL', clicker);
app.on('decideNavigationForClickedURL', clicker);

app.on('launchURL', (url) => {
	console.log("app.js: launching " + url);
	var comps = url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift();
	switch (scheme) {
		case "slack": //FIXME: support search for find users, channels
			break;
		default:
			browser.tabSelected = new WebView({url: url});
	}
});

//let enDarken = require(`file://${app.resourcePath}/enDarken.js`);
// ^^ uses CSS filters, CPU intensive
let enDarken = function(tab) {
	let idx = tab.styles.indexOf('dark');
	(idx >= 0) ? tab.popStyle(idx) : tab.style('dark');
	return;
};

app.on('tabTransparencyToggled', (transparent, tab) => {
	console.log(transparent, tab);
	let idx = tab.styles.indexOf('transparent');
	(!transparent && idx >= 0) ? tab.popStyle(idx) : tab.style('transparent');
	return; // cannot affect built-in transperatizing of tab
});

var alwaysAllowRedir = false;
let toggleRedirection = function(state) { alwaysAllowRedir = (state) ? true : false; };


app.on('AppWillFinishLaunching', (AppUI) => {
	//browser.unhideApp();
	//$.browser.addShortcut('Slack', slack);
	// FIXME: use LocalStorage to save slackTab's team-domain after sign-in, and restore that on every start up
	browser.addShortcut('Dark Mode', [], enDarken);
	browser.addShortcut('Enable Redirection to external domains', [true], toggleRedirection);
	// FIXME add themes: https://gist.github.com/DrewML/0acd2e389492e7d9d6be63386d75dd99  DrewML/Theming-Slack-OSX.md
	AppUI.browserController = browser; // make sure main app menu can get at our shortcuts
	//browser.tabSelected = slackTab; // no key-focus, omnibox blank
});

app.on('AppFinishedLaunching', (launchURLs) => {
	//slackTab.asyncEvalJS(`document.location = document.querySelectorAll('.btn')[1].href ? document.querySelectorAll('.btn')[1].href : document.location;`, 3); // try logging into the first signed-in team
	browser.tabSelected = slackTab; // no key-focus, omnibox populated
});
