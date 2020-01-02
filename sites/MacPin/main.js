/*
 * eslint-env applescript
 * eslint-env builtins
 * eslint-env es6
 * eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0
*/
"use strict";

console.log(`evaluating ${__dirname} ${__filename}`);
console.assert(module === require.main);

// https://github.com/electron/electron-quick-start/blob/master/main.js
const {app, BrowserWindow, WebView} = require('@MacPin');
let injectTab = require('app_injectTab.js');
let enDarken = require('enDarken.js');

var docTab = new WebView("file:///usr/share/doc/cups/index.html");
var gitTab = new WebView({url: 'https://github.com/kfix/MacPin'});
//var gooTab = new WebView({url: "http://google.com"})

let browser = new BrowserWindow();

function readability(tab) {
	// do the bookmarklet stuff for "Reading Mode"
	console.trace();

	// https://github.com/mozilla/readability/blob/master/Readability.js
	let pkg = 'Readability'; // i keep typo'ing this, lol

	//inject & evalJS are both async so we need some blocking here ...

	tab.style(pkg);

	let popupReader = `
		(() => {
			let readr = new ${pkg}(window.document.cloneNode(true), {debug: false}).parse();
			console.log(readr);

			//let popup = window.open('about:readability', '_blank'); // i get same-origin errors with this
			let popup = window.open();
			// Inherited origins: Content from about:blank, javascript: and data: URLs inherits the origin from the document that loaded the URL

			// debugs
			//console.log(popup);
			//console.log(popup.location);
			//console.log(popup.document.origin === window.document.origin);
			// ^ same-origin policy must pass if we want to manipulate the popup's DOM!
			//console.log(popup.opener.location); // window.open(...,'noopener') to prevent
			//window.readerArticle = readr;
			//window.readerPopup = popup;

			popup.document.write(readr.content);
			popup.document.title = 'Reading: ' + readr.title;
			//console.log(popup.document.body);

			popup.focus(); // notimpld yet
		})();
	`;

	injectTab(pkg, popupReader, false, tab);
}

app.on('didWindowOpenForURL', function(url, newTab, tab) {
	if (url.length > 0 && newTab)
		console.log(`window.open(${url})`);

	return false; // macpin will popup(newTab, url) and return newTab to tab's JS
});

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

let proxiedTab = function(proxy, sproxy, currentTab) {
	browser.tabSelected = new WebView({proxy: proxy, sproxy: sproxy});
};

let setAgent = function(agent, tab) { tab.userAgent = agent; };
let getAgent = function(tab) { tab.evalJS(`window.alert(navigator.userAgent);`); };
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

