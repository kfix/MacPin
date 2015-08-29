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
			css.id = 'unSocialSpam';
		    css.innerHTML = "\
			    body, #content { overflow: hidden; background-color: transparent !important; }\
			    #contentPane, #gb, #gba, #notify-widget-pane { display: none; }\
				div[title='Display Notifications'] { display: none; }\
				div[title='Add People'] { display: none; }\
				div[guidedhelpid='streamcontent'] { display: none; }\
				div[style='height: 60px;'] { display: none; }\
				div[style='top: 60px;'] { display: none; }\
				#content > div:first-of-type { display: none; }\
				div[guidedhelpid='chat_mole_icon'] { display: none; }\
				div[style='top: 104px;'] { top: 0px !important; }\
				#ozIdRtRibbonChatRoster { height: 800px; margin-left: 0px; }\
			";
			document.head.appendChild(css);
			//document.head.insertBefore(css,document.head.childNodes[0]); //prepend
		}
	}
	document.addEventListener('DOMSubtreeModified', injectCSS, false); //mutation events are deprecated
})();

if (window == top)
window.addEventListener('resize', function(e){
	//e.preventDefault();
	//e.stopPropagation();
	if (roster = document.getElementById('ozIdRtRibbonChatRoster'))
		roster.style.height = document.height - 1 + "px";
	//return false;
});



if (window.name == 'preld') { //frame-id ^gtn_ this is a chatbox iframe
	// remove google's redirect wrappers on all messaged links
	// no evil being done here, amirite? -GoogleBruh
	function fixLink(el) {
		if (el.nodeName == 'A')
			if (~el.href.indexOf("http://www.google.com/url?q="))
				el.href = el.text;
	}

	function watchForGoogleRedirects(el) {
		//look for changed element attributes in the chat list representing new messages and send them to the notifier
					//for (var link of mut.target.querySelectorAll('a[href^="http://www.google.com/url?q="]'))
		var cfg = { attributes: true, attributeFilter: ['href'], childList: true, characterData: false, subtree: true };
		var watch = new MutationObserver(function(muts) {
			for (var mut of muts) 
				if (mut.type === 'childList')
					Array.prototype.forEach.call(mut.addedNodes, fixLink);
				if (mut.type === 'attributes')
					if (mut.attributeName == 'href')
						fixLink(mut.target);
		});
		watch.observe(el, cfg);
		return watch;
	}
	watchForGoogleRedirects(document);
}

if (window.name == 'preld') { //frame-id ^gtn_ this is a chatbox iframe
	(function(){ //IIFE
		function injectCSS() {
	        if (document.head) {
				document.removeEventListener('DOMSubtreeModified', injectCSS, false);

				// show local native emoji font rather than Hangout's crappy emoji art
				var css = document.createElement("style");
				css.type = 'text/css';
				css.id = 'appleEmoji'
			    css.innerHTML = "\
					span[data-emo] span { opacity: 1.0 !important; width: auto !important; font-size: 12pt; } \
					span[data-emo] div { display: none !important; } \
				\
				";
				document.head.appendChild(css);
			}
		}
		document.addEventListener('DOMSubtreeModified', injectCSS, false); //mutation events are deprecated

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
	})();

	// watch for pop-out button to appear
	// document.querySelector('button[title="Pop-out"]').click() //auto-tab this chat
	// then postMessage at macpin to switch to next tab
};
