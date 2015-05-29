/*eslint-env applescript*/
/*eslint-env builtins*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

var delegate = {}; // our delegate to receive events from the webview app

/*
(function (logtab) {
  var log = console.log;
  console.log = function () {
	logtab.evalJS("console.log('"+arguments+"');");
    log.apply(this, Array.prototype.slice.call(arguments));
  };
}(testTab));
*/

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
	console.log(urls);
	for (var url of urls) {
		$.browser.tabSelected.evalJS("confirm('Open a new tab for: "+url+"');", function(response) {
			if (response) {
				var tab = new $.WebView({url: url});
				//$.browser.tabSelected = tab;
				$.browser.pushTab(tab);
			}
		})
	}
	return true;
};

delegate.launchSeeDebugger = function() {
	//if ($.browser.tabSelected.postinject("seeDebugger")) { $.browser.tabSelected.reload() }
		// http://davidbau.com/archives/2013/04/19/debugging_locals_with_seejs.html
	//$.browser.tabSelected.postinject("seeDebugger");

	if ($.browser.tabSelected.postinject("seeDebugger")) {
		$.browser.tabSelected.evalJS('window.location.reload(false);'); // must reload page after injection
		$.browser.tabSelected.asyncEvalJS("see.init();", 2);
	} else { // debugger might already be injected, just popup the console
		$.browser.tabSelected.evalJS("see.init();")
	}

	// https://github.com/davidbau/see/blob/master/see-bookmarklet.js
	/*
		if let seeJSpath = NSBundle.mainBundle().URLForResource("seeDebugger", withExtension: "js") {
			// gotta run it from the bundle because CORS
			var seeJS = "(function() { loadscript( '\(seeJSpath)', function() { see.init(); }); function loadscript(src, callback) { function setonload(script, fn) { script.onload = script.onreadystatechange = fn; } var script = document.createElement('script'), head = document.getElementsByTagName('head')[0], pending = 1; setonload(script, function() { pending && (!script.readyState || {loaded:1,complete:1}[script.readyState]) && (pending = 0, callback(), setonload(script, null), head.removeChild(script)); }); script.src = src; head.appendChild(script); } })();"
			evalJS(seeJS) // still doesn't allow loading local resources
		}
		// download to temp?
		// else complain?
	*/
};

delegate.setAgent = function(agent) { $.browser.tabSelected.userAgent = agent; };

delegate.AppFinishedLaunching = function() {
	//$.globalUserScripts.push("dnd");
	//$.browser.defaultUserAgent = "Mozilla/5.0 (iPad; CPU OS 8_1 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12B410 Safari/600.1.4";
	//$.browser.unhideApp();

	//$.browser.addShortcut('XCode docs', 'file:///Applications/Xcode.app/Contents/Developer/Documentation//DocSets/com.apple.adc.documentation.Xcode.docset/Contents/Resources/Documents/index.html');
	$.browser.addShortcut('Swift docs', 'file:///Applications/Xcode.app/Contents/Developer/Documentation//DocSets/com.apple.adc.documentation.Xcode.docset/Contents/Resources/Documents/documentation/Swift/Conceptual/Swift_Programming_Language/index.html');
	$.browser.addShortcut('MacPin @ GitHub', 'http://github.com/kfix/MacPin');
	$.browser.addShortcut('Browsing Test', 'http://browsingtest.appspot.com');

	$.browser.addShortcut('UA: iPhone', ["setAgent", "Mozilla/5.0 (iPhone; CPU iPhone OS 8_1 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12B410 Safari/600.1.4"]);
	$.browser.addShortcut('UA: iPad', ["setAgent", "Mozilla/5.0 (iPad; CPU OS 8_1 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12B410 Safari/600.1.4"]);
	$.browser.addShortcut('UA: iPod Touch', ["setAgent", "Mozilla/5.0 (iPad; CPU OS 8_1 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12B410 Safari/600.1.4"]);
	$.browser.addShortcut('UA: Mac Chrome 29', ["setAgent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_9_0) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/29.0.1547.57 Safari/537.36"]);
	$.browser.addShortcut('UA: Mac Firefox 23', ["setAgent", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.9; rv:23.0) Gecko/20100101 Firefox/23.0"]);
	$.browser.addShortcut('UA: IE 10', ["setAgent", "Mozilla/5.0 (compatible; MSIE 10.0; Windows NT 6.2; Win64; x64; Trident/6.0)"]);


	//$.app.openURL('data://text/plain;base64,SGVsbG8gV29ybGQh', "com.google.Chrome"); // works `Hello world!`
	$.browser.addShortcut('Inline see.js console', ['launchSeeDebugger']);

	if ($.app.doesAppExist("com.google.Chrome")) $.browser.addShortcut('Open in Chrome', ['openInChrome']);

	var editor = {
		transparent: true,
		postinject: ['dnd'],
		url: 'data:text/html,'+escape('<html contenteditable>') // https://coderwall.com/p/lhsrcq/one-line-browser-notepad
		// should use ace http://ace.c9.io/#nav=about
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

	if ($.app.pathExists($.app.resourcePath + '/ractive.html')) $.browser.addShortcut('Ractive test', 'file://'+ $.app.resourcePath + '/ractive.html');
	//var testTab = $browser.tabs[0];
	//testTab.evalJS('"string!";');
	//testTab.evalJS('null;', null);
	//testTab.evalJS('true;', function(res, err) { console.log(String(res)); });
	//testTab.evalJS("true;", function(res, err) { "this is an NSBlock in scope of jsruntime:app.js, _NOT_ the webview" });
};

delegate.macpinWarn = function(msg) { // .. file, func, column, line
	try {
		//$.browser.tabs[0].evalJS("document.body.textContent += '"+msg+"';");
		$.browser.tabs[0].evalJS("document.body.innerHTML += '<div><pre>"+msg+"</pre></div>';");
	} catch(e) {
		//alert?
	}
};

delegate.evalREPL = function(tab, msg) {
	var command = msg;
	var result;
	try {
		result = eval(command);
		// need to identify whether an object or literal and dump accordingly
		result = [result, ' -> ' + JSON.stringify(result)];
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
