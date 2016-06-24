/* eslint-env es6 */
delegate.enDarken = function(tab) {
	// adapted from https://lnikki.la/articles/night-mode-css-filter/
	tab.evalJS(`
		var css = document.getElementById('enDarken');
		if (css) {
			document.head.removeChild(css); //toggle
		} else {
			var css = document.createElement("style");
			css.id = "enDarken";
			css.type = 'text/css';
			css.innerText = \`
				html, img, video {
					-webkit-filter: invert(1) hue-rotate(180deg);
					filter: invert(1) hue-rotate(180deg);
				}
				body { background: black; }
			\`
			document.head.appendChild(css);
		}
	`);
};
