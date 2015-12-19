/* eslint-env: es6 */
// shim NSGestureRecognizer delegates (pan, rotate, pinch, drag) to cursor/pointer-less touchpad events in javascript
//     https://developer.apple.com/library/mac/documentation/AppKit/Reference/NSGestureRecognizer_Class/
//     https://developer.mozilla.org/en-US/docs/Web/Guide/Events/Mouse_gesture_event://developer.mozilla.org/en-US/docs/Web/Guide/Events/Mouse_gesture_events 
// or maybe use current mouse pointer as a virtual "center" of the gesture and fully mimic TouchEvents?
//    hold down ctrl+cmd to bypass/trigger virtual centering 
