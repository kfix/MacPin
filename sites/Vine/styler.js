(function(){
var css = document.createElement("style");
css.type = 'text/css';
css.id = 'macpin'
css.innerHTML = "\
		button.app-banner { display: none; !important; }\
		header { margin-top: 0px !important; }\
			";
document.head.appendChild(css);
})()
