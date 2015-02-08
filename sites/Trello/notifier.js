// https://gist.github.com/marclipovsky/4566822
var fluid = {} // http://www.fluidapp.com/developer/
window.fluid.showGrowlNotification = function(h) { //h{} :title, :priority, :sticky, :description, :icon, :callback
	webkit.messageHandlers.TrelloNotification.postMessage([h.title, "", h.description]);
}
