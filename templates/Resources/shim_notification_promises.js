/* eslint-env browser */
/* eslint-env builtins */

// Safari only supports the pre-promised W3C Notifications spec, so Electron/Chromey pages can't acquire permissions
	// https://developer.apple.com/library/archive/documentation/NetworkingInternet/Conceptual/NotificationProgrammingGuideForWebsites/LocalNotifications/LocalNotifications.html#//apple_ref/doc/uid/TP40012932-SW1
	// Notification.requestPermission( (rp) => console.log(rp) ) -> undefined // `granted`

//   new spec sez should have gotten a Promise so I could
	// Notification.requestPermission.then( (rp) => console.log(rp) )

window.Notification._requestPermission = window.Notification.requestPermission;
// https://github.com/ttsvetko/HTML5-Desktop-Notifications/blob/master/src/Notification.js
Object.defineProperty(window.Notification, 'requestPermission', {
    enumerable: true,
    writable: true,
    value: function(callback) {
        return new Promise(function(resolve, reject) {
            window.Notification._requestPermission(function(permission) {
                resolve(permission);
            });
        });
    }
});
