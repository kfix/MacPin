/*eslint-env applescript*/
/*eslint-env builtins*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";
// helpers to stringify JS outputs to REPL from seeDebugger.js
// also refer to:
//   http://stackoverflow.com/questions/34914397/why-doesnt-console-log-work-in-the-jsc-environment-but-it-works-in-safaris-deb
//   https://github.com/v8/v8/blob/master/src/d8.js

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
  // https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects
  switch (vt) {
    case 'String':
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

function REPLdump(v) {
	var type = vtype(v);
	if (type == 'Function') return v.toString(); // dump funcs' code w/ whitespace & comments too!
	if (!isprimitive(type)) {
		if (v instanceof Object) { // fixme - check if not bridged
			var obj = {};
			//for (var pn of Object.getOwnPropertyNames(v)) { if (v.hasOwnProperty(pn)) obj[pn] = v[pn]; }
			for (var pn of Object.keys(v)) { obj[pn] = v[pn]; }
			return obj;
		} else {
			return type;
		}
	}
	return v;
}

// stringifies results from evaluations of JS code from command-line
delegate.REPLprint = function(result) {
	var description = JSON.stringify(result, function (k,v) { //replacer func
		return REPLdump(v);
		var type = vtype(v);
		if (type == 'Function') return result.toString(); // dump funcs' code
		if (!isprimitive(type)) return type;
		return v;
	}, 1)
	if (description) description = description.replace(/\\t/g, "\t").replace(/\\n/g, "\n")
	var rtype = vtype(result);
	if (rtype == 'Function') description = REPLdump(result);
	//if (typeof result == 'object') description += Object.keys(result);
	if (typeof result != 'undefined' && result.__proto__) description += `\n${rtype}.__proto__: ${Object.getOwnPropertyNames(result.__proto__)}`;
	var ret = `[${rtype}] = ${description}`;
	return ret;
};
