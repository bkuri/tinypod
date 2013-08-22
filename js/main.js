// Generated by CoffeeScript 1.6.3
'use strict';
$(function() {
  var $body, $document, $wrapper, app, closeLid, minHeight, navBarHeight, on_scroll, scrollTop;
  $body = $('body');
  $document = $(document);
  $wrapper = $('#wrapper');
  navBarHeight = $('.navbar').first().height();
  scrollTop = 0;
  minHeight = 40;
  closeLid = function(e) {
    $document.scrollTop(navBarHeight);
    return e.preventDefault();
  };
  on_scroll = function() {
    var stop;
    stop = $document.scrollTop();
    if (stop < navBarHeight) {
      $wrapper.mousedown(closeLid);
    } else {
      $wrapper.off('mousedown');
    }
    $.doTimeout('scrolling', 150, function() {
      return $document.scrollTop((navBarHeight - stop) < stop ? navBarHeight : 0);
    });
    return scrollTop = stop;
  };
  $document.on('scroll', $body, on_scroll).scrollTop(navBarHeight);
  $.ajaxSetup({
    crossDomain: true
  });
  return app = new App();
});