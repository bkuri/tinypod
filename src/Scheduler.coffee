'use strict'

class Scheduler
  @addTask: (name, task, period, recurring=false) ->
    #schedule = later.parse.text period
    #console.log "addTask -> #{name}: #{later.schedule(schedule).next(2)[1]}"
    #if recurring then later.setInterval task, schedule
    #else later.setTimeout task, schedule
    console.log 'addTask'

  @init: ->
    Scheduler.addTask Store.refreshFeeds Feeds.fetch, (Store.config 'refresh-feeds'), true
    Scheduler.addTask Store.refreshSession, (Store.config 'refresh-session'), true

  constructor: ->
    #Scheduler.init()
    console.log 'Scheduler started'
