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
fs = require "fs-extra"
path = require "path"
os = require "os"
child_process = require "child_process"

_ = require "underscore"
async = require "async"

{TSV,CSV} = require "tsv"
csv = require "csv"

MINDTAGGER_PRESET_ROOT = "#{process.env.MINDBENDER_HOME}/gui/presets"

# parse command-line args and environment
MINDBENDER_PORT = parseInt process.env.PORT ? 8000

tagrArgs = {}
[
    tagrArgs.itemsFile
    tagrArgs.workspaceDir
    tagrArgs.presets...
] = process.argv[2..] # FIXME generalize parsing
tagrArgs.workspaceDir ?= "#{tagrArgs.itemsFile}.tagging"
tagrArgs.presets = ["_default"] unless tagrArgs.presets?.length > 0

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


class MindbenderUtils
    @escapeSqlString: (s) ->
        s?.replace /'/g, "''"
    @asSqlLiteral: (value) ->
        if value?
            switch typeof value
                when "object"
                    "'#{MindbenderUtils.escapeSqlString (JSON.stringify value)}'"
                when "number"
                    if _.isNaN value
                        "NULL"
                    else
                        "#{value}"
                when "boolean"
                    if value then "TRUE" else "FALSE"
                else # when "string"
                    "'#{MindbenderUtils.escapeSqlString value}'"
        else
            "NULL"
    @findAllKeys: (objs) ->
        merged = {}
        _.extend merged, obj for obj in objs
        _.keys merged


# some routines for loading and storing data
CSV_OPTIONS =
    columns: yes
    header: yes
loadDataFile = (fName, next) ->
    console.log "loading #{fName}"
    try
        switch path.extname fName
            when ".tsv"
                fs.readFile fName, (err, data) -> next err, try (TSV.parse String data)
            when ".json"
                fs.readFile fName, (err, data) -> next err, try (JSON.parse String data)
            else # when ".csv"
                parser = csv.parse (_.clone CSV_OPTIONS)
                output = []
                parser.on "readable", ->
                    while record = parser.read()
                        output.push record
                parser.on "error", next
                parser.on "finish", ->
                    next null, output
                (fs.createReadStream fName)
                    .pipe parser
    catch err
        next err
loadOptionalDataFile = (fName, defaultValue, next) ->
    fs.exists fName, (exists) ->
        if exists
            loadDataFile fName, next
        else
            next null, defaultValue
writeDataFile = (fName, array, next) ->
    try
        console.log "writing #{fName}"
        switch path.extname fName
            when ".tsv"
                fs.writeFile fName, (TSV.stringify array), next
            when ".json"
                fs.writeFile fName, (JSON.stringify array), next
            else # when ".csv"
                # find out the columns first
                columns = MindbenderUtils.findAllKeys objs
                # Stringify all columns
                arrayProcessed =
                    for row in array
                        rowProcessed = {}
                        rowProcessed[col] = String val for col,val of row
                        rowProcessed
                # write CSV
                csv.stringify arrayProcessed, {
                    header: yes
                    columns
                }, (err, formatted) ->
                    return next err if err
                    fs.writeFile fName, formatted, next
    catch err
        next err

tagrArgs.presetDirs =
    for preset,i in tagrArgs.presets
        presetDir = preset
        if not fs.existsSync presetDir
            bundledPresetDir = "#{MINDTAGGER_PRESET_ROOT}/#{presetDir}"
            if fs.existsSync bundledPresetDir
                presetDir = bundledPresetDir
        unless (fs.statSync presetDir)?.isDirectory()
            throw new Error "#{presetDir}: Not a directory"
        presetDir
