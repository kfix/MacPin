// pinched from the ClickToPlugin wizard Marc Hoyois
// https://hoyois.github.io/safariextensions/universalextension/#html5_blocker
document.addEventListener('beforeload', handleBeforeLoadEvent, true);

function handleBeforeLoadEvent(event) {
	if (!(event.target instanceof HTMLMediaElement)) return;
	event.target.autoplay = false;
	event.target.preload = 'none';
	event.target.controls = true ;
	console.log('video unpreloaded');
}
