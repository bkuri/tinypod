###
lscache library
Copyright (c) 2011, Pamela Fox

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
###

#jshint undef:true, browser:true 

###
Creates a namespace for the lscache functions.
###
lscache = ->
  
  # Prefix for all lscache keys
  
  # Suffix for the key name on the expiration items in localStorage
  
  # expiration date radix (set to Base-36 for most space savings)
  
  # time resolution in minutes
  
  # ECMAScript max Date (epoch + 1e8 days)
  
  # Determines if localStorage is supported in the browser;
  # result is cached for better performance instead of being run each time.
  # Feature detection is based on how Modernizr does it;
  # it's not straightforward due to FF4 issues.
  # It's not run at parse-time as it takes 200ms in Android.
  supportsStorage = ->
    key = "__lscachetest__"
    value = key
    return cachedStorage  if cachedStorage isnt `undefined`
    try
      setItem key, value
      removeItem key
      cachedStorage = true
    catch exc
      cachedStorage = false
    cachedStorage
  
  # Determines if native JSON (de-)serialization is supported in the browser.
  supportsJSON = ->
    
    #jshint eqnull:true 
    cachedJSON = (window.JSON?)  if cachedJSON is `undefined`
    cachedJSON
  
  ###
  Returns the full string for the localStorage expiration item.
  @param {String} key
  @return {string}
  ###
  expirationKey = (key) ->
    key + CACHE_SUFFIX
  
  ###
  Returns the number of minutes since the epoch.
  @return {number}
  ###
  currentTime = ->
    Math.floor (new Date().getTime()) / EXPIRY_UNITS
  
  ###
  Wrapper functions for localStorage methods
  ###
  getItem = (key) ->
    localStorage.getItem CACHE_PREFIX + cacheBucket + key
  setItem = (key, value) ->
    
    # Fix for iPad issue - sometimes throws QUOTA_EXCEEDED_ERR on setItem.
    localStorage.removeItem CACHE_PREFIX + cacheBucket + key
    localStorage.setItem CACHE_PREFIX + cacheBucket + key, value
  removeItem = (key) ->
    localStorage.removeItem CACHE_PREFIX + cacheBucket + key
  warn = (message, err) ->
    return  unless warnings
    return  if not "console" of window or typeof window.console.warn isnt "function"
    window.console.warn "lscache - " + message
    window.console.warn "lscache - The error was: " + err.message  if err
  CACHE_PREFIX = "lscache-"
  CACHE_SUFFIX = "-cacheexpiration"
  EXPIRY_RADIX = 10
  EXPIRY_UNITS = 60 * 1000
  MAX_DATE = Math.floor(8.64e15 / EXPIRY_UNITS)
  cachedStorage = undefined
  cachedJSON = undefined
  cacheBucket = ""
  warnings = false
  
  ###
  Stores the value in localStorage. Expires after specified number of minutes.
  @param {string} key
  @param {Object|string} value
  @param {number} time
  ###
  set: (key, value, time) ->
    return  unless supportsStorage()
    
    # If we don't get a string value, try to stringify
    # In future, localStorage may properly support storing non-strings
    # and this can be removed.
    if typeof value isnt "string"
      return  unless supportsJSON()
      try
        value = JSON.stringify(value)
      catch e
        
        # Sometimes we can't stringify due to circular refs
        # in complex objects, so we won't bother storing then.
        return
    try
      setItem key, value
    catch e
      if e.name is "QUOTA_EXCEEDED_ERR" or e.name is "NS_ERROR_DOM_QUOTA_REACHED" or e.name is "QuotaExceededError"
        
        # If we exceeded the quota, then we will sort
        # by the expire time, and then remove the N oldest
        storedKeys = []
        storedKey = undefined
        i = 0

        while i < localStorage.length
          storedKey = localStorage.key(i)
          if storedKey.indexOf(CACHE_PREFIX + cacheBucket) is 0 and storedKey.indexOf(CACHE_SUFFIX) < 0
            mainKey = storedKey.substr((CACHE_PREFIX + cacheBucket).length)
            exprKey = expirationKey(mainKey)
            expiration = getItem(exprKey)
            if expiration
              expiration = parseInt(expiration, EXPIRY_RADIX)
            else
              
              # TODO: Store date added for non-expiring items for smarter removal
              expiration = MAX_DATE
            storedKeys.push
              key: mainKey
              size: (getItem(mainKey) or "").length
              expiration: expiration

          i++
        
        # Sorts the keys with oldest expiration time last
        storedKeys.sort (a, b) ->
          b.expiration - a.expiration

        targetSize = (value or "").length
        while storedKeys.length and targetSize > 0
          storedKey = storedKeys.pop()
          warn "Cache is full, removing item with key '" + key + "'"
          removeItem storedKey.key
          removeItem expirationKey(storedKey.key)
          targetSize -= storedKey.size
        try
          setItem key, value
        catch e
          
          # value may be larger than total quota
          warn "Could not add item with key '" + key + "', perhaps it's too big?", e
          return
      else
        
        # If it was some other error, just give up.
        warn "Could not add item with key '" + key + "'", e
        return
    
    # If a time is specified, store expiration info in localStorage
    if time
      setItem expirationKey(key), (currentTime() + time).toString(EXPIRY_RADIX)
    else
      
      # In case they previously set a time, remove that info from localStorage.
      removeItem expirationKey(key)

  
  ###
  Retrieves specified value from localStorage, if not expired.
  @param {string} key
  @return {string|Object}
  ###
  get: (key) ->
    return null  unless supportsStorage()
    
    # Return the de-serialized item if not expired
    exprKey = expirationKey(key)
    expr = getItem(exprKey)
    if expr
      expirationTime = parseInt(expr, EXPIRY_RADIX)
      
      # Check if we should actually kick item out of storage
      if currentTime() >= expirationTime
        removeItem key
        removeItem exprKey
        return null
    
    # Tries to de-serialize stored value if its an object, and returns the normal value otherwise.
    value = getItem(key)
    return value  if not value or not supportsJSON()
    try
      
      # We can't tell if its JSON or a string, so we try to parse
      return JSON.parse(value)
    catch e
      
      # If we can't parse, it's probably because it isn't an object
      return value

  
  ###
  Removes a value from localStorage.
  Equivalent to 'delete' in memcache, but that's a keyword in JS.
  @param {string} key
  ###
  remove: (key) ->
    return null  unless supportsStorage()
    removeItem key
    removeItem expirationKey(key)

  
  ###
  Returns whether local storage is supported.
  Currently exposed for testing purposes.
  @return {boolean}
  ###
  supported: ->
    supportsStorage()

  
  ###
  Flushes all lscache items and expiry markers without affecting rest of localStorage
  ###
  flush: ->
    return  unless supportsStorage()
    
    # Loop in reverse as removing items will change indices of tail
    i = localStorage.length - 1

    while i >= 0
      key = localStorage.key(i)
      localStorage.removeItem key  if key.indexOf(CACHE_PREFIX + cacheBucket) is 0
      --i

  
  ###
  Appends CACHE_PREFIX so lscache will partition data in to different buckets.
  @param {string} bucket
  ###
  setBucket: (bucket) ->
    cacheBucket = bucket

  
  ###
  Resets the string being appended to CACHE_PREFIX so lscache will use the default storage behavior.
  ###
  resetBucket: ->
    cacheBucket = ""

  
  ###
  Sets whether to display warnings when an item is removed from the cache or not.
  ###
  enableWarnings: (enabled) ->
    warnings = enabled
lscache()
