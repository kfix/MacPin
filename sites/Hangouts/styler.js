/* eslint-env browser */
/* eslint-env es6 */
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/

if (window == top)
(function(){ //IIFE
	// window.args ...
	function injectCSS() {
        if (document.head) {
			document.removeEventListener('DOMSubtreeModified', injectCSS, false);

			// E: Not allowed to load local resource
			/* wait until http://trac.webkit.org/changeset/174029/trunk lands in OSX */
			/* var cssf = document.createElement("link");
			cssf.setAttribute("rel", "stylesheet");
			cssf.setAttribute("type", "text/css");
			cssf.setAttribute("href", "file://restyle.css")
			document.head.appendChild(cssf);
			*/

			// allow correct zooming
			var vp = document.createElement("meta");
			vp.setAttribute("name", "viewport");
			vp.setAttribute("content", "initial-scale=1.0");
			document.head.appendChild(vp);
			//<meta name="viewport" content="initial-scale=1.0" />
		}
	}
	document.addEventListener('DOMSubtreeModified', injectCSS, false); //mutation events are deprecated
})();

if (window.name == 'gtn-roster-iframe-id-b') { // roster
		function injectCSS2() {
	        if (document.head) {
				document.removeEventListener('DOMSubtreeModified', injectCSS2, false);

				// show local native emoji font rather than Hangout's crappy emoji art
				var css = document.createElement("style");
				css.type = 'text/css';
				css.id = 'MacPinDeFuglify'
				//:root, img, video, object, iframe, span[data-emo] { filter: invert(1) hue-rotate(180deg); }
			    css.innerHTML = `
			    	body, div, li, input { font-family: -apple-system-font !important; }
			    	button, div, li, input { font-size: 9pt !important; }
				`;
				//document.head.appendChild(css);
			}
		}
		document.addEventListener('DOMSubtreeModified', injectCSS2, false); //mutation events are deprecated
}

if ((window.name == 'preld') || ~window.name.indexOf('gtn_')) { //frame-id ^gtn_ this is a chatbox iframe

	// remove google's redirect wrappers on all messaged links
	// no evil being done here, amirite? -GoogleBruh
	// from https://github.com/canisbos/DirectLinks/blob/master/DirectLinks.safariextension/injected.js
	document.addEventListener('mousedown', function (e) {
		var et = e.target, lc = -1;
		while (et && !(et instanceof HTMLAnchorElement) && (3 > lc++))
		    et = et.parentElement;
		if (!et || !et.href)
		    return;
		var link = et;
	    if ((link.host === "www.google.com") && (link.pathname === '/url')) {
	        if ((/[?&]q=[^&]+/).test(link.search)) {
	            link.href = decodeURIComponent(link.search.split(/[?&]q=/)[1].split('&')[0]);
	        }
		}
	}, true); // true captures the event on the down-pass from document to element

	function injectCSS() {
	    if (document.head) {
			document.removeEventListener('DOMSubtreeModified', injectCSS, false);

			// show local native emoji font rather than Hangout's crappy emoji art
			var css = document.createElement("style");
			css.type = 'text/css';
			css.id = 'appleEmoji'
			//:root, img, video, object, iframe, span[data-emo] { filter: invert(1) hue-rotate(180deg); }
		    css.innerHTML = `
		    	body, div, input { font-family: -apple-system-font !important; }
				span[data-emo] span { opacity: 1.0 !important; width: auto !important; font-size: 12pt; }
				span[data-emo] div { display: none !important; }
			`;
			document.head.appendChild(css);
			// dang, they took away the textContent emojis, just img[data-emo] now...
		}
	}
	document.addEventListener('DOMSubtreeModified', injectCSS, false); //mutation events are deprecated

	/*		
	function autoPop() {
		// auto-tab all opened chats (via window.open)
		if (btn = document.querySelector('button[title="Pop-out"]')) {
			console.log("got a pop-out button!");
			console.log(btn);
			document.removeEventListener('DOMSubtreeModified', autoPop, false);
			setTimeout(function(){
				btn.click();
				webkit.messageHandlers.SwitchToNewestTab.postMessage([]);
			}, 5000); //need a little lag so closure can associate window.open() to the button
		}
	}
	document.addEventListener('DOMSubtreeModified', autoPop, false); 
	*/

	var callWatcher;
	function watchForIncomingCalls(chat) {
		// if a new button node is added, see if it's an Answer Call and steal focus to the app
		var cfg = { childList: true, subtree: true };
		var watch = new MutationObserver(function(muts) {
			for (var mut of muts) {
				if (mut.type === 'childList')
					if (btn = mut.target.querySelector('button[title="Answer call"]')) { 
						console.log(Date() + " [Incoming phone call]");
						btn.autofocus = true; //hafta apply this before .onload
						window.addEventListener("keypress", function (e) {
							switch (e.which) {
								case 13: //Enter
								case 32: //Space
									document.querySelector('button[title="Answer call"]').click();
									document.removeEventListener('keypress', this, false);
									break;
								case 27: //Esc
								case 9: //Tab
								case 8: //Bksp
									document.querySelector('button[title="Decline call"]').click();
									document.removeEventListener('keypress', this, false);
									break;
								default:
							}
						});
						webkit.messageHandlers.unhideApp.postMessage([]); //get the app in the user's face right now!!
						window.callWatcher.disconnect(); // can stop observing now
					}
			}
		});
		watch.observe(chat, cfg);
		return watch;
	}
	callWatcher = window.watchForIncomingCalls(document);

};
