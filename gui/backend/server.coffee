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

MINDTAGGER_PRESET_ROOT = "#{process.env.MINDBENDER_HOME}/gui/mindtagger-presets"

# parse command-line args and environment
MINDBENDER_PORT = parseInt process.env.PORT ? 8000

# TODO use a more sophisticated command-line parser
mindtaggerConfFiles = process.argv[2..]

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
    @CSV_OPTIONS:
        columns: yes
        header: yes
    @loadDataFile: (fName, next) ->
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
    @loadOptionalDataFile: (fName, defaultValue, next) ->
        fs.exists fName, (exists) ->
            if exists
                MindbenderUtils.loadDataFile fName, next
            else
                next null, defaultValue
    @writeDataFile: (fName, array, next) ->
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


###
# Mindtagger
###

## A Mindtagger task that holds items and tags with a schema and other info
class MindtaggerTask
    @ALL = {}
    constructor: (@config) ->
        # load task config if necessary
        unless typeof @config is "object"
            configFile = @config
            @config = JSON.parse (fs.readFileSync configFile)
            @config.path = path.resolve (path.dirname configFile)
        throw new Error "No path set in config", @config unless @config.path
        # determine task's name
        @config.name ?= path.basename @config.path
        if MindtaggerTask.ALL[@config.name]?
            suffix = 1
            ++suffix while MindtaggerTask.ALL["#{@config.name}-#{suffix}"]?
            @config.name += "-#{suffix}"
        # initialize fields
        @items = null
        @tags = null
        @areTagsDirty = no
        # resolve all preset directories
        @config.presetDirs =
            for [presetName] in @config.presets
                presetDir = presetName
                if not fs.existsSync presetDir
                    bundledPresetDir = "#{MINDTAGGER_PRESET_ROOT}/#{presetDir}"
                    if fs.existsSync bundledPresetDir
                        presetDir = bundledPresetDir
                try
                    stat = fs.statSync presetDir
                catch err
                    throw new Error "#{presetDir}: No such directory"
                unless stat.isDirectory()
                    throw new Error "#{presetDir}: Not a directory"
                presetDir
        # register itself
        MindtaggerTask.registerTask @

    preferCached: (cache, generator) -> (next) ->
        if cache?
            next null, cache
        else
            generator next

    getBaseTagsSchema: (next) => (@preferCached @baseTagsSchema, (next) =>
            # load all schema files and merge
            schemaFiles = ("#{presetDir}/schema.json" for presetDir in @config.presetDirs)
            async.map schemaFiles,
                (fName, next) -> MindbenderUtils.loadOptionalDataFile fName, {}, next
            , (err, schemas) =>
                return next err if err
                @baseTagsSchema = {}
                _.extend @baseTagsSchema, s for s in schemas.reverse()
                next null, @baseTagsSchema
        ) next

    getItemsWithTags: (next, offset = 0, limit) =>
        async.parallel {
            items: @preferCached @items, (next) =>
                itemsFile = path.resolve @config.path, @config.items?.file
                MindbenderUtils.loadDataFile itemsFile, (err, @items) =>
                    return next err if err
                    @items ?= []
                    # TODO offset, limit
                    next err, @items
            tags: @preferCached @tags, (next) =>
                tagsFile = path.resolve @config.path, "tags.json"
                MindbenderUtils.loadOptionalDataFile tagsFile, [], (err, @tags) =>
                    return next err if err
                    @tags ?= []
                    # TODO offset, limit
                    next err, @tags
        }, next

    getSchema: (next) => (@preferCached @schema, (next) =>
            @getBaseTagsSchema (err, baseTagsSchema) =>
                return next err if err
                @getItemsWithTags (err, {items, tags}) =>
                    return next err if err
                    @schema =
                        items: @config.items?.schema ? MindtaggerTask.deriveSchema items
                        tags : MindtaggerTask.deriveSchema tags, baseTagsSchema
                    next null, @schema
        ) next
    @deriveSchema: (tags, baseSchema) ->
        schema = {}
        # examine all tags  # TODO sample if large?
        for tag in tags
            for name,value of tag
                ((schema[name] ?= {}).values ?= []).push value
        # infer type by induction on observed values
        for tagName,tagSchema of schema
            tagSchema.type =
                if (tagSchema.values.every (v) -> not v? or (typeof v) is 'boolean') or
                        tagSchema.values.length == 2 and
                        not tagSchema.values[0] is not not tagSchema.values[1]
                    'binary'
                else
                    # TODO 'categorical'
                    'freetext'
        if baseSchema?
            _.extend schema, baseSchema
        else
            schema

    setTagsForItems: (tagsByIndex, next) =>
        # TODO use keys instead of index
        index = tagsByIndex.index
        if 0 <= index < @items.length
            @tags ?= []
            @tags[index] = tagsByIndex.tag
            @areTagsDirty = yes
            # update tags schema
            @getSchema (err, schema) =>
                return next err if err
                schema.tags = MindtaggerTask.deriveSchema [@tags[index]], schema.tags
                next null
        else
            next "index #{index} not in range [0, #{@items.length})"


    writeChanges: (next) =>
        # write the tags to file
        tagsFile = path.resolve @config.path, "tags.json"
        write = (next) =>
            MindbenderUtils.writeDataFile tagsFile, @tags, (err) =>
                @areTagsDirty = no unless err
                next err
        if @areTagsDirty
            write next
        else
            fs.exists tagsFile, (exists) ->
                unless exists
                    write next
                else
                    console.log "no need to write #{tagsFile}"
                    next null

    @WRITER_T = null
    @WRITER_INTERVAL = 30 * 1000
    @registerTask: (task) ->
        MindtaggerTask.ALL[task.config.name] = task
        unless @WRITER_T?
            # set up a periodic task that writes back changes
            @WRITER_T =
                setInterval MindtaggerTask.writeBackChanges, @WRITER_INTERVAL
            # as well as upon receiving signals and exit
            process.on "SIGQUIT", => MindtaggerTask.writeBackChanges()
            process.on "SIGINT",  => MindtaggerTask.writeBackChanges -> process.exit 130
            process.on "SIGTERM", => MindtaggerTask.writeBackChanges -> process.exit 143
            #process.on "exit",    => MindtaggerTask.writeBackChanges -> process.exit 0
    @writeBackChanges: (next = (err) ->) ->
        async.each (_.values MindtaggerTask.ALL), ((task, next) -> task.writeChanges next), next

    @getAllPresetDirsByPreset: ->
        map = {}
        for taskName,task of MindtaggerTask.ALL
            for preset,i in task.config.presets
                presetDir = task.config.presetDirs[i]
                map[preset] = presetDir
        map
                

