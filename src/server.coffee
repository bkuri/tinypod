#!/usr/bin/env coffee

express = require 'express'
app = express()
app.use express.static "#{__dirname}/public"
