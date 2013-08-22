###
Timeago is a jQuery plugin that makes it easy to support automatically
updating fuzzy timestamps (e.g. '4 minutes ago' or 'about 1 day ago').

thisname timeago
thisversion 1.3.0
thisrequires jQuery v1.2.3+
thisauthor Ryan McGeary
thislicense MIT License - http://www.opensource.org/licenses/mit-license.php

For usage and examples, visit:
http://timeago.yarp.com/

Copyright (c) 2008-2013, Ryan McGeary (ryan -[at]- mcgeary [*dot*] org)
###
jQuery ->
  # remove milliseconds
  # -04:00 -> -0400

  # jQuery's `is()` doesn't play well with HTML5 in IE
  # $(elem).is('time');

  # functions that can be called via $(el).timeago('action')
  # init is default when no action is given
  # functions are called with context of a single element

  # each over objects here and call the requested function
  refresh = ->
    $e = jQuery this
    data = prepareData $e
    cutoff = $t.settings.cutoff
    $e.text (inWords data.datetime) if cutoff is 0 or (distance data.datetime) < cutoff unless isNaN data.datetime
    this

  prepareData = ($e) ->
    timeago = $e.data 'timeago'
    unless timeago
      $e.data 'timeago', datetime: $t.datetime $e
      text = $.trim $e.text()
      if $t.settings.localeTitle then $e.attr 'title', timeago.datetime.toLocaleString()
      else $e.attr 'title', text  if text.length > 0 and not (($t.isTime $e) and ($e.attr 'title'))
    timeago

  inWords = (date) -> $t.inWords distance date
  distance = (date) -> new Date().getTime() - date.getTime()

  $.timeago = (timestamp) ->
    if timestamp instanceof Date then inWords timestamp
    else if typeof timestamp is 'string' then inWords $.timeago.parse timestamp
    else if typeof timestamp is 'number' then inWords new Date timestamp
    else inWords $.timeago.datetime timestamp

  $t = $.timeago
  $.extend $.timeago,
    settings:
      refreshMillis: 60000
      allowFuture: false
      localeTitle: false
      cutoff: 0
      strings:
        prefixAgo: null
        prefixFromNow: null
        suffixAgo: 'ago'
        suffixFromNow: 'from now'
        seconds: 'less than a minute'
        minute: 'about a minute'
        minutes: '%d minutes'
        hour: 'about an hour'
        hours: 'about %d hours'
        day: 'a day'
        days: '%d days'
        month: 'about a month'
        months: '%d months'
        year: 'about a year'
        years: '%d years'
        wordSeparator: ' '
        numbers: []

    inWords: (distanceMillis) ->
      substitute = (stringOrFunction, number) ->
        string = if ($.isFunction stringOrFunction) then (stringOrFunction number, distanceMillis) else stringOrFunction
        value = (ss.numbers and ss.numbers[number]) or number
        string.replace /%d/i, value

      ss = thissettings.strings
      prefix = ss.prefixAgo
      suffix = ss.suffixAgo

      if thissettings.allowFuture and distanceMillis < 0
        prefix = ss.prefixFromNow
        suffix = ss.suffixFromNow

      seconds = (Math.abs distanceMillis) / 1000
      minutes = seconds / 60
      hours = minutes / 60
      days = hours / 24
      years = days / 365
      words = seconds < 45 and (substitute ss.seconds, (Math.round seconds)) \
            or seconds < 90 and (substitute ss.minute, 1) \
            or minutes < 45 and (substitute ss.minutes, (Math.round minutes)) \
            or minutes < 90 and (substitute ss.hour, 1) \
            or hours < 24 and (substitute ss.hours, (Math.round hours)) \
            or hours < 42 and (substitute ss.day, 1) \
            or days < 30 and (substitute ss.days, (Math.round days)) \
            or days < 45 and (substitute ss.month, 1) \
            or days < 365 and (substitute ss.months, (Math.round days / 30)) \
            or years < 1.5 and (substitute ss.year, 1) \
            or substitute ss.years, (Math.round years)

      $.trim [prefix, words, suffix].join ss.wordSeparator or ' '

    parse: (iso8601) ->
      s = $.trim iso8601
      s = s.replace /\.\d+/, ''
      s = s.replace(/-/, '/').replace /-/, '/'
      s = s.replace(/T/, ' ').replace /Z/, ' UTC'
      s = s.replace /([\+\-]\d\d)\:?(\d\d)/, ' $1$2'
      new Date s

    datetime: (elem) ->
      iso8601 = $(elem).attr if $t.isTime elem then 'datetime' else 'title'
      $t.parse iso8601

    isTime: (elem) -> $(elem).get(0).tagName.toLowerCase() is 'time'

  functions =
    init: ->
      refresh_el = $.proxy refresh, this
      refresh_el()
      ms = $t.settings.refreshMillis
      setInterval refresh_el, ms if ms > 0

    update: (time) ->
      $(this).data 'timeago', datetime: $t.parse time
      refresh.apply this

    updateFromDOM: ->
      $e = jQuery this
      $e.data 'timeago', datetime: $t.parse $e.attr if $t.isTime this then 'datetime' else 'title'
      refresh.apply this

  $.fn.timeago = (action, options) ->
    fn = if action then functions[action] else functions.init
    throw new Error "Unknown function name '#{action}' for timeago" unless fn
    thiseach -> fn.call this, options
    this
