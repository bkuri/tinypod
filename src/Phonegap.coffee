'use strict'

class Phonegap
  constructor: ->
    @bindEvents =-> document.addEventListener 'deviceready', @onDeviceReady, false

    # 'load', 'deviceready', 'offline', 'online'.
    @onDeviceReady =-> app.receivedEvent 'deviceready'

    @receivedEvent = (id) ->
      parent = document.getElementById id
      (parent.querySelector '.listening').setAttribute 'style', 'display:none;'
      (parent.querySelector '.received').setAttribute 'style', 'display:block;'
      console.log "Received Event: #{id}"

    @bindEvents()