console.log "Mindtagger using ", tagrArgs
fs.mkdirsSync tagrArgs.workspaceDir
tagsFile    = "#{tagrArgs.workspaceDir}/tags.json"
schemaFiles = ("#{presetDir}/schema.json" for presetDir in tagrArgs.presetDirs)
async.parallel {
    items : (next) -> loadDataFile tagrArgs.itemsFile, next
    tags  : (next) -> loadOptionalDataFile tagsFile, [], next
    schema: (next) ->
        # load all schema files and merge
        async.map schemaFiles,
            (fName, next) -> loadOptionalDataFile fName, {}, next
            (err, schemas) ->
                return next err if err
                schema = {}
                _.extend schema, s for s in schemas.reverse()
                next null, schema
}, (err, results) ->
    return console.error err if err?
    {items, tags, schema} = results

    # write the tags to file upon receiving signals and exit
    areTagsDirty = no
    writeTags = (options) -> ->
        write = ->
            writeDataFile tagsFile, tags, ->
                areTagsDirty = no
                process.exit options.thenExit if options.thenExit?
        if areTagsDirty
            do write
        else
            fs.exists tagsFile, (exists) ->
                unless exists
                    do write
                else
                    console.log "no need to write #{tagsFile}"
                    process.exit options.thenExit if options.thenExit?
    process.on "SIGQUIT", writeTags {}
    process.on "SIGINT",  writeTags thenExit:130
    process.on "SIGTERM", writeTags thenExit:143
    process.on "exit",    writeTags thenExit:0

    # set up preset URLs to make mixin mechanism work
    MIXIN_PRESET_DIR = "#{MINDTAGGER_PRESET_ROOT}/_mixin"
    DEFAULT_PRESET_DIR = "#{MINDTAGGER_PRESET_ROOT}/_default"
    for preset,i in tagrArgs.presets
        presetDir = tagrArgs.presetDirs[i]
        app.use "/tagr/preset/#{preset}", express.static presetDir
        app.use "/tagr/preset/#{preset}", express.static MIXIN_PRESET_DIR
    app.use "/tagr/preset", express.static MINDTAGGER_PRESET_ROOT

    # set up JSON APIs
    app.get "/api/tagr/schema", (req, res) ->
        res.json
            presets: tagrArgs.presets
            tags:    schema
    app.get "/api/tagr/items", (req, res) ->
        res.json items
    app.get "/api/tagr/tags", (req, res) ->
        res.json tags
    # TODO use keys instead of index
    # TODO support saving the entire state?
    app.post "/api/tagr/tags", (req, res) ->
        index = req.body.index
        if 0 <= index < items.length
            tags[index] = req.body.tag
            areTagsDirty = yes
            # TODO write to tags file
            res.json true
        else
            res.status 400
                .send "Bad request: index #{index} not in range [0, #{items.length})"

    # set up APIs for exporting
    exportTagsWithItemKeys = (keys) ->
        for item,i in items
            row = _.extend {}, tags[i]
            row[key] = item[key] for key in keys
            row
    app.get "/api/tagr/tags.:format", (req, res) ->
        format = req.param "format"
        keys = req.param("keys")?.split(/\s*,\s*/)
        unless keys?.length > 0
            return res.status 400
                .send "Bad request: no keys specified"
        rows = exportTagsWithItemKeys keys
        columnNames = MindbenderUtils.findAllKeys rows
        res.contentType "text/plain"
        res.set "Content-Disposition": "attachment; filename=tags-#{
            keys.join "-"}.#{new Date().toISOString()}.#{format}"
        switch format
            when "sql"
                tableName = req.param "table" ? "tags"
                res.send """
                    DROP TABLE #{tableName};
                    CREATE TABLE #{tableName}(\n#{("#{c} TEXT" for c in columnNames).join ",\n"}
                    );
                    INSERT INTO #{tableName}(#{(columnNames.join ", ")}) VALUES
                    #{(
                        for row in rows
                            "(#{(MindbenderUtils.asSqlLiteral row[c] for c in columnNames).join ", "})"
                    ).join ",\n"
                    };
                    """
            when "tsv"
                res.send TSV.stringify rows
            when "csv"
                csv.stringify rows, {
                    header: yes
                    columns: columnNames
                }, (err, formatted) ->
                    if err
                        res.status 500
                            .send "Failed to export in CSV"
                    else
                        res.send formatted
            when "json"
                res.contentType "application/json"
                res.json rows
            else
                res.status 404
                    .send "Not found"

