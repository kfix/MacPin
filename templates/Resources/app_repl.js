/*eslint-env applescript*/
/*eslint-env builtins*/
/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
"use strict";

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

// stringifies results from evaluations of JS code from command-line
delegate.REPLprint = function(result) {
	var description = JSON.stringify(result, function (k,v) { //replacer func
		var type = vtype(v);
		if (!isprimitive(type)) return type;
		return v;
	}, 1);
	var rtype = vtype(result);
	if (!isprimitive(rtype)) description = result.__proto__ ? Object.getOwnPropertyNames(result.__proto__) : Object.getOwnPropertyNames(result); //dump props of custom objects
	if (rtype == 'Function') description += '\n' + result.toString(); // dump funcs' code
	var ret = `[${rtype}]:  ${description}`;
	return ret;
};
