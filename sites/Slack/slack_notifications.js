/*
 How nice of Slack to not obfuscate or IIFE their JS!
*/

// we can't cache user's intention, so just presume they want notifications
window.TS.ui.growls.checkPermission = function() { return true; }
