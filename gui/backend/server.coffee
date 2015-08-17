#!/usr/bin/env coffee
###
# Mindbender GUI backend
###

## dependencies
util = require "util"
fs = require "fs-extra"
os = require "os"
{execFile} = require "child_process"

_ = require "underscore"
async = require "async"

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

# user defined extensions can be put under $PWD/mindbender/extensions.{js,coffee}
extensionsDirPath = "#{process.cwd()}/mindbender"
app.get "/mindbender/extensions.js", (req, res, next) ->
    compileCoffeeIfNeeded = (cs, next) ->
        js = cs.replace /\.coffee$/, ".js"
        fs.exists cs, (exists) ->
            return next yes unless exists
            async.map [cs, js], fs.stat, (err, [csStat, jsStat]) ->
                if jsStat? and (jsStat.mode & 0o222)
                    # we keep compiled .js write-protected, so skip if writable
                    util.log "Not compiling #{cs} because of existing .js"
                else
                    # check if .js is stale
                    if not jsStat? or csStat.mtime > jsStat.mtime
                        # compile .coffee and refresh .js
                        util.log "Compiling #{cs}"
                        return execFile "sh", ["-euc", """
                                rm -f "$2"
                                coffee -c -m "$1"
                                chmod a-w "$2"
                            """, "--", cs, js
                        ], (err, stdout, stderr) ->
                            console.error "Cannot compile #{cs}\n#{stderr}\n#{stdout}" if err
                            do next
                # nothing to do
                do next
    compileCoffeeIfNeeded "#{extensionsDirPath}/extensions.coffee", (err) ->
        do next
app.use "/mindbender/", express.static "#{extensionsDirPath}/"

#app.use express.methodOverride()
app.use express.static "#{__dirname}/files"

# start listening
server.listen (app.get "port"), ->
    util.log "Mindbender GUI started at http://#{os.hostname()}:#{app.get "port"}/"
