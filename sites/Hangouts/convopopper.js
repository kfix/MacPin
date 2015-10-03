/* eslint-env browser */
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/

if ((window.name == 'preld') || ~window.name.indexOf('gtn_')) { //frame-id ^gtn_ this is a chatbox iframe
	
		function autoPop() {
			// auto-tab all opened chats (via window.open)
			if (btn = document.querySelector('button[title="Pop-out"]')) {
				console.log("got a pop-out button!");
				console.log(btn);
				document.removeEventListener('DOMSubtreeModified', autoPop, false);
				btn.click();
				webkit.messageHandlers.SwitchToNewestTab.postMessage([]);
			}
		}

		document.addEventListener('DOMSubtreeModified', autoPop, false); 
};
