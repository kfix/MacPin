/*
 How nice of Slack to not obfuscate or IIFE their JS!
*/

// we can't cache user's intention, so just presume they want notifications
TS.ui.growls.promptForPermission(); // Motification.permission == "granted"
window.TS.ui.growls.checkPermission = function() { console.log("checked usernote perms!"); return true; }
// TS.ui.growls.showTestNotification("title","message", () => console.log("test note clicked!") )
