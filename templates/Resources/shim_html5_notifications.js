/* eslint-env: applescript */
// WK2 doesn't have delegates for requesting permission
// so we swizzle MacPin's notification hook into the Notification API object.
// https://developer.mozilla.org/en-US/docs/Web/API/Notification/Using_Web_Notifications

var NotificationShim = function() {

	function Notification(title, options) { // constructor
		var note = new Object();
		for (var i in options) { note[i] = options[i]; }
		console.log(options);
		note.title = title;
		//note.show = function() {
			webkit.messageHandlers.receivedHTML5DesktopNotification.postMessage(note);
			/*
			webkit.messageHandlers.receivedHTML5DesktopNotification.postMessage(post);
			*/
		//}
		note.close = function(){ }; //noop to recall notification
		//EventTarget.addEventListener .cancelEventListener .dispatchEvent(ev)
		//.data title dir lang body tag icon
		return note;
	}

	Notification.prototype = {
	};

	Notification.requestPermission = function(callback){ if (typeof callback == "function") callback("granted"); };
	Notification.permission = "granted";

	return Notification;
}();

window.Notification = NotificationShim;

