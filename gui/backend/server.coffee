#!/usr/bin/env coffee
###
# Mindbender GUI backend
###

## dependencies
util = require "util"
fs = require "fs-extra"
os = require "os"

_ = require "underscore"

http = require "http"
express = require "express"
logger = require "morgan"
errorHandler = require "errorhandler"
bodyParser = require "body-parser"
jade = require "jade"
socketIO = require "socket.io"

## express.js server
app = module.exports = express()
server = http.createServer app
io = socketIO.listen server

# pick up environment and command-line args
app.set "port", (parseInt process.env.PORT ? 8000)
app.set "views", "#{__dirname}/views"
app.set "view engine", "jade"

# set up logging
app.use logger "dev"
switch app.get "env"
    when "production"
        app.use logger "combined",
            stream: fs.createWriteStream (process.env.NODE_LOG ? "access.log"), flags: 'a'
    else
        app.use errorHandler()

# process-wide exception handler
process.on "uncaughtException", (err) ->
    if err.errno is "EADDRINUSE"
        console.error "Port #{app.get "port"} is already in use. To specify an alternative port, set PORT environment, e.g., PORT=12345"
        process.exit 2
    else
        throw err

# TODO use a more sophisticated command-line parser
cmdlnArgs = process.argv[2..]

## set up APIs for each components ############################################

components = [
    # Mindtagger
    require "./mindtagger/mindtagger-api"
    # Dashboard
    require "./dashboard/dashboard-api"
    # Search
    require "./search/search-api"
]

# set up component-specific middlewares
for component in components
    component.configureApp? app, cmdlnArgs

# set up some middlewares routes typically depend on, e.g., bodyParser
# XXX (bodyParser should be installed after some middlewares, e.g., reverse
# proxy middleware as it changes the request stream.)
app.use bodyParser.json()
app.use (bodyParser.urlencoded extended: true)

# set up routes
for component in components
    component.configureRoutes? app, cmdlnArgs

###############################################################################

#app.use express.methodOverride()
app.use express.static "#{__dirname}/files"

# start listening
server.listen (app.get "port"), ->
    util.log "Mindbender GUI started at http://#{os.hostname()}:#{app.get "port"}/"
