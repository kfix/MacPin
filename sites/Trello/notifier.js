/*eslint eqeqeq:0, quotes:0, space-infix-ops:0, curly:0*/
/*globals webkit*/
"use strict";

// https://gist.github.com/marclipovsky/4566822
var fluid = {}; // http://www.fluidapp.com/developer/
fluid.showGrowlNotification = function(h) { //h{} :title, :priority, :sticky, :description, :icon, :callback
	webkit.messageHandlers.TrelloNotification.postMessage([h.title, "", h.description]);
};
