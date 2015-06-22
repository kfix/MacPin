function xss_eval(event) {
	console.log('origin['+event.origin +'] called @'+window.name+'.postMessage() -> req: '+event.data);

	if ( event.origin != "https://plus.google.com" ) return; //only handle messages from main frame

	var calls = event.data.slice();
	for (argv of calls) {
		func = argv.shift();
		if ( eval("typeof "+func+" === 'function'") ){
			console.log('@'+window.name+'.xss_eval() -> '+func+'() -> args: ' + argv);
			func = eval(func)
			//res = func.apply(this, argv); //splat
			res = func(...argv); //spread
			//event.source is origin's .window, could send result of func there with postMessage()
		}
	}

}

if (window == top) {
	window.dispatchEvent(new Event('resize')); //resize the roster per styler.js on cold reloads in fullscreen
	document.querySelector('a[href="/stream"]').parentNode.remove(); // -G+ page selector tray list
	/* <script>window.jstiming.load.tick('streamStart');</script>
		delete all the junk nodes in between these
	<script>window.jstiming.load.tick('streamEnd');</script>*/

	function getRoster() { return document.getElementById('gtn-roster-iframe-id-b'); }
	function xssRoster() { /* ([func1, arg1, arg2], [func2, arg1, arg2])*/
		// make arg[0] == iframe.id ?
		getRoster().contentWindow.postMessage(Array.prototype.slice.call(arguments), '*'); // ordered dispatch
		//for (var i = 0; i < arguments.length; i++) { // immediate dispatch
		//	var call = arguments[i];
		//	getRoster().contentWindow.postMessage(call, '*');
		//}
	 }

	function myGAIA(){ return document.querySelector('a[aria-label^=Profile]').getAttribute('href').slice(1); }
	// this is your UID for G+: https://developers.google.com/apis-explorer/#p/plus/v1/plus.people.get?userId=me&_h=6&

	function rosterClickOn(sel) { xssRoster(['clickOn', sel]); }

	//addEventListener("message", xss_eval, false); // intercept new chat window dispositions in the main content pane

} else {
	function evalMain(req) { top.postMessage([req], '*'); }
	//addEventListener("message", xss_eval, false); // intercept loooots of data to individual chat iframes
	// https://github.com/tdryer/hangups/blob/master/hangups/pblite.py
	// https://github.com/tdryer/hangups/blob/master/hangups/schemas.py
	// http://protobuf.axo.io/#objc
}

