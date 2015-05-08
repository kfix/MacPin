/*eslint-env applescript*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

var hangouts = {
	transparent: true,
	postinject: ["notifier"],
	preinject: ["styler"],
	handlers: ['receivedHangoutsMessage', 'unhideApp', 'HangoutsRosterReady'],
	url: "https://plus.google.com/hangouts"
};
$.browser.addShortcut("Google Hangouts", hangouts);
var hangoutsTab = new $.WebView(hangouts);
var useChromeAV = $.app.doesAppExist("com.google.Chrome"); // use Chrome's NaCL+WebRTC Hangouts client for A/V chats ( https://webrtchacks.com/hangout-analysis-philipp-hancke/ )
// var useChromeAV = false // use NPAPI GoogleVoice & Video (Vidyo) plugin in WebKit ( https://encrypted.google.com/tools/dlpage/hangoutplugin )
var gaia; // your Google ID
var delegate = {}; // our delegate to receive events from the webview app

delegate.decideNavigationForClickedURL = function(url) { $.app.openURL(url); return true; };
delegate.decideNavigationForMIME = function() { return false; };
delegate.decideWindowOpenForURL = function(url) {
	if (~url.indexOf("https://plus.google.com/hangouts/_/")) { //G+ hangouts a/v chat
		if (useChromeAV)
			$.app.openURL(url, "com.google.Chrome");
		else
			$.browser.tabSelected = new $.WebView({url: url});
		return true;
	}
	//if url ^= https://talkgadget.google.com/u/0/talkgadget/_/frame
	return false;
};

delegate.launchURL = function(url) { // $.app.openURL(/[sms|hangouts|tel]:.*/) calls this
	console.log("app.js: launching " + url);
	var comps = url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift();
	switch (scheme) {
		case 'hangouts':
			// this should be a gmail address or email address that has been linked to a google account
			// http://handleopenurl.com/scheme/hangouts
			// https://productforums.google.com/forum/#!topic/hangouts/-FgLeX50Jck
			//xssRoster(["inputAddress", addr, [' ','\r']]);
			//xssRoster(['inputAddress', "+addr+", ['.','\b','\r']]);");
		case 'sms':
			$.browser.unhideApp(); //user might have switched apps while waiting for roster to load
			hangoutsTab.evalJS("xssRoster(['inputAddress', '"+addr+"'], ['sendSMS']);"); //calls into AppTab[1]:notifier.js
			break;
		case 'tel':
			if (useChromeAV) {
				$.app.openURL("https://plus.google.com/hangouts/_/?hl=en&hpn="+addr+"&hip="+addr+"&hnc=0", "com.google.Chrome"); //use Chrome's NaCL+WebRTC Hangouts client
			} else {
				$.browser.unhideApp(); //user might have switched apps while waiting for roster to load
				$.browser.tabSelected = new $.WebView({url: "https://plus.google.com/hangouts/_/?hl=en&hpn="+addr+"&hip="+addr+"&hnc=0"});
			}
			break;
		default:
	}
};

//addEventListener('receivedHangoutsMessage', function(e){...}, false); ??
delegate.receivedHangoutsMessage = function(tab, msg) {
	// receives events from JS in 1st AppTab
	// -> webkit.messageHandlers.receivedHangoutMessage.postMessage([from, replyTo, msg, cpar]);
	$.app.postNotification(msg[0], msg[1], msg[2], msg[3]); // ...msg spread-op
	//console.log(Date() + ' [posted user notification] ' + msg);
};

delegate.handleClickedNotification = function(title, subtitle, msg, id) {
	console.log("JS: opening notification for: "+ [title, subtitle, msg, id]);
	$.browser.tabSelected = hangoutsTab;
	hangoutsTab.evalJS('rosterClickOn("button[cpar='+"'"+id+"'"+']");');
	return true;
};

delegate.unhideApp = function(tab) {
	$.browser.tabSelected = tab;
	$.browser.unhideApp();
};

delegate.AppFinishedLaunching = function() {
	$.app.registerURLScheme('sms');
	$.app.registerURLScheme('tel');
	$.app.registerURLScheme('hangouts');
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
	tab.evalJS('myGAIA();', function(res, err) {
		if (res != '') {
			gaia = res;
			console.log("Logged in as https://plus.google.com/"+gaia);
		} else {
			console.log(err);
		}
	});
};

delegate; //return this to macpin
