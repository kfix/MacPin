//if (document.documentElement.style.backgroundColor == "") document.documentElement.style.backgroundColor = "white";
//uggh, its so painfully bright... time for hacker mode?
/*

diggreader.css
.col-left
.col-right
	.#view-region-main-controller
		article .feeditem-read .feeditem-list .feeditem-list:hover
		article .feed-item-focused .expanded
			.feeditem-list.expanded .story-detail-view-container = background-color: "rgb(147,148,151)";
			div .story-detail-view
*/

var macpinIsTransparent;

var customizeBG = function() {
	var css = document.getElementById('customizeBG');
	if (!css) {
		var css = document.createElement("style");
		css.id = "customizeBG";
		css.type = 'text/css';
	}
	//if (window.macpinIsTransparent) {
	css.innerHTML = "body { background-color: rgb(96, 96, 96) !important; }";
	css.innerHTML += "\n.feeditem-list.expanded .story-detail-view-container { background: rgb(147, 148, 151) !important; }";
	css.innerHTML += "\n.feeditem-list.expanded .story-detail-view-container .story-title a { color: #111 !important; }";
	css.innerHTML += "\n.feeditem-read.expanded .story-detail-view-container .story-title a { color: #444 !important; }";
	css.innerHTML += "\n.feed-item-focused.expanded .story-detail-view-container .story-title a { color: #0093cc !important; }";
	document.head.appendChild(css);
}

window.addEventListener("load", function(event) { window.customizeBG(); }, false);

window.addEventListener("MacPinWebViewChanged", function(event) {
	window.macpinIsTransparent = event.detail["transparent"];
	window.customizeBG();
}, false);
