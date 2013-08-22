// Generated by CoffeeScript 1.6.3
'use strict';
var FeedDetailsView;

FeedDetailsView = (function() {
  FeedDetailsView.liTemplate = Handlebars.compile($('#article-li-tpl').html());

  FeedDetailsView.template = Handlebars.compile($('#feed-tpl').html());

  function FeedDetailsView(store, data) {
    var _this = this;
    this.render = function() {
      this.el.html(FeedDetailsView.template(data));
      return this;
    };
    this.el = $('<article class="page" />').attr('id', "feed-" + data.id);
    store.loadArticles(data.id, function(result) {
      return $('.article-list', _this.el).html(FeedDetailsView.liTemplate(result));
    });
  }

  return FeedDetailsView;

})();