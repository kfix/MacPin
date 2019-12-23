/*eslint-env applescript*/
/*eslint-env es6*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

var hangouts = {
	transparent: true,
	postinject: ["notifier"], // "convopopper"],
	preinject: ["styler"],
	subscribeTo: ['unhideApp', 'HangoutsRosterReady', 'SwitchToThisTab'],
	style: [ "style" ],
	url: "https://hangouts.google.com"
};
var hangoutsAlt = Object.assign({}, hangouts, {url: "https://plus.google.com/u/1/hangouts"});
$.browser.addShortcut("Google Hangouts", hangouts);
var hangoutsTab = new $.WebView(hangouts); // start loading right way, its a big Closure app
$.browser.addShortcut("Log into Google Account", "https://accounts.google.com/signin");
$.browser.addShortcut("Open Hangouts tab using secondary Google account", hangoutsAlt);
$.browser.addShortcut("Install Google Voice & Video plugin", "https://encrypted.google.com/tools/dlpage/hangoutplugin");
$.browser.addShortcut("Get Contacts.app -> Hangouts.app plugin", "http://github.com/kfix/MacPin/tree/master/extras/AddressBookHangoutsPlugin");
$.browser.addShortcut("Get OSX service for text-selected numbers", "http://github.com/kfix/MacPin/tree/master/extras/Call%20Phone%20with%20Hangouts.workflow");
$.browser.addShortcut("Google Voice call history", "https://www.google.com/voice/?pli=1#history")
$.browser.addShortcut("(secondary account) Google Voice call history", "https://www.google.com/voice/b/1?pli=1#history")
//var gaia; // your numeric Google ID

var delegate = {}; // our delegate to receive events from the webview app

delegate.DidWindowOpenForURL = function(url, child, parent) { child.subscribeTo("SwitchToThisTab"); } //all popped-up tabs can select themselves

delegate.decideNavigationForClickedURL = function(url) {
	if (
		!url.startsWith("https://talkgadget.google.com")
		&& !url.startsWith("https://accounts.google.com")
		&& !url.startsWith("https://hangouts.google.com")
		&& !url.startsWith("https://plus.google.com/hangouts/")
		&& !url.startsWith("https://www.google.com/a/")
		&& !url.startsWith("https://voice.google.com")
		&& !url.startsWith("https://g.co")
		) { // open all links externally except those above
			$.app.openURL(url);
			return true;
	}
	if (url.startsWith("https://www.google.com/url?q=")) {
		// stripping obnoxious google redirector
		url = decodeURIComponent(url.slice(29));
		$.app.openURL(url);
		return true;
	}
	return false;
};
delegate.decideNavigationForMIME = function() { return false; };
delegate.decideWindowOpenForURL = function(url) {
	if (url.startsWith("https://plus.google.com/hangouts/_/")) { //G+ hangouts a/v chat
		if (useChromeAV)
			$.app.openURL(url, "com.google.Chrome");
		else
			$.browser.tabSelected = new $.WebView({url: url});
		return true;
	}

	/*
	if (url.startsWith("//talkgadget.google.com/u/0/talkgadget/_/frame")) {
		$.browser.tabSelected = new $.WebView({url: url}); // chat pop-out should change tab to new chat tab, and not change size
		return true; //doesn't work because parent webViewConfig is not passed through
	}
	*/

	return false;
};

delegate.handleUserInputtedInvalidURL = function(query) {
	// assuming the invalid url is a phone number
	// check for all-nums or at-sign
	hangoutsTab.evalJS("xssRoster(['inputAddress', '"+query+"']);");
	return true; // tell MacPin to stop validating the URL
};

