/* eslint-env browser */
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/

if ((window.name == 'preld') || ~window.name.indexOf('gtn_')) { //frame-id ^gtn_ this is a chatbox iframe
	var btn;
	function autoPop() {
		// auto-tab all opened chats (via window.open)
		if (btn = document.querySelector('button[title="Pop-out"]')) {
			console.log("got a pop-out button!");
			console.log(btn);
			//btn.click();
			// goog.testing.events.fireClickSequence()
			// https://google.github.io/closure-library/api/source/closure/goog/testing/events/events.js.src.html#l165
			btn[Object.keys(btn)[0]].$.click[0].proxy(); // btn.closure_lm_54596 ...
		}

		//setTimeout(webkit.messageHandlers.SwitchToThisTab.postMessage, 3000, []);
	}

	setTimeout(autoPop, 4000);
	webkit.messageHandlers.SwitchToThisTab.postMessage([]);
};
