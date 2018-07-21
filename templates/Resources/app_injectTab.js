console.log(`require()d ${module.uri}`);
module.exports = function(script, init, pre, tab) {
	// i really need a .nowinject to replace .postinject+reload
	if (pre ? tab.preinject(script) : tab.postinject(script)) {
		//if (init) tab.evalJS(`window.onload = Function("${init}"); window.location.reload(false)`); // ewww
		// .onload doesn't survive reload

		tab.reload();
		// would like a way to block on reload() or supply it with a strictly-ordered callback
		// instead of just sitting for 2 seconds
		// tab.reloadThen(jscb) ...

		//if (init) setTimeout((js) => {tab.evalJS(js)}, 2, init);
		// arrow is a Function type, so setTimeout works
		//if (init) setTimeout(tab.evalJS, 2, init);
		// evalJS is a CallbackFunction type, so setTimeout bails
		if (init) setTimeout(tab.evalJS.bind(tab), 2, init);

	} else { // script is already injected, so just init it again
		if (init) tab.evalJS(init);
	}
};
