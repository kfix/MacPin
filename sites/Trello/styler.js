var macpinIsTransparent;

var customizeBG = function() {
	var css = document.getElementById('customizeBG');
	if (!css) {
		var css = document.createElement("style");
		css.id = "customizeBG";
		css.type = 'text/css';
	}
	if (window.macpinIsTransparent) {
	    css.innerHTML = "body { background-color: rgba(125, 126, 244, 0.07) !important; } "; //Dark-Purple with translucency
		// should just get rgb=getComputedStyle(document.body).backgroundColor.match(/[\d\.]+/g) and convert from original rgb() to rgba()
		// http://stackoverflow.com/q/6672374/3878712 http://davidwalsh.name/detect-invert-color
	} else {
	    css.innerHTML = "body { background-color: rgb(14, 116, 175) !important; } "; //stock Trello blue
	}
	document.head.appendChild(css);
}

window.addEventListener("load", function(event) { window.customizeBG(); }, false);

window.addEventListener("macpinTransparencyChanged", function(event) {
	window.macpinIsTransparent = event.detail["isTransparent"];
	window.customizeBG();
}, false);

/*

//trello uses HTML5 pushState and Backbone.js, so this script needs to corrupt their machiniations
(function(history){
	var pushState = history.pushState;
	history.pushState = function(state) {
	if (typeof history.onpushstate == "function") {
		history.onpushstate({state: state});
	}
	return pushState.apply(history, arguments);
	}
})(window.history);
history.onpushstate = function(event) {
	setTimeout(window.customizeBG, 20000) //wait for new HTML to be generated
};

window.addEventListener("popstate", function(event) {
	// happens onLoad (Safari bug) and on manual fwd/backs, but not through board/card navigation pushState()s
	window.customizeBG();
}, false);

*/