if (window.name == 'gtn-roster-iframe-id-b') {
//IIFE?

	var roster;

	function clickOn(sel) { document.querySelector(sel).click() }
	function getTopConversation() { return document.querySelector('button[cpar]'); } //gets 1st convers in roster
	// cpar=<SenderGAIA>_<ReceiverGAIA>
	// SMS forwarded messages have ephermeral GAIA's (persist for length of conversation history?)
	// cathartic messages just have cpar=<YourGAIA>

	function notifyMessages(msgs) {
		for (el of msgs) { // el should be a <button>
			var cpar = el.getAttribute('cpar');
			var msg = el.innerText.split('\n').filter( function(v) { return (v.length > 0) }) //filter blank lines
			var from = msg.shift();
			var rcvd = msg.shift();
			// naked sms: '(NNN) NNN-NNNN'
			// shortcode sms: NNNNNN
			// sms from number in your Gmail Contacts: 'Firstname Lastname \U2022 (NNN) NNN-NNNN'
			// pure hangout messages can be named anything -- fixme: must differentiate these with hangouts:<foo@gmail>
			var body = msg.join('\n');

			//var replyTo = (el.parentNode.querySelector('div[title="This user may not be on Hangouts"]') != null) ?
			//	 'sms:' + from.replace(/[^[0-9]/g, '') : // could discriminate with https://github.com/googlei18n/libphonenumber
			//	 'hangouts:' + from; //user is available/ user may be unavailable

			var digits = from.replace(/[^[0-9]/g, '');
			if (digits.length == 10 || digits.length == 5) { // could discriminate with https://github.com/googlei18n/libphonenumber
				 replyTo = 'sms:' + digits;
			} else {
				 replyTo = 'hangouts:' + from;
			}


			if (body == "is video calling you" || body == "is calling you" || body == "You're in a call" || body == "You're in a video call") {
				webkit.messageHandlers.unhideApp.postMessage([]); //get in the user's face right now!!
			} else {
				//webkit.messageHandlers.receivedHangoutsMessage.postMessage([from, replyTo, body, cpar]);
				var note = {
					title: from,
					subtitle: replyTo,
					body: body,
					tag: cpar
				}

				if (img = el.getElementsByTagName('IMG')[0].src) note.icon = img;

				webkit.messageHandlers.receivedHTML5DesktopNotification.postMessage(note);
			}
		}
	}

	function findParentNodeOfTag(tagName, childObj) {
		var testObj = childObj.parentNode;
		var count = 1;
		while(testObj.tagName != tagName) {
			testObj = testObj.parentNode;
			count++;
		}
		return testObj
	}

	function watchForRoster() {
		var cfg = { attributes: false, childList: true, characterData: false, subtree: true };
		var watch = new MutationObserver(function(muts) {
			for (var mut of muts) {
				if (mut.type === 'childList')
					if (roster = mut.target.querySelector('div[aria-label=Conversations]')) {
						console.log("Found Hangouts chat roster, dispatching HangoutsRosterReady event");
						window.dispatchEvent(new window.CustomEvent('HangoutsRosterReady',{'detail':{'roster': roster}})); //send ref to roster element
						window.rosterWatcher.disconnect(); // FIXME: use 'this'
						break;
					}
			}
		});
		watch.observe(document.body, cfg);
		return watch
	}

	function watchForNewMessages(roster) {
		//look for changed element attributes in the chat list representing new messages and send them to the notifier
		var cfg = { attributes: true, childList: false, attributeFilter: ['aria-label'], attributeOldValue: true, characterData: false, subtree: true };
		var watch = new MutationObserver(function(muts) {
			for (var mut of muts) {
				if (mut.type === 'attributes')
					if (mut.target.nodeName == 'DIV')
						if (mut.target.getAttribute('aria-label') != mut.oldValue) //prevent duplicate notifications of fed-back identical messages from chats with myself
							if (mut.target.getAttribute('aria-label').match(/ ([1-9]\d?) unread message/) != null) { //if more than 0 unreads, notify
								console.log(Date() + ' [new message seen from:] ' + mut.target.innerText);
								//console.log('aria-label=' + mut.target.getAttribute('aria-label') + '!=' + mut.oldValue) //debug
								notifyMessages([findParentNodeOfTag('BUTTON', mut.target)]) // search upwards in the tree to get button.parent
								// document.evaluate('/button', mut.target, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null ).singleNodeValue
							}
			}

		});
		watch.observe(roster, cfg);
		return watch;
	}

	function getCallBox() { return document.querySelector('input[spellcheck]'); }
	function getRosterDiv() { return document.querySelector('div > div > div > div'); } //this element captures all of the keyevents

	function inputAddress(addr, endkeys) {
		if (addr == null || addr == '') return;
		addr = decodeURI(addr);
		var cb = window.getCallBox();
		cb.blur();
		cb.value = '';
		cb.focus();
		//cb.value = addr;
		var tev = document.createEvent("TextEvent");
		tev.initTextEvent('textInput', true, true, null, addr);
		cb.dispatchEvent(tev);
		if (endkeys != null) // Enter will open a direct hangout/call, Tab will add to recipent list
			sendkeys(cb, endkeys);
	};

	function sendkeys(el, keys) {
		//for (var i = 1; i < arguments.length; i++) {
			//var key = arguments[i];
		var keyids = { // https://developer.mozilla.org/en-US/docs/Web/API/KeyboardEvent.keyCode
			8: 'backspace',
			9: 'tab',
			//10: 'newline',
			13: 'enter',
			27: 'esc',
			32: 'space',
			38: 'up',
			40: 'down',
			46: 'Period', //wtf webkit?!
			108: '.'
		};
		for (key of keys) {
			var keycode = (Number(key)) ? key : key.charCodeAt(0); // String.fromCharCode(keycode)
			var keyid = keyids[keycode];
			for (kt of ["keydown", "keypress", "keyup"]) {
				var kev = new KeyboardEvent(kt, { bubbles: true, cancelable: true, view: window, detail: 0, keyIdentifier: keyid, location: KeyboardEvent.DOM_KEY_LOCATION_STANDARD, ctrlKey: false, altKey: false, shiftKey: false, metaKey: false }); //key: keycode
				if (kt == 'keypress') {
					Object.defineProperty(kev, 'charCode', {'value': keycode, 'enumerable': true});
				} else {
					Object.defineProperty(kev, 'charCode', {'value': 0, 'enumerable': true});
				}
				// .which??
				Object.defineProperty(kev, 'keyCode', {'value': keycode, 'enumerable': true});

				setTimeout(function(){ el.dispatchEvent(kev); }, 10000); //add a bit of lag
			}
		}
		if (typeof el.value == 'string') el.value += key;
	};

	function sendSMS() { setTimeout(function(){
 		document.querySelector('a[title="Click to send SMS"]').click(); // a='Send SMS' -> @main window.frames['gtn_96gm6a']
	}, 1000); } //wait for contact to get found
	function makeCall() { setTimeout(function(){
		//var tgt = document.querySelector("li[title='Call'] > div + div > div > div");
		var tgt = document.querySelector("li[title='Call'] img");
		//tgt.click();
		tgt.focus();
		var sz = tgt.getBoundingClientRect();
		tgt.dispatchEvent(new MouseEvent('mouseover', {
			view: window,
			bubbles: true,
			cancelable: false,
			detail: 0,
			screenX: sz.left,
			screenY: sz.top,
			clientX: sz.left,
			clientY: sz.top,
			ctrlKey: false,
			altKey: false,
			shiftKey: false,
			metaKey: false,
			button: 0,
			relatedTarget: tgt
		}));
		tgt.dispatchEvent(new MouseEvent('mousedown', {
			view: window,
			bubbles: true,
			cancelable: false,
			detail: 0,
			screenX: sz.left,
			screenY: sz.top,
			clientX: sz.left,
			clientY: sz.top,
			ctrlKey: false,
			altKey: false,
			shiftKey: false,
			metaKey: false,
			button: 0,
			relatedTarget: undefined
		}));
		tgt.dispatchEvent(new MouseEvent('mouseup', {
			view: window,
			bubbles: true,
			cancelable: false,
			detail: 0,
			screenX: sz.left,
			screenY: sz.top,
			clientX: sz.left,
			clientY: sz.top,
			ctrlKey: false,
			altKey: false,
			shiftKey: false,
			metaKey: false,
			button: 0,
			relatedTarget: undefined
		}));
	}, 1000); } //wait for contact to get found
	function openHangout() { document.querySelector('button[title="Message"]').click(); } // ||'Video call' -> @main window.frames['gtn_96gm6a']
	function checkFirstFoundContact() { document.querySelector('input[type="checkbox"]').click(); } //input[name=select_result]
	function getFirstFoundContact() { document.querySelector('li[oid]'); } //click, mouseover, mouseout
	var evClick = new MouseEvent('click', {'view': window, 'bubbles': true, 'cancelable': true  });
	var evUIclick = new UIEvent('click', {'view': window, 'bubbles': true, 'cancelable': true  });
	//var openAVchat = function() { document.querySelector('a[title="Click to send SMS"]').previousSibling.previousSibling.children[0].dispatchEvent(evClick); } // Phone icon is second div before SMS link
	//var openAVchat = function() { document.querySelector('img[src$="/phone-avatar.png"]').dispatchEvent(evClick); } // Phone icon is second div before SMS link
	//var openAVchat = function() { document.querySelector('li[title="Call"]').dispatchEvent(evClick); } // Phone icon is second div before SMS link
	function newAVChat() { document.querySelector('button[tabindex="-1"]').click() }; //Start a video Hangout

	addEventListener("message", xss_eval, false);

	var rosterWatcher;
	window.addEventListener("HangoutsRosterReady", function(event) {
		console.log("Caught HangoutsRosterReady event, dispatching message watcher");
		window.rosterWatcher.disconnect(); //don't need to keep searching for the roster anymore
		setTimeout(function(){
			webkit.messageHandlers.HangoutsRosterReady.postMessage([]); //callback JSCore to accept queued new message URLs
		}, 10000); //need a little lag so hangouts can finish populating contacts in the roster
		var chatWatcher = window.watchForNewMessages(event.detail['roster']); //watch the found roster element
	}, false);
	rosterWatcher = window.watchForRoster();


} // -gtn-roster-iframe-id-b?

if (~window.name.indexOf('gtn_') && false) { // chat convo
	// need to un-redirect recv'd urls. "do no evil?" quit harvesting conversations google.
}
