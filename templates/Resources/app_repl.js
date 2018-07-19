/*eslint-env es6*/
/*eslint-env builtins*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

(() => { // ES6 IIFE to protecc global scowpe
const {app} = require("@MacPin");

// helpers to stringify JS outputs to REPL from seeDebugger.js
// also refer to:
//   http://stackoverflow.com/questions/34914397/why-doesnt-console-log-work-in-the-jsc-environment-but-it-works-in-safaris-deb
//   https://github.com/v8/v8/blob/master/src/d8.js
// stringifies results from evaluations of JS code from command-line
//
// node cli's util.inspect() makes much prettier output
//    https://nodejs.org/api/util.html#util_util_inspect_object_options
//
// https://github.com/substack/object-inspect/blob/master/index.js
//
// https://github.com/deecewan/browser-util-inspect/blob/master/index.js
let inspect = require(`file://${app.resourcePath}/browser-util-inspect.js`);
//
// https://github.com/Automattic/util-inspect

Object.defineProperty(this, "ls", {
	configurable: true,
	enumerable: true,
	get: function () {
		let thee = (this) ? this : window;
		return Object.assign({},...Object.getOwnPropertyNames(thee).filter( (pn) => (!pn.startsWith("ls")) ).map( (pn) => ( {[pn]: thee[pn]}) ));
	}
});

app.on('printToREPL', function (result, colorize) {

	function vtype(obj) {
      // JS world doesn't have a solid convention to get bare type names for *any* given object. pathetic.
	  var bracketed;
	  try { bracketed = Object.prototype.toString.call(obj); }
	  catch(e) { bracketed = "[UnstringableTypeName]" }
	  var vt = bracketed.substring(8, bracketed.length - 1);

	  // https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Symbol/toStringTag
      // http://2ality.com/2015/09/well-known-symbols-es6.html#symboltostringtag-string
      // STP 59 haz Symbol.prototype.description: this[Symbol.toStringTag].description
	  if (vt == 'Object') {
	    if ('length' in obj && 'slice' in obj && 'number' == typeof obj.length) {
	      return 'Array';
	    }
	    if ('originalEvent' in obj && 'target' in obj && 'type' in obj) {
	      return vtype(obj.originalEvent);
	    }
	  }

	  if (vt == 'CallbackFunction' && obj.hasOwnProperty('name') && obj.name.length > 0) return obj.name

	  return vt;
	}
	function isprimitive(vt) {
	  // https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects
	  switch (vt) {
	    case 'String':
	    case 'Symbol':
	    case 'Number':
	    case 'Boolean':
	    case 'Array':
	    case 'Undefined':
	    case 'Date':
	    case 'RegExp':
	    case 'Null':
		case 'Object':
		case 'GlobalObject':
	      return true;
	  }
	  return false;
	}

	function isstringy(vt) {
		switch(vt) {
			case 'Function':
			case 'Symbol':
			case 'Date':
				return true;
		}
		// check for a toString prop?
		return false;
	}

	function isobjcish(vt) {
		// looking for generic objC enums (not JSExports)
		switch (vt) {
			// https://github.com/WebKit/webkit/blob/master/Source/JavaScriptCore/API/ObjCCallbackFunction.mm#L381
			case 'CallbackInitMethod':
			case 'CallbackInstanceMethod':
			case 'CallbackClassMethod':
			case 'CallbackBlock':
			//case 'CallbackFunction':
				return true;
		}
		return false;

	}

	function REPLdump(v) {
		var type = vtype(v);
		if (type == 'Function') return v.toString(); // dump funcs' code w/ whitespace & comments too!
		if (type == 'Symbol') return v.toString();
		if (type == 'Error') return v.toString();
		if ((!isprimitive(type)) && (!isobjcish(type))) {
			if (v instanceof Object) {
				var obj = {};
				// For all the other Object instances (including Map, Set, WeakMap and WeakSet), only their enumerable properties will be serialized.

				//for (var pn of Object.keys(v)) { obj[pn] = v[pn]; }

				for (var pn of Object.getOwnPropertyNames(v)) {
					//if (type == 'CallbackFunction' && pn == 'prototype') continue
					//if (pn == 'prototype' && vtype(v[pn]).endsWith('Prototype]')) {
					if (pn == 'prototype' && vtype(v[pn]).endsWith('Prototype')) {
						// $.app.nativeModules.WebView.prototype => [MacPin.MPWebViewPrototype] = ((JSON.stringify failed: TypeError: self type check failed for Objective-C instance method))
						// https://github.com/WebKit/webkit/blob/master/Source/JavaScriptCore/API/ObjCCallbackFunction.mm#L561
						obj[pn] = vtype(v[pn]);
						// if (v.hasOwnProperty('constructor')) // this is an exported objc-class-type, w/an initializer, not a class instance
						//obj[pn] = v[pn].__proto__;
						continue
					}

					if ( (v.hasOwnProperty(pn))
						&& !isobjcish(vtype(v[pn])) )
						obj[pn] = v[pn];
				}

				//for (var ps of Object.getOwnPropertySymbols(v))
				//   https://www.keithcirkel.co.uk/metaprogramming-in-es6-symbols/
				//for (var pn of Object.keys(v)) { obj[pn] = v[pn]; }
				return obj;
			} else {
				// ??
				return type;
			}
		}
		// let JSON figure out how to en-string whatever this is
		return v;
	}

	let description = inspect(result, {showHidden: true, colors: colorize});
/*
	var description;
	try {
		description = JSON.stringify(result, function (k,v) { //replacer func
			return REPLdump(v);
			var type = vtype(v);
			if (isstringy(type)) return result.toString(); // dump funcs' code
			if (!isprimitive(type)) return type;
			return v;
		}, 1)
	} catch(e) {
		description = `((JSON.stringify failed: ${e}))`;
	}
*/
	if (description) description = description.replace(/\\t/g, "\t").replace(/\\n/g, "\n")
	var rtype = vtype(result);
	if (rtype == 'Function') description = REPLdump(result);
	//if (typeof result == 'object') description += Object.keys(result);
	if (typeof result != 'undefined' && !(result === null) && result.__proto__) description += `\n${rtype}.__proto__: ${Object.getOwnPropertyNames(result.__proto__)}`;
	var ret = `[${rtype}] = ${description}`;
	return ret;
});

})(); //-ES6 IIFE
