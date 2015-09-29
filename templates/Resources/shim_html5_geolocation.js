/* eslint-env browser */
/* eslint-env builtins */
/* eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0 */
"use strict";
// on OSX, geolocation object exists but permission prompts do not fire on wkwebview.UIDelegate and location calls are disabled.
// work around this with our own app-thread CLLocationManager and postMessage calls

// https://developer.mozilla.org/en-US/docs/Web/API/Geolocation
// https://developer.mozilla.org/en-US/docs/Web/API/Geolocation/Using_geolocation
// http://www.w3.org/TR/geolocation-API/


// https://github.com/inexorabletash/polyfill/blob/master/geo.js
var EARTH_RADIUS_M = 6.384e6;
function Coordinates(data) {
	this.latitude = Number(data.latitude);
	this.longitude = Number(data.longitude);
	this.altitude = null;
	this.accuracy = 65; //EARTH_RADIUS_M * Math.PI;
	this.altitudeAccuracy = null;
	this.heading = null;
	this.speed = null;
}
function Geoposition(data) {
	this.coords = new Coordinates(data);
	this.timestamp = Date.now();
}

navigator.geolocation.getCurrentPosition = function(cb, errcb, opts) {
	webkit.messageHandlers.getGeolocation.postMessage(opts); // will fire gotCurrentGeolocation when fix acheived

	window.addEventListener("gotCurrentGeolocation", function(e) {
		window.removeEventListener('gotCurrentGeolocation', this, false); //one-time update
		var pos = new Geoposition(e.detail);
		//console.log(pos);
		cb(pos);
		// compare result with navigator.geolocation.getCurrentPosition(function(pos){console.log(pos);})
	});

};

navigator.geolocation.watchPosition = function(cb, errcb, opts) {
	var id = Math.floor(Math.random() * 400000).toString()
	webkit.messageHandlers.watchGeolocation.postMessage([opts, id]);
	// add listener for Geolocation events with cb linked
	return id; //random ?
};

navigator.geolocation.clearWatch = function(id) {
	// remove listener id from JS-stored id table
	// if no more id's in the table, then:
		webkit.messageHandlers.unwatchGeolocation.postMessage(id);
};
