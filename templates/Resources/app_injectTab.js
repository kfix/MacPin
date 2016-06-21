delegate.injectTab = function(script, init, pre, tab) {
	if (pre ? tab.preinject(script) : tab.postinject(script)) {
		tab.evalJS('window.location.reload(false);'); // must reload page after injection
		if (init) tab.asyncEvalJS(init, 2);
	} else { // script is already injected, so just init it again
		if (init) tab.evalJS(init);
	}
};
