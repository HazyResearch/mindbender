#!/usr/bin/env coffee
###
# ScubaDeep backend
###

## dependencies
http = require "http"
express = require "express"
logger = require "morgan"
errorHandler = require "errorhandler"
bodyParser = require "body-parser"
jade = require "jade"
socketIO = require "socket.io"

util = require "util"
fs = require "fs"
os = require "os"
child_process = require "child_process"

_ = require "underscore"
async = require "async"

# parse command-line args and environment
SCUBADEEP_PORT = parseInt process.env.PORT ? 8000

## express.js server
app = module.exports = express()
server = http.createServer app
io = socketIO.listen server

app.set "port", SCUBADEEP_PORT
app.set "views", "#{__dirname}/views"
app.set "view engine", "jade"

app.use logger "dev"
app.use bodyParser.json()
app.use (bodyParser.urlencoded extended: true)
#app.use express.methodOverride()
app.use express.static "#{__dirname}/files"

if "development" == app.get "env"
    app.use errorHandler()

server.listen (app.get "port"), ->
    util.log "SKBDO started at http://#{os.hostname()}:#{SCUBADEEP_PORT}/"


## ScubaDeep backend services
app.get "/api/foo", (req, res) ->
    res.json "Not implemented"

