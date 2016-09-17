/* eslint-env browser */
/* eslint-env builtins */
// WK2 doesn't have delegates for requesting permission
// so we swizzle MacPin's notification hook into the Notification API object.
// https://developer.mozilla.org/en-US/docs/Web/API/Notification/Using_Web_Notifications

// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/WebProcess/Notifications/NotificationPermissionRequestManager.cpp
// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/WebProcess/Notifications/WebNotificationManager.cpp
// https://github.com/WebKit/webkit/commit/99a0a5c064faada93ed5c3af995e982ab751dfb0
// https://github.com/WebKit/webkit/search?q=decidePolicyForNotificationPermissionRequest
//   https://github.com/WebKit/webkit/blob/8e4ed211342ab489a964e980be022cdf63824a8f/Source/WebKit2/UIProcess/WebPageProxy.cpp#L5677
//   https://github.com/WebKit/webkit/blob/2b5a967568e17a0945b9e4050c23986537643c77/Source/WebKit2/UIProcess/API/APIUIClient.h#L137
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

	Notification.requestPermission = function(callback){ this.permission = "granted"; if (typeof callback == "function") callback("granted"); };
	Notification.permission = "default";

	return Notification;
}();

window.Notification = NotificationShim;

/*
// handle the deprecated pre-W3C API too
var wkNotificationShim = {
	checkPermission: function() { return 0; }, // PERMISSION_ALLOWED
	requestPermission: function(cb) { window.Notification.requestPermission(cb); },
	createNotification: function(icon, title, text){ webkit.messageHandlers.receivedHTML5DesktopNotification.postMessage({title: title, icon: icon, text: text}); }
}
window.webkitNotifications.__proto__ = wkNotificationShim;
//window.webkitNotifications.__proto__ = null;
*/

delete window.webkitNotifications; // proto is set but native "NotificationCenter" remains...
