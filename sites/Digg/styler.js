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
/*
	css.innerHTML = "body { background-color: rgb(96, 96, 96) !important; }";
	css.innerHTML += "\n.feeditem-list.expanded .story-detail-view-container { background: rgb(147, 148, 151) !important; }";
	css.innerHTML += "\n.feeditem-list.expanded .story-detail-view-container .story-title a { color: #111 !important; }";
	css.innerHTML += "\n.feeditem-read.expanded .story-detail-view-container .story-title a { color: #444 !important; }";
	css.innerHTML += "\n.feed-item-focused.expanded .story-detail-view-container .story-title a { color: #0093cc !important; }";
	document.head.appendChild(css);
*/

	css.innerHTML = "body {";
	css.innerHTML += "\n	color: rgb(204, 204, 204) !important;";
	css.innerHTML += "\n    background-color: #454545 !important;";
	css.innerHTML += "\n}";

	css.innerHTML += "\n.dr-label, .feeditem-read .feeditem-headline {";
	css.innerHTML += "\n    text-shadow: none !important;";
	css.innerHTML += "\n    color: #CCCCCC !important;";
	css.innerHTML += "\n}";

	css.innerHTML += "\n.feeditem-list.expanded .story-detail-view-container .story-title a, .feed-title a {";
	css.innerHTML += "\n    color: #0093cc !important;";
	css.innerHTML += "\n}";

	css.innerHTML += "\n.feed-title a {";
	css.innerHTML += "\n    border-color: #0093cc !important;";
	css.innerHTML += "\n}";

	css.innerHTML += "\n.feed-title a:hover {";
	css.innerHTML += "\n    border-color: #fff !important;";
	css.innerHTML += "\n}";

	css.innerHTML += "\n.feeditem-feedtitle-src, .feeditem-list .feeditem-fuzzytime a {";
	css.innerHTML += "\n    border-bottom: 1px dotted #212121 !important;";
	css.innerHTML += "\n}";

	css.innerHTML += "\n.feeditem-feedtitle-src:hover, .feeditem-fuzzytime a:hover {";
	css.innerHTML += "\n    border-bottom: 1px dotted #CCCCCC !important;";
	css.innerHTML += "\n}";

	css.innerHTML += "\n.view-region-main-container, .site-header, .col-left, .reader-nav .reader-nav-item, .view-add, .feeditem-list.expanded .story-detail-view-container {";
	css.innerHTML += "\n	background-color: #212121 !important;";
	css.innerHTML += "\n}";

	css.innerHTML += "\n.site-header-container, .no-touch .feeditem-list:hover, .no-touch .feeditem-list.expanded, .dr-label:hover, .feed-item-focused .feeditem-feedtitle,";
	css.innerHTML += "\narticle.expanded .feeditem-feedtitle, .feed-item-focused .feeditem-list-content,";
	css.innerHTML += "\narticle.expanded .feeditem-list-content, .discovery-feed-item-controls .btn-add-feed {";
	css.innerHTML += "\n    background-color: #454545 !important;";
	css.innerHTML += "\n}";

	css.innerHTML += "\n.view-add {";
	css.innerHTML += "\n	border: 0 !important;";
	css.innerHTML += "\n}";

	css.innerHTML += "\n#btn-view-all-items, .dr-add-btn, .feed-stream-header, .col-left, .dr-label:hover, .feeditem-list.expanded {";
	css.innerHTML += "\n	border-color: #454545 !important;";
	css.innerHTML += "\n}";

	css.innerHTML += "\n.btn-toggle-read-state, .feeditem-list {";
	css.innerHTML += "\n    border-color: #777 !important;";
	css.innerHTML += "\n}";

	css.innerHTML += "\n.feeditem-list, .discovery-feed-item {";
	css.innerHTML += "\n	border-top: 1px solid #454545 !important;";
	css.innerHTML += "\n}";

	css.innerHTML += "\n.dr-feed-selected>.dr-label, .dr-feed-selected>.dr-label:hover {";
	css.innerHTML += "\n    background-color: rgba(24, 24, 24, 0.901961) !important;";
	css.innerHTML += "\n    border-top-color: rgba(24, 24, 24, 0.901961) !important;";
	css.innerHTML += "\n    border-bottom-color: rgba(24, 24, 24, 0.901961) !important;";
	css.innerHTML += "\n}";

	css.innerHTML += "\n.reader-nav .reader-nav-item {";
	css.innerHTML += "\n	border-left: 1px solid #454545 !important;";
	css.innerHTML += "\n}";

	css.innerHTML += "\n.view-add>div, .boxshadow .site-header-container {";
	css.innerHTML += "\n    -webkit-box-shadow: inset 0 1px 0 0 #454545 !important;";
	css.innerHTML += "\n    box-shadow: inset 0 1px 0 0 #454545 !important;";
	css.innerHTML += "\n}";

	css.innerHTML += "\n#site-header-logo {";
	css.innerHTML += "\n    background-image: none !important;";
	css.innerHTML += "\n}";

	css.innerHTML += "\n.discovery-search-form-wrap form {";
	css.innerHTML += "\n    background-color: #454545 !important;";
	css.innerHTML += "\n    border: 1px solid #212121 !important;";
	css.innerHTML += "\n    -webkit-box-shadow: inset 0 1px 0 0 #454545 !important;";
	css.innerHTML += "\n    box-shadow: inset 0 1px 0 0 #454545 !important;";
	css.innerHTML += "\n}";

	css.innerHTML += "\ninput {";
	css.innerHTML += "\n    color: #ccc !important;";
	css.innerHTML += "\n}";

	css.innerHTML += "\n.discovery-search-header {";
	css.innerHTML += "\n    border-bottom: 2px solid #454545 !important;";
	css.innerHTML += "\n}";

	css.innerHTML += "\n.btn-action {";
	css.innerHTML += "\n    border: 1px solid #454545 !important;";
	css.innerHTML += "\n}";

	css.innerHTML += "\n.discovery-feed-item-controls .btn-add-feed:hover {";
	css.innerHTML += "\n    background-color: #0093cc !important;";
	css.innerHTML += "\n    border-color: #0093cc !important;";
	css.innerHTML += "\n}";
	document.head.appendChild(css);
};

window.addEventListener("load", function(event) { window.customizeBG(); }, false);

window.addEventListener("MacPinWebViewChanged", function(event) {
	window.macpinIsTransparent = event.detail["transparent"];
	window.customizeBG();
}, false);
