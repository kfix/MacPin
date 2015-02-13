// https://webrtchacks.com/hangout-analysis-philipp-hancke/

var delegate = {}; // our delegate to receive events from the webview app

delegate.decideNavigationForClickedURL = function(url) { $.sysOpenURL(url); return true; }
delegate.decideNavigationForMIME = function(url) { return false; }
delegate.decideWindowOpenForURL = function(url) {
	$.conlog("JScore: catching window.open() " + url);
	if (~url.indexOf("https://plus.google.com/hangouts/_/")) { //G+ hangouts a/v chat
		$.sysOpenURL(url, "com.google.Chrome"); // use Hangouts Pepper WebRTC plugin
		//$.newAppTabWithJS(url);
		//$.switchToNextTab();
		return true;
	};
	//if url ^= https://talkgadget.google.com/u/0/talkgadget/_/frame
	return false;
};

delegate.launchURL = function(url) { // $.sysOpenURL(/[sms|hangouts|tel]:.*/) calls this
	$.conlog("JScore: launching " + url);
	comps = url.split(':');
	scheme = comps.shift();
	addr = comps.shift();
	switch (scheme) {
		case 'hangouts':
			// this should be a gmail address or email address that has been linked to a google account
			// http://handleopenurl.com/scheme/hangouts
			// https://productforums.google.com/forum/#!topic/hangouts/-FgLeX50Jck	
			//xssRoster(["inputAddress", addr, [' ','\r']]);
			//$.firstTabEvalJS("xssRoster(['inputAddress', "+addr+", ['.','\b','\r']]);"); //calls into AppTab[1]:notifier.js
		// https://developer.apple.com/library/ios/featuredarticles/iPhoneURLScheme_Reference/Introduction/Introduction.html#//apple_ref/doc/uid/TP40007899
		case 'sms':
			$.firstTabEvalJS("xssRoster(['inputAddress', '"+addr+"']);"); //calls into AppTab[1]:notifier.js
			//$.firstTabEvalJS("xssRoster(['openSMS']);"); //wait for button to show
			//$.firstTab().frame('gtn-roster-iframe-id-b').evalJS("inputAddress("+addr+");");
			break;
		case 'tel':
			//$.newAppTab("https://plus.google.com/hangouts/_/?hl=en&hpn="+addr+"&hip="+addr+"&hnc=0");
			$.sysOpenURL("https://plus.google.com/hangouts/_/?hl=en&hpn="+addr+"&hip="+addr+"&hnc=0", "com.google.Chrome"); //use Chrome's NaCL+WebRTC client
			break;
		default:
	};
};

//addEventListener('receivedHangoutsMessage', function(e){...}, false); ??
delegate.receivedHangoutsMessage = function(msg) {
	// receives events from JS in 1st AppTab
	// -> webkit.messageHandlers.receivedHangoutMessage.postMessage([from, replyTo, msg]);
	//$.postOSXNotification.apply(this, msg); // why no workie?
	$.postOSXNotification(msg[0], msg[1], msg[2]);
	$.conlog(Date() + ' [posted osx notification] ' + msg);
};

delegate.handleClickedNotification = function(from, url, msg) { 
	$.conlog("JS: opening notification for: "+ [from, url, msg]);
	$.sysOpenURL(url); //will end back up at launchURL
	return true;
};

delegate.unhideApp = function(msg) { $.unhideApp(); };

//addEventListener('HangoutsRosterReady', function(e){...}, false); ??
delegate.HangoutsRosterReady = function(msg) { // notifier.js will call this when roster div is created
	if ($.lastLaunchedURL != '') { //app was launched by an opened URL or a clicked notification - probably a [sms|tel]: link 
		$.unhideApp(); //user might have switched apps while waiting for roster to load
		delegate.launchURL($.lastLaunchedURL);
	};
};

delegate.AppFinishedLaunching = function() {
	$.isTransparent = true;
	$.registerURLScheme('sms');
	$.registerURLScheme('tel');
	$.registerURLScheme('hangouts');
	// OSX Yosemite safari recognizes and launches sms and tel links to any associated app
	//  https://github.com/WebKit/webkit/blob/ce77bdb93dbd24df1af5d44a475fe29b5816f8f9/Source/WebKit2/UIProcess/mac/WKActionMenuController.mm#L691

	$.newAppTabWithJS("https://plus.google.com/hangouts", {
		'postinject': ["notifier"],
		'preinject':  ["styler"],
		'handlers': ['receivedHangoutsMessage','unhideApp','HangoutsRosterReady']
	});
};

delegate; //return this to macpin
