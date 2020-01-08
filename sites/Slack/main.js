/*eslint-env applescript*/
/*eslint-env builtins*/
/*eslint-env es6*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

const {app, BrowserWindow, WebView} = require('@MacPin');

let slackTab, slack = {
	url: 'https://slack.com/signin', // show workspace picker on open
	authorizedOriginsForNotifications: [
		'https://app.slack.com',
		'https://app.slack.com:443'
	],
	style: ['autodark']
};
slackTab = new WebView(slack); // get it started early

let browser = new BrowserWindow();

app.on("postedDesktopNotification", (note, tab) => {
	console.log(Date() + `[${tab.url}] posted HTML5 desktop notification: ${note.id}`);
	console.log(JSON.stringify(note));
	return false
});

app.on('handleClickedNotification', (note) => {
	console.log("App signalled a clicked notification: "+ JSON.stringify(note));
	return false;
});

app.on('networkIsOffline', (url, tab) => {
	// Slack.app might be set to start at boot but wifi lags behind
	// so this is crazy, but here's my number, so call me maybe?
	console.log("reloading from offline!");
	slackTab.loadURL(slack.url);
});

app.on('receivedRedirectionToURL', (url, tab) => {
	console.log(`server-redirected ${url} ...`);
	var comps = url.split('/'),
		scheme = comps.shift();
	comps.shift();
	var	host = comps.shift(),
		path = comps.shift();

	switch (scheme) {
		case "http":
		case "https":
			if (alwaysAllowRedir) break; //user override
			if (host.endsWith(".slack.com") ||
				host.endsWith(".okta.com") ||
				host.endsWith(".duosecurity.com")
				) break; // SSO venders
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
				console.log(`app redirecting from ${url} to ${redir}!`);
				tab.loadURL(redir);
				return true; //tell webkit that we handled this
			}
		case "about":
		case "file":
		default:
			break;
	}
	return false; // tell webkit that we did not handle this
});

let clicker = (url, tab, mainFrame) => {
	console.log(`navigation-delegating ${url} ...`);
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
				app.openURL(redir); //pop all external links to system browser
				return true; //tell webkit to do nothing
			} else if ((host != "slack.com")
				&& !host.endsWith('.slack.com')

				// CDNs for unfurled/inline media shares
				&& !host.endsWith('.slack-edge.com')
				&& !host.endsWith('.cedexis-test.com')
				&& !host.endsWith('.cloudfront.net')
				&& !host.endsWith('.youtube.com')
				&& !host.endsWith('.giphy.com')
				&& !host.endsWith('.imgur.com')
				&& !host.endsWith('.vimeo.com')
				&& !host.endsWith('.fbcdn.net')
				&& !host.endsWith('.tumblr.com')
				&& !host.endsWith('.twimg.com')

				// metrics | trackers
				&& !host.endsWith('.doubleclick.net')
				&& !host.endsWith('.perf.linkedin.com')
				&& !host.endsWith('adservice.google.com')

				// SSO | SAML'rs
				&& !host.endsWith('.okta.com')
				&& !host.endsWith('.duosecurity.com')
			) {
				app.openURL(url);
				return true;
			}
		default:
			break;
	}

	if (mainFrame==false && host == "files.slack.com") {
		console.log("clicked on a file download to be popped up!");
	}

	return false;
};
//app.on('decideNavigationForURL', clicker);
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

var alwaysAllowRedir = false;
let toggleRedirection = function(tab, state) { alwaysAllowRedir = (state != null) ? state : !alwaysAllowRedir; };

app.on('AppWillFinishLaunching', (AppUI) => {
	//browser.unhideApp();
	browser.addShortcut('Workspace Picker', slack);
	// FIXME: use LocalStorage to save slackTab's team-domain after sign-in, and restore that on every start up
	browser.addShortcut('Toggle redirection to external domains', [], toggleRedirection);
	// FIXME add themes: https://gist.github.com/DrewML/0acd2e389492e7d9d6be63386d75dd99  DrewML/Theming-Slack-OSX.md
	AppUI.browserController = browser; // make sure main app menu can get at our shortcuts
	//browser.tabSelected = slackTab; // no key-focus, omnibox blank
});

app.on('AppFinishedLaunching', (launchURLs) => {
	//slackTab.asyncEvalJS(`document.location = document.querySelectorAll('.btn')[1].href ? document.querySelectorAll('.btn')[1].href : document.location;`, 3); // try logging into the first signed-in team
	browser.tabSelected = slackTab; // no key-focus, omnibox populated
});
