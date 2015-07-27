// Fix up jQuery UI dialog's close button, broken by bootstrap.
// See: https://github.com/twbs/bootstrap/issues/6094#issuecomment-20029542
// jquery-ui.js must be loaded first, then bootstrap.js, then this shim.
if ($.fn.button.noConflict) {
    $.fn.btn = $.fn.button.noConflict();
}
// Alternatively, jquery-ui.js could be loaded after bootstrap.js, but that causes another problem with tooltip
// See: http://stackoverflow.com/questions/8681707/jqueryui-modal-dialog-does-not-show-close-button-x
