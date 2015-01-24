$.toggleTransparency();
$.registerURLScheme('sms');
$.registerURLScheme('tel');
$.registerURLScheme('hangouts');
// OSX Yosemite safari recognizes and launches sms and tel links to any associated app
//  https://github.com/WebKit/webkit/blob/ce77bdb93dbd24df1af5d44a475fe29b5816f8f9/Source/WebKit2/UIProcess/mac/WKActionMenuController.mm#L691

var delegate = {}; // our delegate to receive events from the webview app

delegate.receivedHangoutsMessage = function(msg) {
	// receives events from JS in 1st AppTab
	// -> webkit.messageHandlers.receivedHangoutMessage.postMessage([from, replyTo, msg]);
	//$.postOSXNotification.apply(this, msg); // why no workie?
	$.postOSXNotification(msg[0], msg[1], msg[2]);
	$.log(Date() + ' [posted osx notification] ' + msg);
};

delegate.stealAppFocus = function(msg) { $.stealAppFocus() }
delegate.unhideApp = function(msg) { $.unhideApp() }

//delegate.decideNavigationForURL = function(url) { 
delegate.decideWindowOpenForURL = function(url) {
	if (~url.indexOf("https://plus.google.com/hangouts/_")) { //G+ hangouts a/v chat
		//$.log("redirecting window.open to Chrome");
		//$.sysOpenURL("https://plus.google.com/hangouts/_/?hl=en&hpn="+addr+"&hip="+addr+"&hnc=0", "com.google.Chrome");
		$.newAppTabWithJS(url);
		$.switchToNextTab();
		return false;
	};
	//if url ^= https://talkgadget.google.com/u/0/talkgadget/_/frame
	return true; // Allow | Cancel
};

delegate.launchURL = function(url) {
	$.log("JScore: launching " + url);
	comps = url.split(':');
	scheme = comps.shift();
	addr = comps.shift();
	switch (scheme + ':') {
		// https://developer.apple.com/library/ios/featuredarticles/iPhoneURLScheme_Reference/Introduction/Introduction.html#//apple_ref/doc/uid/TP40007899
		case 'sms:':
			$.firstTabEvalJS("xssRoster(['inputAddress', "+addr+"]);"); //calls into AppTab[1]:notifier.js
			$.firstTabEvalJS("xssRoster(['openSMS']);"); //wait for button to show
			//$.firstTab().frame('gtn-roster-iframe-id-b').evalJS("inputAddress("+addr+");");
			break;
		case 'tel:':
			//$.newAppTab("https://plus.google.com/hangouts/_/?hl=en&hpn="+addr+"&hip="+addr+"&hnc=0");
			$.sysOpenURL("https://plus.google.com/hangouts/_/?hl=en&hpn="+addr+"&hip="+addr+"&hnc=0", "com.google.Chrome"); //use Chrome's NaCL+WebRTC client
			break;
		case 'hangouts:':
			// this should be a gmail address or email address that has been linked to a google account
			// http://handleopenurl.com/scheme/hangouts
			// https://productforums.google.com/forum/#!topic/hangouts/-FgLeX50Jck
			//xssRoster(["inputAddress", addr, [' ','\r']]);
			//$.firstTabEvalJS("xssRoster(['inputAddress', "+addr+", ['.','\b','\r']]);"); //calls into AppTab[1]:notifier.js
			$.firstTabEvalJS("xssRoster(['inputAddress', "+addr+"]);"); //calls into AppTab[1]:notifier.js
			break;
		default:
	};
};

$.newAppTabWithJS("https://plus.google.com/hangouts", {
	'postinject': ["notifier"],
	'preinject':  ["styler"],
	'handlers': ['receivedHangoutsMessage','unhideApp','stealAppFocus']
});
if ($.lastLaunchedURL != '') delegate.launchURL($.lastLaunchedURL); //gotta add some delay..
$.log('Hangouts setup script complete');
delegate; //return this to macpin
