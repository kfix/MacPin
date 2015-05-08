/*eslint-env applescript*/
/*eslint-env builtins*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

var delegate = {}; // our delegate to receive events from the webview app
//var tabREPL, editor;

/*
(function (logtab) {
  var log = console.log;
  console.log = function () {
	logtab.evalJS("console.log('"+arguments+"');");
    log.apply(this, Array.prototype.slice.call(arguments));
  };
}(testTab));
*/

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

delegate.AppFinishedLaunching = function() {
	$.globalUserScripts.push("dnd");
	$.browser.defaultUserAgent = "Mozilla/5.0 (iPad; CPU OS 8_1 like Mac OS X) AppleWebKit/600.1.4 (KHTML, like Gecko) Version/8.0 Mobile/12B410 Safari/600.1.4";
	//$.browser.unhideApp();

	//$.browser.addShortcut('XCode docs', 'file:///Applications/Xcode.app/Contents/Developer/Documentation//DocSets/com.apple.adc.documentation.Xcode.docset/Contents/Resources/Documents/index.html');
	$.browser.addShortcut('Swift docs', 'file:///Applications/Xcode.app/Contents/Developer/Documentation//DocSets/com.apple.adc.documentation.Xcode.docset/Contents/Resources/Documents/documentation/Swift/Conceptual/Swift_Programming_Language/index.html');
	$.browser.addShortcut('MacPin @ GitHub', 'http://github.com/kfix/MacPin');
	$.browser.addShortcut('Browsing Test', 'http://browsingtest.appspot.com');
	//$.app.openURL('data://text/plain;base64,SGVsbG8gV29ybGQh', "com.google.Chrome"); // works `Hello world!`

	var editor = {
		transparent: true,
		postinject: ['dnd'],
		url: 'data:text/html,'+escape('<html contenteditable>') // https://coderwall.com/p/lhsrcq/one-line-browser-notepad
		// should use ace http://ace.c9.io/#nav=about
	};
	$.browser.addShortcut('HTML5 editor', editor);
	$.browser.tabSelected = new $.WebView(editor);
	//.evalJS("document.body.textContent = 'Go ahead, type in here!';");
	//.evalJS("window.location.href = 'data:text/html, <html contenteditable>';"); //another way without escaping

	var repl = {
		transparent: true,
		url: 'file://'+ $.app.resourcePath + '/repl.html',
		handlers: ['evalREPL', 'closeREPL']
	};
	$.browser.addShortcut('REPL', repl);

	$.browser.addShortcut('Ractive test', 'file://'+ $.app.resourcePath + '/ractive.html')
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
