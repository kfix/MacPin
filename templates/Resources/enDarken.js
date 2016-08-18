/* eslint-env es6 */
delegate.enDarken = function(tab) {
	let idx = tab.styles.indexOf('enDarken');
	(idx >= 0) ? tab.popStyle(idx) : tab.style('enDarken');
	return;

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
				:root, img, video, object, iframe, *:not(object):not(body)>embed, *[style*="background:url"]:empty, *[style*="background-image:url"]:empty, *[style*="background: url"]:empty, *[style*="background-image: url"]:empty {
					filter: invert(1) hue-rotate(180deg);
				}
				:root { background: white; }
			\`
			document.head.appendChild(css);
		}
	`);
};
