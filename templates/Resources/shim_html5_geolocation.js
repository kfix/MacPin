// on OSX, geolocation object exists but permission prompts do not fire on wkwebview.UIDelegate and location calls are disabled.
// work around this with our own app-thread CLLocationManager and postMessage calls

// https://developer.mozilla.org/en-US/docs/Web/API/Geolocation
// https://developer.mozilla.org/en-US/docs/Web/API/Geolocation/Using_geolocation
navigator.geolocation.getCurrentPosition = function(cb, errcb, opts) {
	webkit.messageHandlers.getGeolocation.postMessage(opts);
	// add listener for Geolocation events with cb linked

	document.addEventListener('gotCurrentPosition', function(e) {
		cb(e.location)
	}
};
navigator.geolocation.watchPosition = function(cb, errcb, opts) {
	webkit.messageHandlers.watchGeolocation.postMessage([opts, id]);
	// add listener for Geolocation events with cb linked
	return id; //random ?
};
navigator.geolocation.clearWatch = function(id) {
	// remove listener id from JS-stored id table
	// if no more id's in the table, then: 
		webkit.messageHandlers.unwatchGeolocation.postMessage(id);
};
