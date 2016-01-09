/* eslint-env browser */
/* eslint-env builtins */
// WK2 doesn't have delegates for requesting permission
// so we swizzle MacPin's notification hook into the Notification API object.
// https://developer.mozilla.org/en-US/docs/Web/API/Notification/Using_Web_Notifications

// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/WebProcess/Notifications/NotificationPermissionRequestManager.cpp
// https://github.com/WebKit/webkit/blob/master/Source/WebKit2/WebProcess/Notifications/WebNotificationManager.cpp
// https://github.com/WebKit/webkit/commit/99a0a5c064faada93ed5c3af995e982ab751dfb0
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

//null out the deprecated pre-W3C API
// delete window.webkitNotifications;
window.webkitNotifications.checkPermission = null; // function(){return true;}
window.webkitNotifications.requestPermission = null; // true
window.webkitNotifications.createNotifcation = null; // function(icon, title, text){ webkit.messageHandlers.receivedHTML5DesktopNotification.postMessage({title: title, icon: icon, text: text}); };

