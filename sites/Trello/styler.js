/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
/*globals webkit, document, window, localStorage*/

"use strict";

var macpinIsTransparent;

window.addEventListener("load", function(event) {
	webkit.messageHandlers.MacPinPollStates.postMessage(["transparent"]);
}, false);

window.addEventListener("MacPinWebViewChanged", function(event) {
	macpinIsTransparent = event.detail["transparent"];
	customizeBG();
}, false);

// TODO: subscribe to storage events so that customizing one Trello tab will signal all others
// http://www.w3.org/TR/webstorage/#the-storage-event
// https://developer.apple.com/library/safari/documentation/iPhone/Conceptual/SafariJSDatabaseGuide/Name-ValueStorage/Name-ValueStorage.html#//apple_ref/doc/uid/TP40007256-CH6-SW6
// https://developer.mozilla.org/en-US/docs/Web/Events/storage

var customizeBG = function(el) {
	var overrideStockTrelloBlue = localStorage.overrideStockTrelloBlue;
	var darkMode = localStorage.darkMode;

	var css = document.getElementById('customizeBG');
	if (!css) {
		css = document.createElement("style");
		css.id = "customizeBG";
		css.type = 'text/css';
	}

	var stockTrelloBlue = "rgb(0, 121, 191)";
	if (macpinIsTransparent) {
		css.innerHTML = 'body { background-color: transparent !important; } ';
		// could get rgb=getComputedStyle(document.body).backgroundColor.match(/[\d\.]+/g) and convert from original rgb() to rgba()
		// http://stackoverflow.com/q/6672374/3878712 http://davidwalsh.name/detect-invert-color
		document.body.style.backgroundColor = "transparent";
	} else if ( (document.body.style.backgroundColor == stockTrelloBlue) && overrideStockTrelloBlue) {
		css.innerHTML = 'body { background-color: rgba('+overrideStockTrelloBlue+') !important; } ';
		document.body.style.backgroundColor = 'rgba('+overrideStockTrelloBlue+')';
	} else {
		document.body.style.backgroundColor = stockTrelloBlue;
		css.innerHTML = '{}';
	}

	if (darkMode) css.innerHTML += "\
		body { -webkit-filter:invert(100%) hue-rotate(180deg); }\
		input,img,video,.window-cover,.list-card-cover,.attachment-thumbnail-preview,.js-open-board,.board-background-select { -webkit-filter:invert(100%) hue-rotate(180deg); }\
		span { color: black; }";

	if (darkMode && !macpinIsTransparent && document.body.style.backgroundColor == "") document.body.style.backgroundColor = "black";

	document.head.appendChild(css);
};

// need to watch for changes to body["style"] so we can re-apply any custom settings after board navigations
var bgWatch = new MutationObserver(function(muts) { customizeBG(); });
bgWatch.observe(document.body, { attributes: true, attributeFilter: ["style"], childList: false, characterData: false, subtree: false });
