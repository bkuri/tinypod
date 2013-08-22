'use strict'

class FeedList
  @liTemplate: Handlebars.compile document.getElementById('feed-li-tpl').innerHTML
  @template: Handlebars.compile document.getElementById('feeds-tpl').innerHTML

  @fetch: ->
    Store.findByName $('.search-key', 'article.homePage').val(), (results) ->
      $('.feed-list', '.homePage')
        .html(FeedList.liTemplate results)
        .children().first()
          .addClass('first-visible')
          .siblings().removeClass 'first-visible'

  constructor: ->
    onClick =->
      $this = jQuery this

      if $this.data 'skip'
        $this.removeData 'skip'
        Player.refreshQueue()
      else window.location.hash = "#feeds/#{$this.data 'id'}"

    onTapHold =->
      console.log 'FeedList.onTapHold'
      $target = $(@).timeoutClass('queued').data skip: true
      blank = $(document.getElementById 'queue').children().length is 0
      query = op: 'getHeadlines', feed_id: ($target.data 'id'), view_mode: 'unread', show_excerpt: false, show_content: false

      Store.ask query, (data) ->
        items = []
        items.unshift item.id for item in data.content

        Store.queueArticles items, ->
          (Player.process (document.querySelector 'audio'), items[0]) if blank and items.length
          console.log "FeedList.onTapHold -> items: #{items}"

    @el = jQuery '<article class="page homePage" />'
    @el
      .on('keyup', '.search-key', FeedList.fetch)
      .on('taphold', 'li', onTapHold)
      .on('vclick', 'li', onClick)

    @render = () =>
      @el.html FeedList.template()
      this
