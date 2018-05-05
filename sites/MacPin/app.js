/*
 * eslint-env applescript
 * eslint-env builtins
 * eslint-env es6
 * eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0
*/
"use strict";

var delegate = {}; // our delegate to receive events from the webview app

delegate.openInChrome = function(tab) {
	console.log(tab.url);
	switch ($.app.platform) {
		case "OSX":
			$.app.openURL(tab.url, "com.google.Chrome");
			break;
		case "iOS":
			$.app.openURL(tab.url,
				url.startsWith("https://") ? "googlechromes" : "googlechrome");
			break;
	}
};

// handles cmd-line and LaunchServices openURL()s
delegate.launchURL = function(url) {
	console.log("app.js: launching " + url);
	var comps = url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift();
	switch (scheme + ':') {
		default:
			$.browser.tabSelected = new $.WebView({url: url}); //FIXME: retains???!
	}
};

delegate.networkIsOffline = function(url, tab) {
	console.log(`Could not navigate to ${url} - network is offline!`);
}

// handles all URLs drag-and-dropped into MacPin.
delegate.handleDragAndDroppedURLs = function(urls) {
	var ret = false;
	console.log(urls);
	for (let url of urls) {
		$.browser.tabSelected.evalJS(`confirm('Open a new tab for: ${url}');`, function(response) {
			if (response) {
				var tab = new $.WebView({url: url});
				//$.browser.tabSelected = tab;
				$.browser.pushTab(tab);
				ret = true;
			}
		})
	}
	return ret;
};

delegate.decideNavigationForMIME = function(mime, url, webview) {
	console.log(`${mime} : ${url}`);
	switch (mime) {
		case 'audio/mpegurl': // m3u8
		case 'application/x-mpegurl':
		case 'application/vnd.apple.mpegurl':
			// FIXME: ensure url is for main frame
			webview.loadURL('file://' + $.app.resourcePath + '/media_player.html?src=' + url); // FIXME: urldecode(url)
			return true;
		default:
			break;
	}
	return false;
}

delegate.setAgent = function(agent, tab) { tab.userAgent = agent; };
delegate.img2data = function(tab) {
	if (!tab) tab = $.browser.tabSelected;
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

delegate.testAS = function(tab) { $.app.callJXALibrary('test', 'doTest', Array.prototype.slice.call(arguments)); };

delegate.AppFinishedLaunching = function() {
	//$.browser.unhideApp();

	$.browser.addShortcut('MacPin @ GitHub', 'http://github.com/kfix/MacPin');
	$.browser.addShortcut('WebKit Feature Status', 'https://webkit.org/status/');
	$.browser.addShortcut('WebKit Blog', 'https://webkit.org/blog/');
	$.browser.addShortcut('Apple WebKit API reference', 'https://developer.apple.com/reference/webkit');
	$.browser.addShortcut('Browsing Test', 'http://browsingtest.appspot.com');
	$.browser.addShortcut('resizeMyBrowser', 'http://resizemybrowser.com');

	// http://user-agents.me
	$.browser.addShortcut('UA: Safari 11 Mac', ["setAgent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_12_5) AppleWebKit/604.1.29 (KHTML, like Gecko) Version/11.0 Safari/604.1.129"]);
	$.browser.addShortcut('UA: Safari 8 Mac', ["setAgent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_3) AppleWebKit/600.6.3 (KHTML, like Gecko) Version/8.0.6 Safari/600.6.3"]);
	$.browser.addShortcut('UA: iPhone', ["setAgent", "Mozilla/5.0 (iPhone; CPU iPhone OS 8_1 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12B410 Safari/600.1.4"]);
	$.browser.addShortcut('UA: iPad', ["setAgent", "Mozilla/5.0 (iPad; CPU OS 8_1 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12B410 Safari/600.1.4"]);
	$.browser.addShortcut('UA: iPod Touch', ["setAgent", "Mozilla/5.0 (iPad; CPU OS 8_1 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12B410 Safari/600.1.4"]);
	$.browser.addShortcut('UA: Mac Chrome 29', ["setAgent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/29.0.1547.57 Safari/537.36"]);
	$.browser.addShortcut('UA: Mac Firefox 23', ["setAgent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.9; rv:23.0) Gecko/20100101 Firefox/23.0"]);
	$.browser.addShortcut('UA: IE 10', ["setAgent", "Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.2; Win64; x64; Trident/6.0)"]);

	$.browser.addShortcut('see.js console', ['injectTab', 'seeDebugger', 'see.init();', false]); // http://davidbau.com/archives/2013/04/19/debugging_locals_with_seejs.html
	$.browser.addShortcut('Simulate TouchEvents', ['injectTab', 'thumbs', '', false]); // http://mwbrooks.github.io/thumbs.js/
	$.browser.addShortcut('Log DnDs to console', ['injectTab', 'dnd', '', false]);
	$.browser.addShortcut('pop-open 1st image as data:// URL', ['img2data']);
	$.browser.addShortcut('Paint It Black', ['enDarken']);
	$.browser.addShortcut('test AppleScript', ['testAS', "whooo", '1']);

	// a dual-mode REPL like this loaded in another browser would be nice: http://reality.hk/2014/01/12/building-a-ios-ruby-repl/

	if ($.app.doesAppExist("com.google.Chrome")) $.browser.addShortcut('Open in Chrome', ['openInChrome']);

	var editor = {
		transparent: true,
		url: 'data:text/html,'+escape('<html contenteditable>') // https://coderwall.com/p/lhsrcq/one-line-browser-notepad
		// should use ace http://ace.c9.io/#nav=about
		// or CodeMirror.net
	};
	$.browser.addShortcut('HTML5 editor', editor);

	//$.browser.addShortcut('HTML5 editor -> preview', editorPreview);
	//editorPreview should find editor tab (passed by ref?) and render its source

	var repl = {
		transparent: true,
		url: 'file://'+ $.app.resourcePath + '/repl.html',
		handlers: ['evalREPL', 'closeREPL']
	};
	$.browser.addShortcut('MacPin/app.js debugging REPL', repl);
	if ($.app.platform === "OSX") $.app.changeAppIcon(`file://${$.app.resourcePath}/icon.png`);
	$.browser.tabSelected = new $.WebView({url: 'http://github.com/kfix/MacPin'});
};

delegate.evalREPL = function(tab, msg) {
	var command = msg;
	var result;
	try {
		result = eval(command);
	} catch(e) {
		result = e;
	}
	var ret = delegate.REPLprint(result);
	console.log(ret);
	tab.evalJS(`window.dispatchEvent(new window.CustomEvent('returnREPL',{'detail':{'result': ${ret}}}));`);
	tab.evalJS(`returnREPL('${escape(ret)}');`);
};

delegate.closeREPL = function(tab, msg) {
	tab.close();
};

$.app.loadAppScript(`file://${$.app.resourcePath}/app_injectTab.js`);
$.app.loadAppScript(`file://${$.app.resourcePath}/app_repl.js`);
$.app.loadAppScript(`file://${$.app.resourcePath}/enDarken.js`);

delegate; //return this to macpin
