'use strict'

class Player
  @buildQueue: ->
    [queue, index] = Player.getQueueIndex()
    items = []

    for id in queue
      switch Store.getPosition id
        when -1 then state = 'finished'
        when 0 then state = 'fresh'
        else state = 'listening'

      state += ' cursor' if id is Store.getCursor()
      Store.getArticle id, (data) -> items.push $.extend data, id: id, state: state

    items: items

  @clean: ->
    $queue = jQuery document.getElementById 'queue'
    $finished = $('article.finished', $queue).remove()

    queue = []
    $queue.children().each ->
      $me = jQuery this
      queue.push $me.data 'id'
      $('span.badge', $me).text $me.index()

    Store.save 'queue', queue
    Player

  @getQueueIndex: ->
    queue = Store.load 'queue'
    [queue, queue.indexOf Store.getCursor()]

  @markItemRead: (id) ->
    item = document.getElementById "article-#{id}"
    item.className += ' finished' if item

  @markReadAndContinue: (audio) ->
    console.log 'Player.markReadAndContinue'
    audio.autoplay = true
    $(audio).data skip: true
    $cursor = $("article.cursor", jQuery document.getElementById 'queue').removeClass('listening').addClass 'finished'
    Store.markArticleRead ($cursor.data 'id'), (id) ->
      console.log "Player.markReadAndContinue -> markArticleRead id: #{id}"
      App.markItemRead id
      Player.skip audio

  @pause: (audio) ->
    return unless audio.hasAttribute 'src'

    if audio.paused
      audio.autoplay = true
      audio.play()

    else
      audio.autoplay = false
      audio.pause()
      Store.savePosition Store.getCursor(), audio.currentTime

  @placeCursor: (id) ->
    $(document.getElementById "article-#{id}").removeClass('fresh').addClass('cursor').siblings().removeClass 'cursor'

  @process: (audio, id) ->
    [queue, index] = Player.getQueueIndex()
    console.log "Player.process -> id: #{id}"
    return unless queue.length

    id = queue[0] if id is 0
    cursor = Store.getCursor()
    Store.savePosition cursor, audio.currentTime if cursor
    Store.placeCursor id
    Player.placeCursor id
    Store.getArticle id, (data) ->
      return unless data.attachments.length
      media = data.attachments[0]
      position = Store.getPosition id
      $(audio).attr
        autoplay: true
        src: if position > 0 then "#{media.content_url}#t=#{position}" else media.content_url
        type: media.content_type

  @queueTemplate: Handlebars.compile document.getElementById('queue-tpl').innerHTML

  @refreshQueue: ->
    $queue = jQuery document.getElementById 'queue'
    items = $queue.children().length

    $queue
      .html(Player.queueTemplate Player.buildQueue())
      .children().first().addClass 'first-visible'

  @repeat: (audio, amount) ->
    $(audio).data 'repeat', true
    $.doTimeout 'repeat', 500, ->
      Player.step audio, amount
      $(audio).data 'repeat'

  @rewind: (audio) ->
    return unless audio.hasAttribute 'src'
    $(audio).data skipping: true
    audio.currentTime = 0

  @skip: (audio, next=true) ->
    return unless audio.hasAttribute 'src'
    unless $(audio).data 'skip'
      Store.savePosition Store.getCursor(), audio.currentTime
      $queue = jQuery document.getElementById 'queue'
      id = Store.getCursor()
      sel = 'article:not(.finished)'
      return if id < 0 or $(sel, $queue).length < 1

      $cursor = jQuery "#article-#{id}"
      $next = $cursor.nextAll sel
      $prev = $cursor.prevAll sel
      handle = ($a, $b) -> if $a.length then $a.first().data 'id' else if $b.length then $b.last().data 'id' else 0
      id = if next then (handle $next, $prev) else (handle $prev, $next)
      Player.process audio, id if id > 0
    else $(audio).removeData 'skip'

  @start: (audio) ->
    [queue, index] = Player.getQueueIndex()
    cursor = Store.getCursor()
    (Player.process audio, if cursor < 0 then queue[0] else cursor) if queue.length

  @step: (audio, amount, absolute=false) ->
    return unless audio.hasAttribute 'src'
    Store.savePosition Store.getCursor(), audio.currentTime = Math.round unless absolute then audio.currentTime + amount else amount

  @stop: (audio, save_position=true) ->
    return unless audio.hasAttribute 'src'
    Store.savePosition Store.getCursor(), audio.currentTime = 0 if save_position
    audio.removeAttribute 'autoplay' if audio.paused
    audio.removeAttribute 'src'
    audio.removeAttribute 'type'
    Player.pause audio
    $(audio).removeData().trigger 'abort'
    audio.load()

  constructor: (audio) ->
    $queue = Player.refreshQueue()
    Player.start audio

    ###
    context = new window.webkitAudioContext()
    js = context.createJavaScriptNode 2048, 1, 1
    js.connect context.destination
    dbmeter = context.createAnalyser()
    dbmeter.smoothingTimeConstant = 0.3
    dbmeter.fftSize = 1024
    dbmeter.connect js

    getAverageVolume = (array) ->
      values = 0
      values += value for value in array
      Math.floor values / array.length

    js.onaudioprocess =->
      array =  new Uint8Array dbmeter.frequencyBinCount
      dbmeter.getByteFrequencyData array
      vol = getAverageVolume array
      audio.volume -= 0.1 if vol > 40
      document.title = vol
    ###

    $(document.querySelector 'footer')
      .on('vclick', '.btn-media-bstep', -> Player.step audio, -15)
      .on('vclick', '.btn-media-fstep', -> Player.step audio, 15)
      .on('vclick', '.btn-media-next', -> Player.skip audio)
      .on('vclick', '.btn-media-prev', -> Player.skip audio, false)
      .on('vclick', '.btn-media-toggle', -> Player.pause audio)
      .on('taphold', '.btn-media-bstep', -> Player.repeat audio, -15)
      .on('taphold', '.btn-media-fstep', -> Player.repeat audio, 15)
      .on('taphold', '.btn-media-next', -> Player.markReadAndContinue audio)
      .on('taphold', '.btn-media-prev', -> Player.rewind audio)
      .on('taphold', '.btn-media-toggle', -> Player.stop audio)
      .on('vmouseup', '.btn-media-bstep, .btn-media-fstep', -> $(audio).data 'repeat', false)

    $articles = $('article', $queue)
    counter = 0
    events = []

    addEvent = (event) ->
      events.unshift event
      events.pop() if events.length > 2

    $.fn.handleTap =->
      $this = jQuery this
      unless $this.hasClass 'selected' then $this.timeoutClass 'selected', 250
      else Player.process audio, $this.data 'id'

      unless $this.hasClass 'focused'
        $queue = jQuery document.getElementById 'queue'
        $focused = $('article.focused', $queue).removeClass 'focused'

        return unless $focused.length
        if $this.index() > $focused.index() then $focused.insertAfter $this
        else $focused.insertBefore $this

        queue = []
        $('article', $queue).each (i, e) ->
          $me = jQuery this
          $('span.badge', $me).text i
          queue.push $me.data 'id'

        Store.save 'queue', queue
        Player.refreshQueue()

      else if events[1] is 'taphold' then $('article.focused', $queue).removeClass 'focused'
      addEvent 'vmouseup'

    $(document.getElementsByClassName 'navbar-inner')
      .on('swipeleft', -> onSwipe 'left')
      .on('swiperight', -> onSwipe 'right')

    $(document.getElementById 'queue')
      .on('vmouseup', 'article', $(@).handleTap)
      .on 'taphold', 'article', ->
        $this = jQuery this
        $this.siblings().removeClass 'focused'
        $this.timeoutClass 'focused', 5000
        addEvent 'taphold'

    onAudioDownloadProgress =->
      buffered = audio.buffered.length
      return unless buffered > 0

      progress = ((audio.buffered.end buffered - 1) / audio.duration) * 100
      $bar = $(document.getElementById 'loaded-bar').css width: "#{progress}%"
      $bar.toggleClass 'blinking', $bar[0].clientWidth < (document.getElementById 'played-bar').clientWidth

    onAudioEnded = (e) ->
      # TODO fix ending time calculation (should be % instead)
      Player.markReadAndContinue e.target

    onAudioError = (e) ->
      skip = true

      switch e.target.error.code
        when e.target.error.MEDIA_ERR_ABORTED then desc = 'You aborted the audio playback.'

        when e.target.error.MEDIA_ERR_NETWORK
          desc = 'A network error caused the download to fail.'
          skip = false

        when e.target.error.MEDIA_ERR_DECODE
          desc = 'Playback was aborted due to a corruption problem or because the file uses features your browser does not currently support.'

        when e.target.error.MEDIA_ERR_SRC_NOT_SUPPORTED
          desc = "The episode could not be loaded, either because the server or network failed or because the format is not supported."

        else
          desc = 'An unknown error occurred.'
          skip = false

      console.log "Player.onAudioError -> code: #{e.target.error.code}\tdesc: #{desc}"

      skipThis =->
        $(audio).removeData 'retries'
        $('article.cursor', jQuery document.getElementById 'queue').addClass 'error'
        Player.skip audio

      unless skip or (Store.config 'on-error' is 'skip')
        console.log 'error encountered; retrying...'
        retries = $(audio).data 'retries' or 0
        if retries < Store.config 'retries' then $(audio).data 'retries', retries + 1
        else skipThis()
      else skipThis()

    onAudioReady =->
      ###
      source = context.createMediaElementSource audio
      source.connect dbmeter
      source.connect js
      ###
      position = Store.getPosition Store.getCursor()
      console.log "Player.onAudioReady -> position: #{position}"
      audio.currentTime = position

    stops = [0]
    onSwipe = (direction) ->
      $queue = jQuery document.getElementById 'queue'

      switch direction
        when 'left'
          $items = $('article.first-visible', $queue).last().nextAll()
          $next = $('nav.navbar').visibleItems($items, 'horizontal').last().addClass 'first-visible'

          if $next.length
            offset = -$queue.offset().left
            stops.push offset
            amount = $next.offset().left + offset if $next.length

        when 'right'
          $first = $('article.first-visible', $queue)
          $first.last().removeClass 'first-visible' if $first.length > 1
          amount = if stops.length > 1 then stops.pop() else 0

      $queue.css transform: "translateX(#{-amount}px)"

    audio.addEventListener 'abort', -> $(document.querySelector 'footer').find('div.bar').css width: 0
    audio.addEventListener 'ended', onAudioEnded
    audio.addEventListener 'error', onAudioError
    audio.addEventListener 'canplay', onAudioReady
    audio.addEventListener 'pause', -> $('.icon-pause', document.getElementsByTagName('footer')[0]).removeClass('icon-pause').addClass 'icon-play'
    audio.addEventListener 'playing', -> $('.icon-play', document.getElementsByTagName('footer')[0]).removeClass('icon-play').addClass 'icon-pause'
    audio.addEventListener 'progress', onAudioDownloadProgress
    audio.addEventListener 'stalled', -> console.log '[audio] stalled.'
    audio.addEventListener 'timeupdate', -> $(document.getElementById 'played-bar').css width: "#{Math.ceil (audio.currentTime * 100) / audio.duration}%"
    audio.addEventListener 'waiting', -> console.log '[audio] waiting...'

    window.onbeforeunload =->
      Store.savePosition Store.getCursor(), audio.currentTime
      null
