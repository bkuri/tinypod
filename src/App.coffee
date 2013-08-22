'use strict'

class App
  @alertTemplate: Handlebars.compile document.getElementById('alert-tpl').innerHTML

  @currentHashId: -> Number window.location.hash.split('/').reverse()[0]

  @markAllRead: ->
    hid = App.currentHashId()
    Store.markFeedRead hid, ->
      $items = jQuery document.getElementById "articles-#{hid}"
      $('li.unread', $items).removeClass 'unread'
      $('span.label', "#feed-#{hid}").remove()

  @markItemRead: (id) ->
    $li = $("li[data-id=#{id}]", 'ul.article-list').removeClass 'unread'
    $('span.label', "#feed-#{App.currentHashId()}").remove() unless $li.siblings('.unread').length

  @navTemplate: Handlebars.compile document.getElementById('nav-tpl').innerHTML

  @queueUnread: ->
    queue = Store.load 'queue'
    unread = []
    $('li.unread', "#articles-#{App.currentHashId()}").each -> unread.unshift $(@).data 'id'
    Store.queueArticles unread, Player.refreshQueue if unread.length

  @reHash: /^#(\w+)\/(\d+)/

  @showAlert: ($parent, message) ->
    $(document.createElement 'section')
      .html(App.alertTemplate message: message)
      .addClass('alert alert-error')
      .appendTo($parent)
      .alert()

  constructor: ->
    $list = jQuery document.getElementById 'thelist'
    $modal = jQuery document.getElementById 'article-details'
    $queue = jQuery document.getElementById 'queue'
    $status = jQuery document.getElementById 'status'
    $wrapper = jQuery document.getElementById 'wrapper'
    audio = document.querySelector 'audio'
    nav = document.querySelector 'nav'

    onTransitionEnd =->
      right = $list.hasClass 'move-right'
      $('article:not(.homePage)', $list).remove() if right
      $list.off 'transitionend'

    @homePage = new FeedList().render()
    @homePage.el.appendTo $list

    @registerEvents =->
      onPlay =->
        id = $(@).next('button.btn-queue').first().data 'article-id'
        console.log "App.onPlay -> id: #{id}"
        Store.queueArticle id, 0
        Player.refreshQueue()
        Player.process audio, id, true

      onQueue =->
        id = $(@).data 'article-id'
        console.log "App.onQueue -> id: #{id}"
        unless id in Store.load 'queue'
          Store.queueArticle id
          Player.refreshQueue()
        $modal.modal 'hide'

      stops = [[],[]]
      onSwipe = (direction) ->
        $page = $('article', $list).last()
        offset = $('header', $page).height() or 0
        index = $page.index()

        switch direction
          when 'up'
            $items = $('li.first-visible', $page).last().nextAll()
            $next = $wrapper.visibleItems($items, 'vertical', offset).last().addClass 'first-visible'

            return unless $next.length
            offset = $page.offset().top
            stops[index].push $wrapper.offset().top - offset
            amount = $next.offset().top - offset
            $status.addClass 'on' if index is 1 and amount > 0

          when 'down'
            $first = $('li.first-visible', $page)
            $first.last().removeClass 'first-visible' if $first.length > 1
            amount = if stops[index].length > 1 then stops[index].pop() else stops[index][0]
            $status.removeClass 'on' if index is 0 or amount is 0

        $page.css transform: "translateY(#{-amount}px)"

      onToss =->
        id = $(@).siblings('button.btn-queue').first().data 'article-id'
        console.log "App.onToss -> id: #{id}"

        Store.markArticleRead id, ->
          App.markItemRead id
          Player.markItemRead id

        $modal.modal 'hide'

      lastY = 0
      onTouchMove = (e) ->
        return unless e.originalEvent.touches.length is 2
        diff = Math.abs(e.originalEvent.touches[0].pageY) - Math.abs lastY

        if diff < -9 then onSwipe 'up'
        else if diff > 9 then onSwipe 'down'

        lastY = e.originalEvent.touches[0].pageY
        false

      onTouchStart = (e) ->
        if e.originalEvent.touches.length is 2
          $('article.page', jQuery this).addClass 'fast'
          lastY = e.originalEvent.touches[0].pageY
          $.doTimeout 'notsofast'
          false
        else $('article.page', jQuery this).removeClass 'fast'

      onTouchEnd =-> not $('article.page', jQuery this).hasClass 'fast'

      $.fn.onVol = (value) ->
        D = 'disabled'
        handle =->
          vol = audio.volume + value
          invalid = (vol < 0 or vol > 1)

          unless invalid
            audio.volume += value
            $(@).siblings().removeAttr(D).end().removeAttr D
          else $(@).siblings().removeAttr(D).end().attr D, D
          not invalid

        if value?
          handle()
          $.doTimeout 'volume', 250, handle
        else $.doTimeout 'volume'

      onWheel = (e) ->
        delta = Math.max -1, Math.min 1, e.wheelDelta || -e.detail
        console.log delta
        false

      $list.on 'vmousedown', 'li', -> $(@).addClass 'pressed'

      $(window).on 'hashchange', @route

      $(nav.querySelector 'button.btn-clean')
        .on('vclick', Player.clean)
        .on 'taphold', ->
          Store.save 'queue', []
          Store.removeCursor ->
            $('article.cursor', document.getElementById 'queue').removeClass 'cursor'
            Player.stop audio, not audio.paused

          $('ul.article-list li.queued', $list).removeClass 'queued'
          Player.refreshQueue()

      $(nav.querySelector 'button.btn-refresh').on 'vclick', ->
        $i = $('i', jQuery this).addClass 'icon-spin'
        $pages = $('.page', $list)

        id = App.currentHashId()
        $feed = jQuery document.getElementById "articles-#{id}"
        handle = (items) ->
          $ul = $('ul', $feed).empty()
          $ul.append "<li #{'class="unread"' if item.unread} data-id=#{item.id}><span>#{item.title}</span></li>" for item in items
          FeedDetails.registerEvents $feed
          $i.removeClass 'icon-spin'

        if $pages.length < 2
          #Store.loadFeeds FeedList.fetch
          $i.removeClass 'icon-spin'
        else Store.loadArticles id, handle, true

      $(nav.querySelector 'button.btn-vol-dn').on 'vmousedown', -> $(@).onVol -0.1
      $(nav.querySelector 'button.btn-vol-up').on 'vmousedown', -> $(@).onVol 0.1
      $(nav.querySelectorAll 'button.btn-vol-dn,button.btn-vol-up').on 'vmouseup', -> $(@).onVol()

      $modal
        .on('vclick', 'button.btn-play', onPlay)
        .on('vclick', 'button.btn-queue', onQueue)
        .on('vclick', 'button.btn-toss', onToss)

      $(nav)
        .on('swipedown', -> $(document.getElementById 'queue').show())
        .on('swipeup', -> $(document.getElementById 'queue').hide())

      $wrapper
        .on('mousewheel', (e) -> onSwipe if e.originalEvent.wheelDeltaY < 0 then 'up' else 'down')
        .on('swipedown', -> onSwipe 'down')
        .on('swipeleft', -> window.history.go + 1)
        .on('swiperight', -> window.history.go -1 if window.location.hash)
        .on('swipeup', -> onSwipe 'up')
        .on('touchmove', onTouchMove)
        .on('touchstart', onTouchStart)
        .on('touchend', onTouchEnd)

    @route = () =>
      goHome = () =>
        @slidePage @homePage
        $(document.getElementById 'status').removeClass 'on'

      hash = window.location.hash
      return goHome() unless hash

      match = hash.match App.reHash
      return goHome() unless match

      switch match[1]
        when 'episodes'
          FeedDetails.showModal match[2]
          $('article:not(.homePage) li.pressed', $list).removeClass 'pressed'

        when 'feeds' then Store.findById (Number match[2]), (feed) =>
          $other = jQuery document.getElementById "articles-#{match[2]}"
          if $other.length then @slidePage $other[0]
          else new FeedDetails feed, @slidePage

    @slidePage = (page) =>
      $status = jQuery document.getElementById 'status'
      home = page is @homePage
      offset = Math.abs @homePage.el.offset().top - $wrapper.offset().top

      unless home
        $('article.homePage li.pressed', $list).removeClass 'pressed'
        $status.text $('h1', page.el).text()
        $(page.el).css(transform: "translateY(#{-offset})px").appendTo $list
      else $status.removeClass 'on'

      $modal.modal 'hide' unless eval $modal.attr 'aria-hidden'
      $wrapper.data offset: offset

      slide = (direction) ->
        classes = 'move-right move-left'
        $list.on('transitionend', onTransitionEnd).removeClass(classes).addClass "move-#{direction}"

      if home then slide 'right'
      else setTimeout -> slide 'left'

    @store = new Store @route, (fresh_install) =>
      init = (app, fresh=false) ->
        nav.innerHTML = App.navTemplate volume: unless fresh then Store.config 'volume-controls' else false
        Store.logIn -> Store.loadFeeds FeedList.fetch

        app.registerEvents()
        app.player = new Player audio
        app.scheduler = new Scheduler()
        app.route() if window.location.hash

      if fresh_install then Settings.show true, => init this, true
      else init this
