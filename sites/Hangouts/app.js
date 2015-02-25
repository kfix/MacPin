var lastLaunchedURL = '';
var hangoutsTab;
var useChromeAV = true;
 // if true, use Chrome's NaCL+WebRTC Hangouts client for A/V chats ( https://webrtchacks.com/hangout-analysis-philipp-hancke/ )
 // else use NPAPI GoogleVoice & Video (Vidyo) plugin in WebKit ( https://encrypted.google.com/tools/dlpage/hangoutplugin )
var delegate = {}; // our delegate to receive events from the webview app

delegate.decideNavigationForClickedURL = function(url) { $osx.openURL(url); return true; }
delegate.decideNavigationForMIME = function(url) { return false; }
delegate.decideWindowOpenForURL = function(url) {
	$browser.conlog("JScore: catching window.open() " + url);
	if (~url.indexOf("https://plus.google.com/hangouts/_/")) { //G+ hangouts a/v chat
		if (useChromeAV)
			$osx.openURL(url, "com.google.Chrome");
		else
			$browser.tabSelected = $browser.newTab({'url':url}); 
		return true;
	};
	//if url ^= https://talkgadget.google.com/u/0/talkgadget/_/frame
	return false;
};

delegate.launchURL = function(url) { // $osx.openURL(/[sms|hangouts|tel]:.*/) calls this
	$browser.conlog("app.js: launching " + url);
	comps = url.split(':');
	scheme = comps.shift();
	addr = comps.shift();
	switch (scheme) {
		case 'hangouts':
			// this should be a gmail address or email address that has been linked to a google account
			// http://handleopenurl.com/scheme/hangouts
			// https://productforums.google.com/forum/#!topic/hangouts/-FgLeX50Jck	
			//xssRoster(["inputAddress", addr, [' ','\r']]);
			//xssRoster(['inputAddress', "+addr+", ['.','\b','\r']]);");
		case 'sms':
			lastLaunchedURL = url; // in case app isn't ready to handle url immediately, will get pulled from var after Ready event
			hangoutsTab.evalJS("xssRoster(['inputAddress', '"+addr+"'], ['openSMS']);"); //calls into AppTab[1]:notifier.js
			break;
		case 'tel':
			if (useChromeAV)
				$osx.openURL("https://plus.google.com/hangouts/_/?hl=en&hpn="+addr+"&hip="+addr+"&hnc=0", "com.google.Chrome"); //use Chrome's NaCL+WebRTC Hangouts client
			else
				$browser.tabSelected = $browser.newTab({"url": "https://plus.google.com/hangouts/_/?hl=en&hpn="+addr+"&hip="+addr+"&hnc=0"});
			break;
		default:
	};
};

//addEventListener('receivedHangoutsMessage', function(e){...}, false); ??
delegate.receivedHangoutsMessage = function(msg) {
	// receives events from JS in 1st AppTab
	// -> webkit.messageHandlers.receivedHangoutMessage.postMessage([from, replyTo, msg]);
	$osx.postNotification(msg[0], msg[1], msg[2]);
	$browser.conlog(Date() + ' [posted osx notification] ' + msg);
};

delegate.handleClickedNotification = function(from, url, msg) { 
	$browser.conlog("JS: opening notification for: "+ [from, url, msg]);
	$browser.tabSelected = hangoutsTab;
	lastLaunchedURL = url; // in case app isn't ready to handle url immediately, will get pulled from var after Ready event
	delegate.launchURL(lastLaunchedURL);
	return true;
};

delegate.unhideApp = function(msg) { 
	$browser.tabSelected = hangoutsTab;
	$browser.unhideApp();
};

delegate.AppFinishedLaunching = function() {
	$osx.registerURLScheme('sms');
	$osx.registerURLScheme('tel');
	$osx.registerURLScheme('hangouts');
	// OSX Yosemite safari recognizes and launches sms and tel links to any associated app
	// https://github.com/WebKit/webkit/blob/ce77bdb93dbd24df1af5d44a475fe29b5816f8f9/Source/WebKit2/UIProcess/mac/WKActionMenuController.mm#L691
	// https://developer.apple.com/library/ios/featuredarticles/iPhoneURLScheme_Reference/Introduction/Introduction.html#//apple_ref/doc/uid/TP40007899

	$browser.isTransparent = true;
	hangoutsTab = $browser.newTab({
		'url': "https://plus.google.com/hangouts",
		'postinject': ["notifier"],
		'preinject':  ["styler"],
		'handlers': ['receivedHangoutsMessage','unhideApp','HangoutsRosterReady']
	});
};

//addEventListener('HangoutsRosterReady', function(e){...}, false); ??
delegate.HangoutsRosterReady = function(msg) { // notifier.js will call this when roster div is created
	if (lastLaunchedURL != '') { //app was launched by an opened URL or a clicked notification - probably a [sms|tel]: link 
		$browser.unhideApp(); //user might have switched apps while waiting for roster to load
		delegate.launchURL(lastLaunchedURL);
		lastLaunchedURL = '';
	};
};

delegate; //return this to macpin
