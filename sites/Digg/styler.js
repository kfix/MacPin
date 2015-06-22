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
	css.innerHTML = "\
		body {\
			color: rgb(204, 204, 204) !important;\
		    background-color: #454545 !important;\
		}\
		.dr-label, .feeditem-read .feeditem-headline {\
		    text-shadow: none !important;\
		    color: #CCCCCC !important;\
		}\
		.feeditem-list.expanded .story-detail-view-container .story-title a, .feed-title a {\
		    color: #0093cc !important;\
		}\
		.feed-title a {\
		    border-color: #0093cc !important;\
		}\
		.feed-title a:hover {\
		    border-color: #fff !important;\
		}\
		.feeditem-feedtitle-src, .feeditem-list .feeditem-fuzzytime a {\
		    border-bottom: 1px dotted #212121 !important;\
		}\
		.feeditem-feedtitle-src:hover, .feeditem-fuzzytime a:hover {\
		    border-bottom: 1px dotted #CCCCCC !important;\
		}\
		.view-region-main-container, .site-header, .col-left, .reader-nav .reader-nav-item, .view-add, .feeditem-list.expanded .story-detail-view-container {\
			background-color: #212121 !important;\
		}\
		.site-header-container, .no-touch .feeditem-list:hover, .no-touch .feeditem-list.expanded, .dr-label:hover, .feed-item-focused .feeditem-feedtitle,\
		article.expanded .feeditem-feedtitle, .feed-item-focused .feeditem-list-content,\
		article.expanded .feeditem-list-content, .discovery-feed-item-controls .btn-add-feed {\
		    background-color: #454545 !important;\
		}\
		.view-add {\
			border: 0 !important;\
		}\
		#btn-view-all-items, .dr-add-btn, .feed-stream-header, .col-left, .dr-label:hover, .feeditem-list.expanded {\
			border-color: #454545 !important;\
		}\
		.btn-toggle-read-state, .feeditem-list {\
		    border-color: #777 !important;\
		}\
		.feeditem-list, .discovery-feed-item {\
			border-top: 1px solid #454545 !important;\
		}\
		.dr-feed-selected>.dr-label, .dr-feed-selected>.dr-label:hover {\
		    background-color: rgba(24, 24, 24, 0.901961) !important;\
		    border-top-color: rgba(24, 24, 24, 0.901961) !important;\
		    border-bottom-color: rgba(24, 24, 24, 0.901961) !important;\
		}\
		.reader-nav .reader-nav-item {\
			border-left: 1px solid #454545 !important;\
		}\
		.view-add>div, .boxshadow .site-header-container {\
		    -webkit-box-shadow: inset 0 1px 0 0 #454545 !important;\
		    box-shadow: inset 0 1px 0 0 #454545 !important;\
		}\
		#site-header-logo {\
		    background-image: none !important;\
		}\
		.discovery-search-form-wrap form {\
		    background-color: #454545 !important;\
		    border: 1px solid #212121 !important;\
		    -webkit-box-shadow: inset 0 1px 0 0 #454545 !important;\
		    box-shadow: inset 0 1px 0 0 #454545 !important;\
		}\
		input {\
		    color: #ccc !important;\
		}\
		.discovery-search-header {\
		    border-bottom: 2px solid #454545 !important;\
		}\
		.btn-action {\
		    border: 1px solid #454545 !important;\
		}\
		.discovery-feed-item-controls .btn-add-feed:hover {\
		    background-color: #0093cc !important;\
		    border-color: #0093cc !important;\
		}\
	";
	document.head.appendChild(css);
};

window.addEventListener("load", function(event) { window.customizeBG(); }, false);

window.addEventListener("MacPinWebViewChanged", function(event) {
	window.macpinIsTransparent = event.detail["transparent"];
	window.customizeBG();
}, false);