delegate.launchURL = function(url) { // $.app.openURL(/[sms|hangouts|tel]:.*/) calls this
	console.log("app.js: launching " + url);
	var comps = url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift().replace(/\//g, ''); // de-slashed
	switch (scheme) {
		case 'hangouts':
			// this could be a gmail address or email address that has been linked to a google account, or the Full Name linked to such addresses
			// http://handleopenurl.com/scheme/hangouts
			// https://productforums.google.com/forum/#!topic/hangouts/-FgLeX50Jck
			$.browser.unhideApp(); //user might have switched apps while waiting for roster to load
			$.browser.tabSelected = hangoutsTab;
			hangoutsTab.evalJS("xssRoster(['inputAddress', '"+addr+"'], ['checkFirstFoundContact']);"); //calls into AppTab[1]:notifier.js
		case 'sms':
			$.browser.unhideApp(); //user might have switched apps while waiting for roster to load
			$.browser.tabSelected = hangoutsTab;
			hangoutsTab.evalJS("xssRoster(['inputAddress', '"+addr+"'], ['sendSMS']);"); //calls into AppTab[1]:notifier.js
			break;
		case 'tel':
			// TODO: interpret commas as 2-sec delays and pounds as pounds
			if ($.app.pathExists('/Library/Internet Plug-Ins/googletalkbrowserplugin.plugin')) {
				// use NPAPI GoogleVoice & Video (Vidyo) plugin in the WebView
				// window.a also seems to have a list of loaded plugins
				$.browser.unhideApp(); //user might have switched apps while waiting for roster to load
				$.browser.tabSelected = hangoutsTab;
				hangoutsTab.evalJS("xssRoster(['inputAddress', '"+addr+"'], ['makeCall']);"); // Hangouts now does in-frame phone calls!
				// TODO: use callback to get new chatbox frame name, simulate keypress events over it?
			} else if ($.app.doesAppExist("com.google.Chrome")) {
				// use Chrome's NaCL+WebRTC Hangouts client for A/V chats ( https://webrtchacks.com/hangout-analysis-philipp-hancke/ )
				$.app.openURL("https://plus.google.com/hangouts/_/?hl=en&hpn="+addr+"&hip="+addr+"&hnc=0", "com.google.Chrome");
			} else {
				// no plugin or chrome ...
				$.browser.tabSelected = new $.WebView({url: "https://encrypted.google.com/tools/dlpage/hangoutplugin"}); //prompt to install plugin
				// so how bout that WebRTC in WebKit???
				//    https://blog.mozilla.org/webrtc/firefox-is-now-supported-by-google-hangouts-and-meet/ should we pretend to be FireFox 60?
				$.app.openURL("tel:"+addr, "com.apple.facetime"); // maybe they have iPhone w/Handoff, so try call w/ facetime
			}
			break;
		case 'https':
			if (!url.startsWith("//accounts.google.com")) { $.browser.tabSelected.loadURL(url); break; }
		default:
			$.app.openURL(url);
	}
};

delegate.SwitchToThisTab = function(tab, msg) {
	if (tab) $.browser.tabSelected = tab;
};

delegate.receivedHTML5DesktopNotification = function(tab, note) {
	if (tab.gaia) note.tag += '__' + tab.gaia // add your Google ID to the notification tag
	console.log(Date() + ' [posted HTML5 notification] ' + note);
	$.app.postHTML5Notification(note);
	return true;
};

delegate.handleClickedNotification = function(note) {
	let {title, subtitle, msg, id} = note;
	console.log("JS: opening user notification for: "+ [title, subtitle, msg, id]);
	//$.browser.tabSelected = hangoutsTab;
	//hangoutsTab.evalJS('rosterClickOn("button[cpar='+"'"+id+"'"+']");');
	var src = id.split('__'),
		cpar = src.shift(),
		gaia = src.shift();
	//var [cpar, gaia] = id.split('__'); //ES6...OSX 10.11 ?
	for (var tab of $.browser.tabs) {
		if ((tab.cpar == cpar) && (tab.gaia == gaia)) {
			// a popped out tab already exists for this conversation
			$.browser.tabSelected = tab;
		} else if (tab.gaia == gaia) {
			$.browser.tabSelected = tab;
			hangoutsTab.evalJS('rosterClickOn("button[cpar='+"'"+cpar+"'"+']");');
		}
	}
	return true;
};

delegate.unhideApp = function(tab) {
	$.browser.tabSelected = tab;
	$.browser.unhideApp();
};

delegate.AppFinishedLaunching = function() {
	//$.app.registerURLScheme('sms'); // `open -a Messages.app imessage:18004444444` still works
	//$.app.registerURLScheme('tel'); // `open -a Facetime.app tel:18004444444` still works
	//$.app.registerURLScheme('hangouts');
	// OSX Yosemite safari recognizes and launches sms and tel links to any associated app
	// https://github.com/WebKit/webkit/blob/ce77bdb93dbd24df1af5d44a475fe29b5816f8f9/Source/WebKit2/UIProcess/mac/WKActionMenuController.mm#L691
	// https://developer.apple.com/library/ios/featuredarticles/iPhoneURLScheme_Reference/Introduction/Introduction.html#//apple_ref/doc/uid/TP40007899
	$.browser.tabSelected = hangoutsTab;
};

//addEventListener('HangoutsRosterReady', function(e){...}, false); ??
delegate.HangoutsRosterReady = function(tab) { // notifier.js will call this when roster div is created
	if ($.launchedWithURL != '') { //app was launched by an opened URL or a clicked notification - probably a [sms|tel]: link
		this.launchURL($.launchedWithURL);
		$.launchedWithURL = '';
	}
/*
	// this is your UID for G+: https://developers.google.com/apis-explorer/#p/plus/v1/plus.people.get?userId=me&_h=6&
	// GET https://www.googleapis.com/plus/v1/people/me?key={YOUR_API_KEY}
	tab.evalJS('myGAIA();', function(res, err) {
		if (res != '') {
			var gaia = res;
			console.log("Logged in as https://plus.google.com/"+gaia);
			tab.gaia = gaia;
			//Object.defineProperty(tab, 'gaia', {value: gaia, writable: false});
		} else {
			console.log(err);
			//$.browser.tabSelected = new $.WebView({url: hangouts.url}); // G+ login prompt
		}
	});
*/
	$.browser.addShortcut("Test call to MCI ANAC", "tel:18004444444");
};

delegate; //return this to macpin
