/*
 * injected funcs for doing stuff with the googlePhone
 *
 *  take a look at https://github.com/jerrod-lankford/google-voice-desktop-app for more possibilities
 *  (SMS send/recv)
 * _gv.soyProto has some interseting stuff in it, like .VoiceClientAccount (current phone number)
 */

	function getCallBox() { return document.getElementsByTagName('gv-make-call-panel')[0].getElementsByTagName('input')[0]; }

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
		if (endkeys != null) // Enter will open a direct call
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

	function makeCall() { setTimeout(function(){
		var tgt = document.querySelector("button[gv-test-id='new-call-button']");
		tgt.click();
		return;
	}, 1000); } //wait for contact to get found
