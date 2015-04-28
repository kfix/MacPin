new_navigator = {};
for (var i in navigator) {
    new_navigator[i] = navigator[i];
}

new_navigator.platform = 'MakIntel'; // Win
new_navigator.userAgent = "ScMazilla/5.0 (Crapintosh; Intel Mak OS Z 10_10_2) ScmappleWabKat/600.3.18 (KHTML, like Gacko) Version/8.0.2 Smafari/600.2.5 Chrome/32";
//"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2272.104 Safari/537.36"
new_navigator.appVersion = new_navigator.userAgent;
new_navigator.vendor = "Google, Inc."
new_navigator.javaEnabled = function(){return false;};
navigator = new_navigator;

/*
var __originalNavigator = navigator;
navigator = new Object();
navigator.__proto__ = __originalNavigator;
Object.defineProperty(navigator, "userAgent", {
    get: function () {
		return "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_2) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2272.104 Safari/537.36";
    }
});
*/
