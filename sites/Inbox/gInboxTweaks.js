// from https://github.com/chenasraf/gInbox/blob/master/gInbox/gInboxTweaks.js
(function() {
  console.log('test');
 window.updateHangoutsMode = function(mode) {
   var rightPane, leftPane, hangoutsButton;

   hangoutsButton = document.querySelector('[title="Hangouts"]').parentNode.parentNode;
   rightPane      = hangoutsButton.previousSibling;
   leftPane       = hangoutsButton.parentNode.previousSibling;

    switch (mode) {
      case 1: // link to messages.app
        color='red';
        break;
      case 2: // disable completely
        color='black';
        hangoutsButton.remove();
        leftPane.style.width='100%';
        rightPane.style.minWidth='100px';
        break;
    }
    var body = document.querySelector('body');
    body.style.borderStyle='solid';
    body.style.borderWidth='10px';
    body.style.borderColor=color;
 }
})();
