/*eslint-env applescript*/
/*eslint-env builtins*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

var delegate = {}; // our delegate to receive events from the webview app

delegate.openInChrome = function() {
	console.log($.browser.tabSelected.url);
	$.app.openURL($.browser.tabSelected.url, "com.google.Chrome");
	// need iOS version
};

// handles cmd-line and LaunchServices openURL()s
delegate.launchURL = function(url) {
	console.log("app.js: launching " + url);
	var comps = url.split(':'),
		scheme = comps.shift(),
		addr = comps.shift();
	switch (scheme + ':') {
		default:
			$.browser.tabSelected = new $.WebView({url: url});
	}
};

// handles all URLs drag-and-dropped into MacPin.
delegate.handleDragAndDroppedURLs = function(urls) {
	var ret = false;
	console.log(urls);
	for (var url of urls) {
		$.browser.tabSelected.evalJS("confirm('Open a new tab for: "+url+"');", function(response) {
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

delegate.injectTab = function(script, init) {
	if ($.browser.tabSelected.postinject(script)) {
		$.browser.tabSelected.evalJS('window.location.reload(false);'); // must reload page after injection
		if (init) $.browser.tabSelected.asyncEvalJS(init, 2);
	} else { // script is already injected, so just init it again
		if (init) $.browser.tabSelected.evalJS(init);
	}
};

delegate.setAgent = function(agent) { $.browser.tabSelected.userAgent = agent; };

delegate.AppFinishedLaunching = function() {
	//$.browser.unhideApp();

	$.browser.addShortcut('MacPin @ GitHub', 'http://github.com/kfix/MacPin');
	$.browser.addShortcut('Browsing Test', 'http://browsingtest.appspot.com');
	$.browser.addShortcut('resizeMyBrowser', 'http://resizemybrowser.com');

	// http://user-agents.me
	$.browser.addShortcut('UA: Safari Mac', ["setAgent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_3) AppleWebKit/600.6.3 (KHTML, like Gecko) Version/8.0.6 Safari/600.6.3"]);
	$.browser.addShortcut('UA: iPhone', ["setAgent", "Mozilla/5.0 (iPhone; CPU iPhone OS 8_1 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12B410 Safari/600.1.4"]);
	$.browser.addShortcut('UA: iPad', ["setAgent", "Mozilla/5.0 (iPad; CPU OS 8_1 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12B410 Safari/600.1.4"]);
	$.browser.addShortcut('UA: iPod Touch', ["setAgent", "Mozilla/5.0 (iPad; CPU OS 8_1 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12B410 Safari/600.1.4"]);
	$.browser.addShortcut('UA: Mac Chrome 29', ["setAgent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/29.0.1547.57 Safari/537.36"]);
	$.browser.addShortcut('UA: Mac Firefox 23', ["setAgent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.9; rv:23.0) Gecko/20100101 Firefox/23.0"]);
	$.browser.addShortcut('UA: IE 10', ["setAgent", "Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.2; Win64; x64; Trident/6.0)"]);

	$.browser.addShortcut('see.js console', ['injectTab', 'seeDebugger', 'see.init();']); // http://davidbau.com/archives/2013/04/19/debugging_locals_with_seejs.html
	$.browser.addShortcut('Simulate TouchEvents', ['injectTab', 'thumbs']); // http://mwbrooks.github.io/thumbs.js/
	$.browser.addShortcut('Log DnDs to console', ['injectTab', 'dnd']);

	if ($.app.doesAppExist("com.google.Chrome")) $.browser.addShortcut('Open in Chrome', ['openInChrome']);

	var editor = {
		transparent: true,
		url: 'data:text/html,'+escape('<html contenteditable>') // https://coderwall.com/p/lhsrcq/one-line-browser-notepad
		// should use ace http://ace.c9.io/#nav=about
		// or CodeMirror.net
	};
	$.browser.addShortcut('HTML5 editor', editor);

	$.browser.tabSelected = new $.WebView(editor);
	//$.browser.pushTab(new $.WebView(editor));
	//.evalJS("document.body.textContent = 'Go ahead, type in here!';");
	//.evalJS("window.location.href = 'data:text/html, <html contenteditable>';"); //another way without escaping

	//if ($.app.platform === 'iOS') $.browser.pushTab(new $.WebView({url: 'http://github.com/kfix/MacPin'}));
	if ($.app.platform === 'iOS') $.browser.tabSelected = new $.WebView({url: 'http://github.com/kfix/MacPin'});

	var repl = {
		transparent: true,
		url: 'file://'+ $.app.resourcePath + '/repl.html',
		handlers: ['evalREPL', 'closeREPL']
	};
	$.browser.addShortcut('MacPin App.js REPL', repl);
	$.browser.tabSelected = new $.WebView(repl);
};


// from seeDebugger.js
function vtype(obj) {
  var bracketed = Object.prototype.toString.call(obj);
  var vt = bracketed.substring(8, bracketed.length - 1);
  if (vt == 'Object') {
    if ('length' in obj && 'slice' in obj && 'number' == typeof obj.length) {
      return 'Array';
    }
    if ('originalEvent' in obj && 'target' in obj && 'type' in obj) {
      return vtype(obj.originalEvent);
    }
  }
  return vt;
}
function isprimitive(vt) {
  switch (vt) {
    case 'String':
    case 'Number':
    case 'Boolean':
    case 'Undefined':
    case 'Date':
    case 'RegExp':
    case 'Null':
	case 'Object':
      return true;
  }
  return false;
}


delegate.evalREPL = function(tab, msg) {
	var command = msg;
	var result;
	try {
		result = eval(command);
		var description = JSON.stringify(result, function (k,v) { //replacer func
			var type = vtype(v);
			if (!isprimitive(type)) return type;
			return v;
		}, 1);
		var rtype = vtype(result);
		if (!isprimitive(rtype)) description = result.__proto__ ? Object.getOwnPropertyNames(result.__proto__) : Object.getOwnPropertyNames(result); //dump props of custom objects
		result = [`[${rtype}]:  ${description}`];
	} catch(e) {
		result = e;
	}
	console.log(result);
	tab.evalJS("window.dispatchEvent(new window.CustomEvent('returnREPL',{'detail':{'result': "+result+"}}));");
	tab.evalJS("returnREPL('"+escape(result)+"');");
};

delegate.closeREPL = function(tab, msg) {
	tab.close();
};

delegate; //return this to macpin
