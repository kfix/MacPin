/* eslint-env: es6 */
// shim NSGestureRecognizer delegates (pan, rotate, pinch, drag) to cursor/pointer-less touchpad events in javascript
//     https://developer.apple.com/library/mac/documentation/AppKit/Reference/NSGestureRecognizer_Class/
//     https://developer.mozilla.org/en-US/docs/Web/Guide/Events/Mouse_gesture_event://developer.mozilla.org/en-US/docs/Web/Guide/Events/Mouse_gesture_events 
// or maybe use current mouse pointer as a virtual "center" of the gesture and fully mimic TouchEvents?
//    hold down ctrl+cmd to bypass/trigger virtual centering 
// Apple is way ahead of me:
//    https://developer.mozilla.org/en-US/docs/Web/API/GestureEvent
//    https://developer.apple.com/library/iad/documentation/UserExperience/Reference/GestureEventClassReference/index.html
//    https://developer.apple.com/library/safari/documentation/UserExperience/Reference/GestureEventClassReference/index.html
//      ^^ has special key modifiers
//    https://developer.apple.com/library/ios/documentation/AppleApplications/Reference/SafariWebContent/HandlingEvents/HandlingEvents.html#//apple_ref/doc/uid/TP40006511-SW23
//    https://developer.apple.com/library/safari/documentation/UserExperience/Reference/GestureEventClassReference/index.html#//apple_ref/javascript/instm/GestureEvent/initGestureEvent
//      .scale to get pinch factor
//      .rotation
//      could use .screenX and .screenY to detect two-finger swipes?
//         https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/mac/ViewGestureControllerMac.mm
//         https://github.com/WebKit/webkit/blob/master/Source/WebKit2/UIProcess/mac/ViewGestureControllerMac.mm#L140 only Magnification events are passed to WebCore
//    https://github.com/taye/interact.js
//    https://github.com/WebKit/webkit/commit/10f11d2d8227a7665c410c642ebb6cb9d482bfa8 Web Gesture events for Mac
//    https://github.com/WebKit/webkit/commit/d4d57e4697410ebaf006f3c62b04038a1915ca7f enable Web Gestures on Mac
