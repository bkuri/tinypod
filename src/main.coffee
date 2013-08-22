'use strict'

registerHandle = (name) ->
  Handlebars.registerHelper name, (context, options) ->
    switch name
      when 'button' then extra = value: options.fn context
      when 'radio' then extra = items: (options.fn context).split ','
      when 'text' then extra = value: options.fn context, type: options.hash['type'] or 'text'
      else extra = {}
    (Handlebars.compile document.getElementById("#{name}-tpl").innerHTML) $.extend context, options.hash, extra

registerHandle item for item in ['button', 'dropdown', 'radio', 'text']

#$.fn.reverse = [].reverse;

$.fn.timeoutClass = (name, duration=100) ->
  $this = jQuery this
  $.doTimeout duration, -> $this.removeClass name
  $this.addClass name

$.fn.visibleItems = ($selector, direction, offset=0) ->
  amt = offset
  pamt = if direction is 'vertical' then $(@).innerHeight() else $(@).innerWidth()
  result = []

  $selector.each ->
    amt += if direction is 'vertical' then @scrollHeight else @scrollWidth + 5
    unless amt > pamt then result.push @
    else return false

  $([]).pushStack result

#document.addEventListener 'deviceready', (-> console.log 'deviceready'), false

jQuery ->
  app = new App()
