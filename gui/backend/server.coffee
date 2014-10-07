#!/usr/bin/env coffee
###
# MindBender GUI backend
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
path = require "path"
os = require "os"
child_process = require "child_process"

_ = require "underscore"
async = require "async"

{TSV,CSV} = require "tsv"
csv = require "csv"

# parse command-line args and environment
MINDBENDER_PORT = parseInt process.env.PORT ? 8000

# FIXME generalize
[baseDataFile, annotationFile] = process.argv[2..]

## express.js server
app = module.exports = express()
server = http.createServer app
io = socketIO.listen server

app.set "port", MINDBENDER_PORT
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
    util.log "MindBender GUI started at http://#{os.hostname()}:#{MINDBENDER_PORT}/"


## MindBender backend services
app.get "/api/foo", (req, res) ->
    res.json "Not implemented"

# load and serve data for tagging
loadDataFile = (fName, next) ->
    switch path.extname fName
        when ".tsv"
            next null, (TSV.parse String (fs.readFileSync fName))
        else # when ".csv"
            parser = csv.parse(columns:true)
            output = []
            parser.on "readable", ->
                while record = parser.read()
                    output.push record
            parser.on "error", next
            parser.on "finish", ->
                next null, output
            (fs.createReadStream fName)
                .pipe parser
async.parallel {
    baseData: (next) ->
        loadDataFile baseDataFile, next
    annotationData: (next) ->
        fs.exists annotationFile, (exists) ->
            if exists
                loadDataFile annotationFile, next
            else
                next null, []
}, (err, results) ->
    return console.error err if err?
    {baseData, annotationData} = results
    app.get "/api/tagr/basedata", (req, res) ->
        res.json baseData
    app.get "/api/tagr/annotation", (req, res) ->
        res.json annotationData

