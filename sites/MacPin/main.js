/*
 * eslint-env applescript
 * eslint-env builtins
 * eslint-env es6
 * eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0
*/
"use strict";

// https://github.com/electron/electron-quick-start/blob/master/main.js
const {app, BrowserWindow, WebView} = require('@MacPin');
let injectTab = require(`file://${app.resourcePath}/app_injectTab.js`);
let enDarken = require(`file://${app.resourcePath}/enDarken.js`);

var ntpTab = new WebView("file:///usr/share/doc/ntp/index.html");
//var gitTab = new WebView({url: 'http://github.com/kfix/MacPin'});
//var gooTab = new WebView({url: "http://google.com"})

let browser = new BrowserWindow();

let openInChrome = function(tab) {
	console.log(`app.js: opening (${tab.url}) in chrome`);
	switch (app.platform) {
		case "OSX":
			app.openURL(tab.url, "com.google.Chrome");
			break;
		case "iOS":
			app.openURL(tab.url,
				tab.url.startsWith("https://") ? "googlechromes" : "googlechrome");
			break;
	}
};

// handles cmd-line and LaunchServices openURL()s
app.on('launchURL', (url) => {
	console.log("app.js: launching " + url);
	var comps = url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift();
	switch (scheme + ':') {
		default:
			browser.tabSelected = new WebView({url: url}); //FIXME: retains???!
	}
});
// app.on('launchURL', (url) => new $.WebView({url: url}));

app.on('networkIsOffline', (url, tab) => {
	console.log(`Could not navigate to ${url} - network is offline!`);
});

// handles all URLs drag-and-dropped into MacPin.
app.on('handleDragAndDroppedURLs', (urls) => {
	var ret = false;
	console.log(urls);
	for (let url of urls) {
		browser.tabSelected.evalJS(`confirm('Open a new tab for: ${url}');`, function(response) {
			if (response) {
				var tab = new WebView({url: url});
				//$.browser.tabSelected = tab;
				browser.tabs.push(tab);
				ret = true;
			}
		})
	}
	return ret;
});

app.on('decideNavigationForMIME', (mime, url, webview) => {
	console.log(`${mime} : ${url}`);
	switch (mime) {
		case 'audio/mpegurl': // m3u8
		case 'application/x-mpegurl':
		case 'application/vnd.apple.mpegurl':
			// FIXME: ensure url is for main frame
			webview.loadURL('file://' + app.resourcePath + '/media_player.html?src=' + url); // FIXME: urldecode(url)
			return true;
		default:
			break;
	}
	return false;
});

let setAgent = function(agent, tab) { tab.userAgent = agent; };
let img2data = function(tab) {
	if (!tab) tab = browser.tabSelected;
	tab.evalJS(`
		var img = document.images[0];
		img.crossOrigin='Anonymous';
		var canvas = document.createElement('canvas');
		var ctx = canvas.getContext('2d');
		canvas.width = img.naturalWidth;
		canvas.height = img.naturalHeight;
		ctx.drawImage(img,0,0);
		window.open(canvas.toDataURL('image/jpeg'));
	`)
};

let testAS = function(tab) { app.callJXALibrary('test', 'doTest', Array.prototype.slice.call(arguments)); };

if (eval != null)
	var eval_copy = eval; // global eval is wiped after app.js is started ...

let replTab;
// var-decl needed to retain the tab, which is "dropped" & deinit()d in a proxied-push() if not bound to a persistent scope
let launchRepl = () => {
	var evalRepl = (tab, msg) => {
		var command = msg;
		var result, exception;
		try {
			result = eval_copy(command); // <- line pointer marks right here
		} catch(e) {
			exception = e;
			result = e; // printToREPL will make a line pointer object
			try { console.log(e); } catch(e) { }
		}
		var ret = app.emit('printToREPL', result, false); // handler, expr, colorize
		//try { console.log(ret); } catch(e) { }
		let exfil = `returnREPL('${escape(ret)}', ${(exception) ? `'${escape(exception)}'` : 'null'});`;
		//console.log(exfil); // use base64 instead of urlencode??
		tab.evalJS(exfil);
	};

	var closeRepl = (tab, msg) => tab.close();

	var cfgRepl = {
		transparent: true,
		url: 'file://'+ app.resourcePath + '/repl.html',
		handlers: {
			'evalREPL': [evalRepl, true, "hello", 42],
			'closeREPL': closeRepl,
			'fooEvent': [(tab) => {console.log(tab.urlstr)}, 1],
			'nullEvent': null
		}
	};

	replTab = new WebView(cfgRepl);
	console.log(`selecting ${replTab.url}`);
	browser.tabSelected = replTab;

	// https://github.com/remy/jsconsole is much prettier than my repl.html ...
	//    https://github.com/remy/jsconsole/blob/master/public/inject.html
	//    https://github.com/remy/jsconsole/blob/1e3a1ecc86b7da1abe6c1e2e6c018184a19f4b37/public/js/remote.js
	// https://nodejs.org/api/repl.html
	// https://www.npmjs.com/package/react-console-component
	// https://github.com/replit-archive/jq-console
};

/*
 var geniusBarsNearMe() {
	// https://locate.apple.com/sales/?pt=4&lat=37&lon=-122.5 cupertino
	//   /service/
	//  add a lat/lon prop to $.app so we can fudge links
	//  https://developer.apple.com/maps/mapkitjs/
	//  https://developer.apple.com/documentation/mapkitjs
}
*/

