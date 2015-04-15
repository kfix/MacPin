// pinched from Marc Hoyois' ClickToPlugin extension
// https://hoyois.github.io/safariextensions/universalextension/#html5_blocker
// https://developer.apple.com/library/safari/documentation/AudioVideo/Conceptual/Using_HTML5_Audio_Video/Introduction/Introduction.html
document.addEventListener('beforeload', handleBeforeLoadEvent, true);

function handleBeforeLoadEvent(event) {
	if (!(event.target instanceof HTMLMediaElement)) return;
	event.target.autoplay = false;
	event.target.preload = 'none';
	event.target.controls = true ;
	console.log('video unpreloaded');
}
