'use strict'

DEFAULT_CONFIG = '{"feedTtl":"every 1 week","articleTtl":"every 1 day","refreshFeeds":"every 1 day","cleanQueue":"never","volumeControls":true,"onError":"retry","retries":3}'

class Store
  @ask: (query, callback, use_session=true) ->
    console.log "Store.ask -> query: #{JSON.stringify query}"
    url = Store.config 'api-url'

    if use_session
      sid = Store.config 'session'
      if sid then $.post url, (JSON.stringify ($.extend query, sid: sid)), callback
      else Store.refreshSession (sid) -> $.post url, (JSON.stringify ($.extend query, sid: sid)), callback
    else $.post url, (JSON.stringify query), callback

  @config: (key, value) ->
    if key?
      if value?
        $(document).data key, value
        console.log "Store.config -> #{key}: #{value}"
        Store.save 'config', $(document).data()

      else
        value = $(document).data key
        console.log "Store.config <- #{key}: #{value}"
        value
    else Object.keys(Store.load 'config').length is 0

  @cssTemplate: Handlebars.compile $(document.getElementById 'style-tpl').html()

  @findById: (id, callback, table='feeds') ->
    for item in Store.load table when (Number item.id) is (Number id)
      callback item
      break

  @findByName: (searchKey, callback, table='feeds') ->
    feeds = Store.load table
    return callback [] unless Object.keys(feeds).length
    callback feeds.filter (element) -> (element.title.toLowerCase().indexOf searchKey.toLowerCase()) > -1

  @getArticle = (id, callback) ->
    key = "article-#{id}"
    data = localStorage.getItem key

    unless data?
      Store.ask (op: 'getArticle', article_id: id), (result, status, xhr) ->
        console.log status unless status is 'success'
        Store.save key, result.content[0]
        callback result.content[0]
    else callback JSON.parse data

  @getCategoryId: (callback, force=false) ->
    cat_id = Store.config 'cat-id'

    if force or not cat_id?
      Store.ask op: 'getCategories', (data) ->
        name = Store.config 'cat-name'
        console.log "Store.getCategoryId -> name: '#{name}'"

        for cat in data.content when cat.title is name
          Store.config 'cat-id', cat.id
          callback cat.id
          return
    else callback cat_id

  @getCursor: -> (Store.load 'progress')['@'] or -1

  @getIcon: (feed_id, callback) ->
    key = ".img-#{feed_id}"
    href = localStorage.getItem key

    console.log "Store.getIcon <- #{key}: #{href}"
    handle = (result, status, xhr) ->
      href = $(result).find('rss:first channel image url').text()
      console.log "Store.getIcon <- href: #{href}"
      Store.setImage key, href if href?
      callback?()

    unless href? then Store.findById feed_id, (feed) ->
      console.log "Store.getIcon <- feed_url: #{feed.feed_url}"
      try
        $.get feed.feed_url, handle, 'xml'
      catch e
        console.log "Store.getIcon -> ERROR #{e}"
    else Store.setImage key, href, false

  @getPosition: (id) ->
    progress = Store.load 'progress'
    progress[id] or 0

  @load: (what, fallback) ->
    result = JSON.parse (localStorage.getItem what) or fallback?
    if what is 'queue' then (result or []) else (result or {})

  @loadArticles: (feed_id, callback, refresh=false) ->
    label = "feed-#{feed_id}"
    articles = if refresh then null else localStorage.getItem label

    unless articles?
      Store.ask (op: 'getHeadlines', feed_id: feed_id, show_excerpt: false, show_content: false), (data) ->
        Store.save label, data.content

        actions =->
          localStorage.removeItem label
          localStorage.removeItem "remove-#{label}"

        Scheduler.addTask "remove-#{label}", actions, Store.config 'feed-ttl'
        callback data.content
    else setTimeout -> callback JSON.parse articles

  @loadFeeds: (callback) ->
    Store.getCategoryId (id) ->
      Store.ask (op: 'getFeeds', cat_id: id), (result) ->
        if result.content.error then console.log "Store.loadFeeds -> ERROR: #{result.content.error}"
        else Store.save 'feeds', result.content
        callback? result.content

  @logIn: (callback) ->
    Store.ask (op: 'isLoggedIn'), (result) ->
      console.log "Store.logIn -> result: #{result.content.status}"
      unless result.content.status then Store.refreshSession (sid) ->
        console.log "Store.logIn -> refreshSession -> sid: #{sid}"
        callback()
      else callback()

  @markArticleRead: (id, callback) ->
    query = op: 'updateArticle', article_ids: id, mode: 0, field: 2

    Store.ask query, ->
      article = Store.getArticle id, (data) ->
        if data?
          label = "article-#{id}"
          data['unread'] = false

          Store.savePosition id, -1
          Store.save label, data
          Scheduler.addTask label, (-> localStorage.removeItem label), Store.config 'article-ttl'

          fid = App.currentHashId()
          feed = Store.load "feed-#{fid}"

          if feed? then for article in feed when article['id'] is id
            article['unread'] = false
            Store.save "feed-#{fid}", feed
            break

          console.log "Store.markArticleRead -> id: #{id}"
          callback? id
        else console.log "Store.markArticleRead -> ERROR id: #{id}\tdesc: #{query['op']}"

  @markFeedRead: (id, callback) ->
    Store.ask (op: 'catchupFeed', feed_id: id), ->
      console.log "Store.markFeedRead -> id: #{id}"
      callback?()

  @placeCursor: (id) ->
    Store.save 'progress', $.extend (Store.load 'progress'), '@': id
    Store.getArticle id, (response) -> console.log  "[ #{id} ] #{response['title']}"
    id

  @queueArticle: (id, index=-1) =>
    queue = Store.load 'queue'
    Store.placeCursor id unless queue.length
    dupe = _.indexOf queue, id
    queue.pop dupe unless dupe < 0
    if index < 0 then queue.push id else queue.splice index, 0, id
    Store.save 'queue', queue

  @queueArticles: (ids, callback) =>
    Store.save 'queue', _.union (Store.load 'queue'), ids
    callback()

  @refreshSession: (callback) ->
    handle = (data) ->
      Store.config 'session', data.content.session_id
      callback data.content.session_id

    Store.ask (op: 'login', user: (Store.config 'user'), password: (Store.config 'password')), handle, false

  @removeCursor: (callback) ->
    progress = Store.load 'progress'
    delete progress['@']
    Store.save 'progress', progress
    callback()

  @save: (key, val) ->
    val = JSON.stringify val
    #console.log "Store.save -> #{key}: #{val}"
    localStorage.setItem key, val

  @savePosition: (id, position=false) ->
    return if id is 0 or not position
    console.log "Store.savePosition -> position: #{position}"
    progress = Store.load 'progress'
    progress[id] = position
    Store.save 'progress', progress

  @setImage = (key, href, persist=true) ->
    console.log "Store.setImage -> #{key}: #{href}"
    localStorage.setItem key, href if persist
    $(Store.cssTemplate css: "#{key} { background-image: url(#{href}); }").appendTo 'head'

  @setLabel: (id, label_id, assign=true) ->
    Store.ask (op: 'setArticleLabel', article_ids: id, label_id: label_id, assign: assign), (result) -> console.log result.content

  @subscribe: (id) ->
    cat_id = Store.config 'cat-id'

    if cat_id?
      query = op: 'subscribeToFeed', feed_id: id, category_id: cat_id
      Store.ask query, (result) -> console.log "Store.subscribed to feed #{id}\t( #{JSON.stringify result.content} )"
    else console.log 'Store.subscribe -> ERROR id: #{id}'

  @unQueue: (id) ->
    queue = Store.load 'queue'
    queue.pop queue.indexOf id
    Store.save 'queue', queue

  @unSubscribe: (id) ->
    # TODO finish this
    Store.ask op: 'unsubscribeFeed', feed_id: id, -> console.log "Store.unSubscribe -> id: #{id}"

  constructor: (route, callback) ->
    fresh = Store.config()
    (Store.setImage img, (localStorage.getItem img), false) if img.match /^.img-/ for img in Object.keys localStorage
    unless fresh then $(document).data Store.load 'config'
    else $(document).data JSON.parse DEFAULT_CONFIG
    callback fresh