app.on('AppWillFinishLaunching', (AppUI) => {
	//browser.unhideApp();

	browser.addShortcut('MacPin @ GitHub', 'http://github.com/kfix/MacPin');
	browser.addShortcut('WebKit Feature Status', 'https://webkit.org/status/');
	browser.addShortcut('WebKit Blog', 'https://webkit.org/blog/');
	browser.addShortcut('Apple WebKit API reference', 'https://developer.apple.com/reference/webkit');
	browser.addShortcut('Browsing Test', 'http://browsingtest.appspot.com');
	browser.addShortcut('resizeMyBrowser', 'http://resizemybrowser.com');
	browser.addShortcut('File Upload test', 'https://mdn.github.io/learning-area/html/forms/file-examples/simple-file.html');
	browser.addShortcut('WebRTC effect test', 'https://webkit.org/blog-files/webrtc/pc-with-effects/index.html');
	browser.addShortcut('WebRTC samples', 'https://webrtc.github.io/samples/');
	browser.addShortcut('WebRTC recorder', 'https://www.webrtc-experiment.com/RecordRTC/');
	browser.addShortcut('WebRTC test', 'https://webrtc.test.org');
	// window.AudioContext = window.AudioContext || window.webkitAudioContext;
	browser.addShortcut('Geolocation test', 'https://onury.io/geolocator/?content=examples');
	browser.addShortcut('Notification test', 'https://ttsvetko.github.io/HTML5-Desktop-Notifications/');

	// http://user-agents.me
	browser.addShortcut('UA: Safari 11 Mac', ["Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_5) AppleWebKit/604.1.29 (KHTML, like Gecko) Version/11.0 Safari/604.1.129"], setAgent);
	browser.addShortcut('UA: Safari 8 Mac', ["Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_3) AppleWebKit/600.6.3 (KHTML, like Gecko) Version/8.0.6 Safari/600.6.3"], setAgent);
	browser.addShortcut('UA: iPhone', ["Mozilla/5.0 (iPhone; CPU iPhone OS 8_1 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12B410 Safari/600.1.4"], setAgent);
	browser.addShortcut('UA: iPad', ["Mozilla/5.0 (iPad; CPU OS 8_1 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12B410 Safari/600.1.4"], setAgent);
	browser.addShortcut('UA: iPod Touch', ["Mozilla/5.0 (iPad; CPU OS 8_1 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12B410 Safari/600.1.4"], setAgent);
	browser.addShortcut('UA: Mac Chrome 29', ["Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/29.0.1547.57 Safari/537.36"], setAgent);
	browser.addShortcut('UA: Mac Firefox 23', ["Mozilla/5.0 (Macintosh; Intel Mac OS X 10.9; rv:23.0) Gecko/20100101 Firefox/23.0"], setAgent);
	browser.addShortcut('UA: IE 10', ["Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.2; Win64; x64; Trident/6.0)"], setAgent);

	browser.addShortcut('see.js console', ['seeDebugger', 'see.init();', false], injectTab); // http://davidbau.com/archives/2013/04/19/debugging_locals_with_seejs.html
	browser.addShortcut('Simulate TouchEvents', ['thumbs', '', false], injectTab); // http://mwbrooks.github.io/thumbs.js/
	browser.addShortcut('Log DnDs to console', ['dnd', '', false], injectTab);
	browser.addShortcut('pop-open 1st image as data:// URL', [], img2data);
	browser.addShortcut('Paint It Black', [], enDarken);
	browser.addShortcut('test AppleScript', ["whooo", '1'], testAS);

	// a dual-mode REPL like this loaded in another browser would be nice: http://reality.hk/2014/01/12/building-a-ios-ruby-repl/

	if (app.doesAppExist("com.google.Chrome")) browser.addShortcut('Open in Chrome', [], openInChrome);

	var editor = {
		transparent: true,
		url: 'data:text/html,'+escape('<html contenteditable>') // https://coderwall.com/p/lhsrcq/one-line-browser-notepad
		// should use ace http://ace.c9.io/#nav=about
		// or CodeMirror.net
	};
	browser.addShortcut('HTML5 editor', editor);

	//browser.addShortcut('HTML5 editor -> preview', editorPreview);
	//editorPreview should find editor tab (passed by ref?) and render its source

	//browser.addShortcut('MacPin/app.js debugging REPL', cfgRepl);
	//  WebView.init ends up with WebViewInitProps.handlers: <__NSFrozenDictionaryM>
	browser.addShortcut('MacPin/app.js debugging REPL', [], launchRepl);

	if (app.platform === "OSX") app.changeAppIcon(`file://${app.resourcePath}/icon.png`);
	//browser.tabSelected = new $.WebView({url: 'http://github.com/kfix/MacPin'});

	AppUI.browserController = browser; // make sure main app menu can get at our shortcuts
	console.log(app.browserController);

	// lets flex tab management flows a bit
	launchRepl(); // late-create a WebView and select it

	// shuffle the _tabs using the tabs Proxy
	browser.tabs.push(ntpTab);
	browser.tabs.reverse(); // selection will change to the pushed tab that was flipped #0

	console.log(`reselecting ${replTab.url}`);
	browser.tabSelected = replTab;
});

app.on('AppFinishedLaunching', (launchURLs) => {
	console.log(launchURLs);
	if (!('printToREPL' in app.eventCallbacks)) {
		app.loadAppScript(`file://${app.resourcePath}/app_repl.js`);
	}
});

// https://www.lucidchart.com/techblog/2018/02/14/javascriptcore-the-holy-grail-of-cross-platform/
//$.app.loadAppScript(`file://${$.app.resourcePath}/fetchURL.js`);
//$.app.loadAppScript(`file://${$.app.resourcePath}/fetchDeps.js`);
//var fetch = require('fetch').fetch;
