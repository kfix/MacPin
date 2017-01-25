/* eslint-env es6 */
delegate.enDarken = function(tab) {
	let idx = tab.styles.indexOf('enDarken');
	(idx >= 0) ? tab.popStyle(idx) : tab.style('enDarken');
	return;

	// I really wish this worked in WebKit: https://developer.mozilla.org/en-US/docs/Web/CSS/Alternative_style_sheets
	//   https://developer.mozilla.org/en-US/docs/Web/API/Document/preferredStyleSheetSet
	//   http://www.thesitewizard.com/css/switch-alternate-css-styles.shtml
};
