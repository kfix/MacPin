(function(){
var css = document.createElement("style");
css.type = 'text/css';
css.id = 'macpin'

// make news feed take full width and jewel bar float at top
css.innerHTML = "\
	#header { position: fixed !important; top: 0px !important; }\
	#main { width: auto !important; }\
	._e_- { max-width: 10000px !important; }\
	.mHomeNewsfeed {\
		margin-left: 0px !important;\
		margin-right: 0px !important;\
	}\
";

document.head.appendChild(css);
})()
