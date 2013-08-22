'use strict'

class Settings
  @setupTemplate: Handlebars.compile document.getElementById('settings-tpl').innerHTML

  @show: (main, callback) ->
    onHidden =->
      $('input', jQuery this).each ->
        $input = jQuery this
        Store.config ($input.data 'key'), $input.val().trim()
      Store.refreshSession -> Store.getCategoryId callback

    onHide =->
      valid = true
      $('input', jQuery this).each -> valid = false unless $(@).val().trim().length > 0
      valid

    colors = [
      { label: 'red', val: '#990000' }
      { label: 'green', val: '#009900' }
      { label: 'blue', val: '#000099' }
      { label: 'orange', val: '#orange' }
      { label: 'purple', val: '#purple' }
      { label: 'custom...', val: '#custom' }
    ]

    items = [
      { label: 'every week', val: 'in 1 week' }
      { label: 'every 2 weeks', val: 'in 2 weeks' }
      { label: 'every 3 weeks', val: 'in 3 weeks' }
      { label: 'every month', val: 'in 4 weeks' }
      { label: 'custom period...', val: 'custom' }
    ]

    params =
      article_ttl:
        items: items
      color:
        items: colors
      feed_ttl:
        items: items
      main: main
      session_ttl:
        items: items

    settings = document.getElementById 'settings'
    settings.innerHTML = Settings.setupTemplate params

    $(settings)
      .on('hidden', onHidden)
      .on('hide', onHide)
      .modal 'show'