# prepare Mindtagger tasks based on given json files
for confFile in mindtaggerConfFiles
    # construct a task
    new MindtaggerTask confFile

console.log "Loaded #{_.size MindtaggerTask.ALL} Mindtagger tasks", MindtaggerTask.ALL  # XXX debug

## Configure Mindtagger API URLs
# set up preset URLs to make mixin mechanism work
MIXIN_PRESET_DIR = "#{MINDTAGGER_PRESET_ROOT}/_mixin"
DEFAULT_PRESET_DIR = "#{MINDTAGGER_PRESET_ROOT}/_default"
for preset,presetDir of MindtaggerTask.getAllPresetDirsByPreset()
    app.use "/mindtagger/preset/#{preset}", express.static presetDir
    app.use "/mindtagger/preset/#{preset}", express.static MIXIN_PRESET_DIR
app.use "/mindtagger/preset", express.static MINDTAGGER_PRESET_ROOT

# list of all tasks
app.get "/api/mindtagger/", (req, res) ->
    res.json (task.config for taskName,task of MindtaggerTask.ALL)

# each task
withTask = (taskName, req, res, next) ->
    task = MindtaggerTask.ALL[taskName]
    unless task?
        res.status 404
            .send "No such task: #{taskName}"
    else
        next task
app.get "/api/mindtagger/:task/schema", (req, res) ->
    withTask (req.param "task"), req, res, (task) ->
        task.getSchema (err, schema) ->
            if err
                return res.status 500
                    .send "Internal error: #{err}"
            res.json
                presets: task.config.presets
                schema:  schema
app.get "/api/mindtagger/:task/items", (req, res) ->
    # TODO support offset, limit from req
    # TODO sanity check offset, limit
    withTask (req.param "task"), req, res, (task) ->
        task.getItemsWithTags (err, taggedItems) ->
            if err
                return res.status 500
                    .send "Internal error: #{err}"
            res.json taggedItems
app.post "/api/mindtagger/:task/items", (req, res) ->
    withTask (req.param "task"), req, res, (task) ->
        task.setTagsForItems req.body, (err) ->
            if err
                return res.status 400
                    .send "Bad request: #{err}"
            res.json task.schema

# TODO continue below ###############################################
# set up APIs for exporting
exportTagsWithItemKeys = (keys) ->
    for item,i in items
        row = _.extend {}, tags[i]
        row[key] = item[key] for key in keys
        row
app.get "/api/mindtagger/tags.:format", (req, res) ->
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
            tableName = (req.param "table") ? "tags"
            # TODO escape quoted columnNames?
            res.send """
                DROP TABLE #{tableName};
                CREATE TABLE #{tableName}(\n#{("\"#{c}\" TEXT" for c in columnNames).join ",\n"}
                );
                INSERT INTO #{tableName}(#{(("\"#{c}\"" for c in columnNames).join ", ")}) VALUES
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

