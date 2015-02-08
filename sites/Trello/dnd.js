// https://html.spec.whatwg.org/multipage/interaction.html#dnd
// https://developer.mozilla.org/en-US/docs/Web/Guide/HTML/Drag_and_drop
// https://developer.mozilla.org/en-US/docs/Web/Guide/HTML/Recommended_Drag_Types
// https://developer.apple.com/library/iad/documentation/AppleApplications/Conceptual/SafariJSProgTopics/Tasks/DragAndDrop.html
// http://www.html5rocks.com/en/tutorials/dnd/basics/

//fix trello's buggy code
if (window.jQuery) {
	// http://learn.jquery.com/events/event-extensions/#jquery-event-props-array
	jQuery.event.props = jQuery.event.props.filter(function(v){return (v != 'dataTransfer');});
	// http://learn.jquery.com/events/event-extensions/#jquery-event-fixhooks-object
	jQuery.event.fixHooks.drop = { props: [ "dataTransfer" ] };
	jQuery.event.fixHooks.dragover = { props: [ "dataTransfer" ] };
	jQuery.event.fixHooks.dragleave = { props: [ "dataTransfer" ] };
	jQuery.event.fixHooks.dragenter = { props: [ "dataTransfer" ] };
}

document.body.addEventListener("dragenter", function(e) {
	e.preventDefault(); // allow ondrop
	var dt = e.dataTransfer;
	e.dataTransfer.effectAllowed = "all";
	console.assert(dt.types != null);
}, true);
document.body.addEventListener("dragover", function(e) {
	e.preventDefault(); // make cursor show "droppable"
	var dt = e.dataTransfer;
	e.dataTransfer.dragEffect = "copy";
	console.assert(dt.types != null);
}, true);
document.body.addEventListener("drop", function(e) {
	//e.stopPropagation();
	e.preventDefault(); // prevent browser from simply loading the link when dropped
	var dt = e.dataTransfer;
	console.assert(dt.types != null);
	// this should never be null, but it happens with Chrome & Safari intermittently
	// https://code.google.com/p/chromium/issues/detail?id=226785
	// https://bugs.webkit.org/show_bug.cgi?id=30416
	// https://github.com/WebKit/webkit/commit/236ec7654dd513e68215c6cce3c95d2ac50f7d67
	// https://github.com/WebKit/webkit/blob/master/Source/WebCore/platform/mac/DragDataMac.mm
    var types = Array.prototype.slice.call(dt.types); //should already be an array
	console.log(types);
	for (type of ['text/uri-list', //*W3C<>*W3C STANDARD
				// ^ now, Chrome>WK2 has these blank on non-draggable elements, but they are filled in when Chrome<>Chrome. grrr
				//for WK2>Chrome, you must hold down Ctrl or Alt on some dropzone elements, WTF?
				'text/plain', //WK2>Chrome,WK2, same as uri-list
				//'text/x-moz-url', 'application/x-moz-file', //FF
				//'public.file-url', 'com.apple.pasteboard.promised-file-url', 'local-file-url', //Finder>WK2
				//'text/html', //Chrome<>Chrome: actual markup of dragged element
				'org.chromium.image-html', //Chrome>WK2, same as text/html^
				'public.url', //WK2<>WK2, same as text/uri-list 
 				'public.url-name', //WK2<>WK2, -name is alt-title of dragged element
				//'image/tiff', // Chrome,WK2>WK2, any NSImage is sent as a TIFF
				//'image/jpg', 'image/png' // Chrome>WK2, NSImages are also sent as their native formats
				'com.apple.pasteboard.promised-file-content-type',
				'com.apple.webarchive', //'application/x-webarchive', //WK2<>WK2 http://www.cocoanetics.com/2011/09/decoding-safaris-pasteboard-format/
				'Apple URL pasteboard type', // NSURLPboardType ~NSURL DEPRECATED Chrome>WK2
				// WebURLsWithTitlesPboardType
				'frob']) {
		if (~types.indexOf(type))
	    	console.log(type +': '+ dt.getData(type));
	}
	for (var i = 0; i < e.dataTransfer.files.length; i++) {
		var file = e.dataTransfer.files[i];
		console.log(file.name);
    }
}, true);

// https://developer.apple.com/library/safari/documentation/AppleApplications/Conceptual/SafariJSProgTopics/Tasks/CopyAndPaste.html
document.body.addEventListener("paste", function(e) {
	var cd = e.clipboardData;
    console.log(Array.prototype.slice.call(cd.types));
//    console.log(cd.getData('text/uri-list'));
}, false);

// dragging stuff to outside the window appears to be stunted
// https://github.com/WebKit/webkit/blob/72b18a0525ffb78247aa1951efc17129f8390f37/Source/WebKit2/UIProcess/API/mac/WKView.mm#L2312
// https://github.com/WebKit/webkit/blob/72b18a0525ffb78247aa1951efc17129f8390f37/Source/WebKit2/UIProcess/API/mac/WKView.mm#L1261
// https://github.com/WebKit/webkit/blob/54601073e462979408cd1e1d76e573f67ccc7930/Source/WebKit2/UIProcess/WebPageProxy.cpp#L1456