let replTab;
// var-decl needed to retain the tab, which is "dropped" & deinit()d in a proxied-push() if not bound to a persistent scope
let launchRepl = () => {
	var evalRepl = (tab, msg) => {
		var command = msg;
		var result, exception;
		try {
			result = Function(`"use strict";return (${command})`).bind(window)(); // MDN sez dis moar betta
		} catch(e) {
			exception = e;
			result = e; // printToREPL will make a line pointer object
			try { console.log(e); } catch(e) { }
		}
		var ret = app.eventCallbacks['printToREPL'][0](result, false); // expr, colorize
		//try { console.log(ret); } catch(e) { }
		let exfil = `returnREPL('${escape(ret)}', ${(exception) ? `'${escape(exception)}'` : 'null'});`;
		//console.log(exfil); // use base64 instead of urlencode??
		tab.evalJS(exfil);
	};

	var closeRepl = (tab, msg) => tab.close();

	var cfgRepl = {
		transparent: true,
		//url: 'file://'+ app.resourcePath + '/repl.html', // < doesn't work from spaces in names ...
		url: app.resourceURL + '/repl.html',
		caching: false,
		handlers: {
			'evalREPL': [evalRepl, true, "hello", 42],
			'closeREPL': closeRepl,
			'fooEvent': [(tab) => {console.log(tab.urlstr)}, 1],
			'nullEvent': null
		}
	};

    try {
	  replTab = new WebView(cfgRepl);
	  console.log(`selecting ${replTab.url}`);
	  browser.tabSelected = replTab;
	} catch (e) {
      if (e instanceof TypeError) {
         console.error("could not load WebView!", cfgRepl);
      } else {
        throw e;
      }
    }

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

function sendNoteFromTab(msg, tab) {
	app.postHTML5Notification({title: tab.title, subtitle: tab.url, body: msg, type: 1, tabHash: tab.hash, origin: app.resourcePath});
}

app.on('AppWillFinishLaunching', (AppUI) => {
	//browser.unhideApp();
	browser.addShortcut('Paint It Black', [], enDarken);
	browser.addShortcut('Make it Readable', [], readability);

	browser.addShortcut('localhost:8080 proxied tab', ["http://localhost:8080", "http://localhost:8080"], proxiedTab);
	// cask install squidman

	browser.addShortcut('MacPin @ GitHub', 'http://github.com/kfix/MacPin');
	browser.addShortcut('WebKit Feature Status', 'https://webkit.org/status/');
	browser.addShortcut('WebKit Blog', 'https://webkit.org/blog/');
	browser.addShortcut('Apple WebKit API reference', 'https://developer.apple.com/reference/webkit');
	browser.addShortcut('Navigation Tests', 'http://browsingtest.appspot.com');
	browser.addShortcut('resizeMyBrowser', 'http://resizemybrowser.com');
	browser.addShortcut('File Upload test', 'https://mdn.github.io/learning-area/html/forms/file-examples/simple-file.html');
	browser.addShortcut('WebRTC effect test', 'https://webkit.org/blog-files/webrtc/pc-with-effects/index.html');
	browser.addShortcut('WebRTC samples', 'https://webrtc.github.io/samples/');
	browser.addShortcut('WebRTC resolution tester', 'https://webrtchacks.github.io/WebRTC-Camera-Resolution/');
	browser.addShortcut('WebRTC loopback test', 'https://appr.tc/?hd=true&stereo=true&debug=loopback');

	browser.addShortcut('HTML5 features report', 'https://html5test.com/');
	browser.addShortcut('HTML5 Geolocation test', 'https://lab.html5test.com/geolocation/');
	browser.addShortcut('HTML5 Notification test', {
		url: 'https://lab.html5test.com/notification/',
		authorizedOriginsForNotifications: [
			'https://lab.html5test.com',
			'https://lab.html5test.com:443'
		]
	});
	browser.addShortcut('AppScript Notification test', ["notified title of current tab"], sendNoteFromTab);
	browser.addShortcut('WebSocket test', 'https://www.websocket.org/echo.html');

	// http://user-agents.me
	browser.addShortcut('Show current User-Agent', [], getAgent);
	browser.addShortcut('Examine WebKit User-Agent', 'http://browserspy.dk/webkit.php');
	browser.addShortcut('Safari Version history', 'https://en.wikipedia.org/wiki/Safari_version_history');
	browser.addShortcut('UA: Safari 11 Mac', ["Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_5) AppleWebKit/604.1.29 (KHTML, like Gecko) Version/11.0 Safari/604.1.129"], setAgent);
	browser.addShortcut('UA: Safari 8 Mac', ["Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_3) AppleWebKit/600.6.3 (KHTML, like Gecko) Version/8.0.6 Safari/600.6.3"], setAgent);
	browser.addShortcut('UA: iPhone', ["Mozilla/5.0 (iPhone; CPU iPhone OS 8_1 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12B410 Safari/600.1.4"], setAgent);
	browser.addShortcut('UA: iPad', ["Mozilla/5.0 (iPad; CPU OS 8_1 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12B410 Safari/600.1.4"], setAgent);
	browser.addShortcut('UA: iPod Touch', ["Mozilla/5.0 (iPod touch; CPU OS 8_1 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12B410 Safari/600.1.4"], setAgent);
	browser.addShortcut('UA: Mac Chrome 29', ["Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/29.0.1547.57 Safari/537.36"], setAgent);
	browser.addShortcut('UA: Mac Firefox 23', ["Mozilla/5.0 (Macintosh; Intel Mac OS X 10.9; rv:23.0) Gecko/20100101 Firefox/23.0"], setAgent);
	browser.addShortcut('UA: Mac Firefox 62', ["Mozilla/5.0 (Macintosh; Intel Mac OS X 10.13; rv:62.0) Gecko/20100101 Firefox/62.0"], setAgent);
	browser.addShortcut('UA: IE 10', ["Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.2; Win64; x64; Trident/6.0)"], setAgent);

	browser.addShortcut('see.js console', ['seeDebugger', 'see.init();', false], injectTab); // http://davidbau.com/archives/2013/04/19/debugging_locals_with_seejs.html
	browser.addShortcut('Simulate TouchEvents', ['thumbs', '', false], injectTab); // http://mwbrooks.github.io/thumbs.js/
	browser.addShortcut('Log DnDs to console', ['dnd', '', false], injectTab);
	browser.addShortcut('pop-open 1st image as data:// URL', [], img2data);
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

	if (app.platform === "OSX") app.changeAppIcon('icon.png');
	//browser.tabSelected = new $.WebView({url: 'http://github.com/kfix/MacPin'});

	AppUI.browserController = browser; // make sure main app menu can get at our shortcuts
	console.log(app.browserController);

	// lets flex tab management flows a bit
	launchRepl(); // late-create a WebView and select it

	// shuffle the _tabs using the tabs Proxy
	browser.tabs.push(gitTab);
	browser.tabs.push(docTab);
	browser.tabs.reverse(); // selection will change to the pushed tab that was flipped #0

	console.log(`reselecting ${replTab.url}`);
	browser.tabSelected = replTab;
});

app.on('AppFinishedLaunching', (launchURLs) => {
	console.log(launchURLs);
	setTimeout((() => {console.log("yay timers work"); console.trace();}), 3.2);
});

// replTab needs this
if (!('printToREPL' in app.eventCallbacks)) {
	let {repl} = require('app_repl.js');
	app.on('printToREPL', repl);
}

app.on('AppShouldTerminate', (app) => {
	console.log("main.js shutting down!");
	docTab = null;
	gitTab = null;
});

// https://www.lucidchart.com/techblog/2018/02/14/javascriptcore-the-holy-grail-of-cross-platform/
//app.loadAppScript('fetchDeps.js`);
//let fetchURL = require('fetchURL');
