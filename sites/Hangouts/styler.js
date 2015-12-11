/* eslint-env browser */
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/

if (window == top)
(function(){ //IIFE
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

			var css = document.createElement("style");
			css.type = 'text/css';
			css.id = 'MacPinUnclutter';
		    css.innerHTML = "\
			    body { overflow: hidden; background-color: transparent !important; font-family: -apple-system-font !important; }\
			    #gb, #gba { display: none; }\
				#hangout-landing-chat { left: 60px; top: 0px; width: 250px; }\
				div[aria-label='Open background photo'] > div { background-image: none !important; background: none !important; }\
				img:nth-of-type(2) { display: none; }\
				#hangout-landing-chat + div { background-color: transparent !important; }\
				#hangout-landing-chat + div > div > div { display: none !important; }\
				#hangout-landing-chat + div + div[jsaction] { display: none !important; }\
			";
			document.head.appendChild(css);
			//document.head.insertBefore(css,document.head.childNodes[0]); //prepend
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
			    css.innerHTML = "\
			    	body, div, li, input { font-family: -apple-system-font !important; }\
			    	button, div, li, input { font-size: 9pt !important; }\
				\
				";
				document.head.appendChild(css);
			}
		}
		document.addEventListener('DOMSubtreeModified', injectCSS2, false); //mutation events are deprecated
}

if (window.name == 'preld') { //frame-id ^gtn_ this is a chatbox iframe
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
		e.stopPropagation();
		if (link.getAttribute('onmousedown')) {
		    link.removeAttribute('onmousedown');
		    if (link.pathname === '/url') {
		        if ((/[?&]url=[^&]+/).test(link.search)) {
		            link.href = decodeURIComponent(link.search.split(/[?&]url=/)[1].split('&')[0]);
		        }
		    }
		}
	}, false);
}

if ((window.name == 'preld') || ~window.name.indexOf('gtn_')) { //frame-id ^gtn_ this is a chatbox iframe
	//(function(){ //IIFE
		function injectCSS() {
	        if (document.head) {
				document.removeEventListener('DOMSubtreeModified', injectCSS, false);

				// show local native emoji font rather than Hangout's crappy emoji art
				var css = document.createElement("style");
				css.type = 'text/css';
				css.id = 'appleEmoji'
			    css.innerHTML = "\
			    	body, div, input { font-family: -apple-system-font !important; }\
					span[data-emo] span { opacity: 1.0 !important; width: auto !important; font-size: 12pt; } \
					span[data-emo] div { display: none !important; } \
				\
				";
				document.head.appendChild(css);
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

		document.addEventListener('DOMSubtreeModified', function(e){
	
			// enable keyboard to quickly take/reject phone calls
			if (btn = document.querySelector('button[title="Answer call"]')) { //answer button
				var from = document.QuerySelector('div[googlevoice]').innerText;
				console.log(Date() + " [Incoming phone call from:] " + from);
				document.removeEventListener('DOMSubtreeModified', this, false);
				btn.autofocus = true //hafta apply this before .onload
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
			}
		});
	//})(); //IIFE

};
