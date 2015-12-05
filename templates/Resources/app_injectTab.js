delegate.injectTab = function(script, init, pre) {
	if (pre ? $.browser.tabSelected.preinject(script) : $.browser.tabSelected.postinject(script)) {
		$.browser.tabSelected.evalJS('window.location.reload(false);'); // must reload page after injection
		if (init) $.browser.tabSelected.asyncEvalJS(init, 2);
	} else { // script is already injected, so just init it again
		if (init) $.browser.tabSelected.evalJS(init);
	}
};
