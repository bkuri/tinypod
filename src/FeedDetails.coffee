'use strict'

class FeedDetails
  @artTemplate: Handlebars.compile document.getElementById('article-tpl').innerHTML

  @registerEvents: ($target) ->
    onClick =->
      $me = $(@).removeClass 'pressed'
      if $me.data 'skip'
        $me.removeData 'skip'
        Player.refreshQueue()
      else window.location.hash = "#episodes/#{$me.data 'id'}"

    onTapHold =->
      blank = $(document.getElementById 'queue').children().length is 0
      [queue, index] = Player.getQueueIndex()
      id = $(@).addClass('queued').data(skip:true).data 'id'
      console.log "onTapHold -> id: #{id}"
      Store.queueArticle id, unless blank then index + 1 else 0
      (Player.process (document.querySelector 'audio'), id) if blank

    $target
      .on('vclick', 'button.btn-unread', App.queueUnread)
      .on('vclick', 'button.btn-catchup', App.markAllRead)
      .on('taphold', 'li', onTapHold)
      .on('vclick', 'li', onClick)
      .find('li:first').addClass 'first-visible'

  @template: Handlebars.compile document.getElementById('feed-tpl').innerHTML

  @showModal: (id) ->
    modal = document.getElementById 'article-details'

    Store.getArticle id, (data) ->
      Store.getIcon data.feed_id
      modal.innerHTML = FeedDetails.artTemplate data

      $('section.modal-body', jQuery modal)
        .find('embed, iframe, object').remove().end()
        .find('*').removeAttr 'style'

      $(modal).on('hide', -> window.history.back()).modal 'show'

  constructor: (data, callback) ->
    console.log "FeedDetails -> id: #{data.id}"
    Store.loadArticles data.id, (result) =>
      @el = jQuery FeedDetails.template $.extend data, items: result
      FeedDetails.registerEvents @el
      callback this
    this
