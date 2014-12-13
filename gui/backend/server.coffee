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


# TODO use a more sophisticated command-line parser
mindtaggerConfFiles = process.argv[2..]

## express.js server
app = module.exports = express()
server = http.createServer app
io = socketIO.listen server

# pick up environment and command-line args
app.set "port", (parseInt process.env.PORT ? 8000)

app.set "views", "#{__dirname}/views"
app.set "view engine", "jade"
app.use bodyParser.json()
app.use (bodyParser.urlencoded extended: true)
#app.use express.methodOverride()
app.use express.static "#{__dirname}/files"

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

server.listen (app.get "port"), ->
    util.log "MindBender GUI started at http://#{os.hostname()}:#{app.get "port"}/"

## MindBender backend services
class MindbenderUtils
    # Expand all parameter references in the strings of given value.  Expansion
    # is done recursively to values and elements if it is a complex Object or
    # Array.
    @expandParameters: (value, params) ->
        return value unless params?
        expanded = (o) ->
            if "string" is typeof o
                o.replace ///
                        [$][{]   # begin string '${'
                        ([^{}]+) #  parameter name may not include { or }
                        [}]      # end string '}'
                    ///g, (m, name) ->
                        params[name] ? m
            else if o instanceof Array
                expanded v for v in o
            else if "object" is typeof o
                eo = {}
                for k,v of o
                    eo[k] = expanded v
                eo
            else
                o
        expanded value

    @escapeSqlString: (s) ->
        s?.replace /'/g, "''"
    @escapeSqlName: (n) ->
        # use double quote to escape SQL names
        "\"#{n?.replace /"/g, "\"\""}\""
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
        auto_parse: yes
    @convertValues: (array, from, to) ->
        if array?
            for row in array
                row[key] = to for key,value of row when (from? and value is from) or (not value? and not from?)
            array
    @deserializeNullStrings: (array) -> MindbenderUtils.convertValues array, "\\N", null
    @serializeNulls:         (array) -> MindbenderUtils.convertValues array, null, "\\N"
    @unescapeBackslashes: (array) ->
        if array?
            for row in array
                for key,value of row when "string" is typeof value
                    row[key] = value
                        .replace /\\(.)/g, (m, c) ->
                            switch c
                                when "t"
                                    "\t"
                                when "n"
                                    "\n"
                                else
                                    c
            array
    @escapeWithBackslashes: (array) ->
        if array?
            for row in array
                for key,value of row when "string" is typeof value
                    row[key] = value
                        .replace /([\t\n\\])/g, (m, c) ->
                            switch c
                                when "\t"
                                    "\\t"
                                when "\n"
                                    "\\n"
                                else
                                    "\\#{c}"
            array
    @loadDataFile: (fName, next) ->
        util.log "loading #{fName}"
        try
            switch path.extname fName
                when ".json"
                    fs.readFile fName, (err, data) -> next err, try (JSON.parse String data)
                when ".tsv"
                    fs.readFile fName, (err, data) -> next err,
                      MindbenderUtils.unescapeBackslashes (
                          MindbenderUtils.deserializeNullStrings (
                              try (TSV.parse (String data).replace /[\r\n]+$/g, ""))
                      )
                else # when ".csv"
                    parser = csv.parse (_.clone MindbenderUtils.CSV_OPTIONS)
                    output = []
                    parser
                        .on "readable", ->
                            while record = parser.read()
                                output.push record
                        .on "error", next
                        .on "finish", ->
                            next null, MindbenderUtils.deserializeNullStrings output
                    input = (fs.createReadStream fName)
                        .on "error", next
                        .on "open", -> input.pipe parser
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
            util.log "writing #{fName}"
            switch path.extname fName
                when ".json"
                    fs.writeFile fName, (JSON.stringify array, null, 1), next
                when ".tsv"
                    fs.writeFile fName, (TSV.stringify (
                        MindbenderUtils.serializeNulls (
                            MindbenderUtils.escapeWithBackslashes array))), next
                else # when ".csv"
                    # find out the columns first
                    columns = MindbenderUtils.findAllKeys objs
                    # Stringify all columns
                    arrayProcessed =
                        for row in array
                            rowProcessed = {}
                            rowProcessed[col] = String val for col,val of row
                            rowProcessed
                    arrayProcessed = MindbenderUtils.serializeNulls arrayProcessed
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
    @nameFor: (taskName, params) ->
        if params?
            for name in (_.keys params).sort()
                value = params[name]
                taskName += " #{name}=#{value}"
        taskName

    constructor: (@config, @params, next) ->
        # load task config if necessary
        unless typeof @config is "object"
            configFile = @config
            @config = JSON.parse (fs.readFileSync configFile)
            @config.file = configFile
            @config.path = path.resolve (path.dirname configFile)
        throw new Error "No path set in config", @config unless @config.path
        # determine task's name
        @config.name ?= path.basename @config.path
        @config.name = MindtaggerTask.nameFor @config.name, @params
        if MindtaggerTask.ALL[@config.name]?
            suffix = 1
            ++suffix while MindtaggerTask.ALL["#{@config.name}-#{suffix}"]?
            @config.name += "-#{suffix}"
        # do not actually load anything if this is a parameterized task but no values were supplied
        if @config.params?.length > 0 and not @params?
            @isAbstract = -> yes
            @instantiateIfNeeded = (params, next) =>
                instanceName = MindtaggerTask.nameFor @config.name, params
                instance = MindtaggerTask.ALL[instanceName]
                if instance?
                    next null, instance, instanceName
                else
                    # instantiate one if doesn't exist yet
                    config = _.extend {}, @config
                    new MindtaggerTask config, params, (err, instance) =>
                        instance.baseTask = @
                        next null, instance, instanceName
            MindtaggerTask.registerTask @
            next null, @
        else
            @isAbstract = -> no
            # expand all parameters
            @config = MindbenderUtils.expandParameters @config, @params
            # making sure there's tags config as it's crucial
            @config.tags ?=
                storage: "file"
                file: "tags.json"
            # initialize fields
            @allItems = null
            @allTags = null
            @areTagsDirty = no
            # load all schema files and merge
            @baseTagsSchema = {}
            schemaFiles = ("#{dir}/schema.json" for dir in [@config.path])
            async.map schemaFiles,
                (fName, next) -> MindbenderUtils.loadOptionalDataFile fName, {}, next
            , (err, schemas) =>
                return next err if err
                _.extend @baseTagsSchema, s for s in schemas.reverse()
                # finally, register itself
                MindtaggerTask.registerTask @
                next null, @

    preferCached: (cache, generator) -> (next) ->
        if cache?
            next null, cache
        else
            generator next

    createEmptyTags: =>
        version: 1
        key_columns: @config.items?.key_columns ? []
        by_key: {}

    getItemsWithTags: (next, offset, limit) =>
        async.parallel {
            allItems: @preferCached @allItems, (next) =>
                itemsFile = path.resolve @config.path, @config.items?.file
                MindbenderUtils.loadDataFile itemsFile, (err, @allItems) =>
                    return next err if err
                    @allItems ?= []
                    next err, @allItems
            allTags: @preferCached @allTags, (next) =>
                tagsFile = path.resolve @config.path, @config.tags.file
                emptyTags = @createEmptyTags()
                MindbenderUtils.loadOptionalDataFile tagsFile, emptyTags, (err, @allTags) =>
                    return next err if err
                    @allTags ?= emptyTags
                    next err, @allTags
        }, (err, {allItems, allTags}) =>
            return next err, {} if err
            # XXX backward compatibility: upgrade Array-type tags to Object
            if allTags instanceof Array
                util.log "#{@config.name}: upgrading #{@config.tags.file} from Array"
                tagsArray = allTags
                allTags = @allTags = @createEmptyTags()
                for tag,idx in tagsArray when tag?
                    key = @keyFor allItems[idx], idx
                    allTags.by_key[key] = tag
            # XXX backward compatibility: upgrade plain Object tags
            unless allTags.version? and allTags.by_key?
                util.log "#{@config.name}: upgrading #{@config.tags.file} from plain Object"
                byKey = allTags
                allTags = @allTags = @createEmptyTags()
                allTags.by_key = byKey
            # make sure we know how to handle this version
            unless allTags.version == 1
                err = new Error "#{@config.tags.file} version #{allTags.version} unsupported"
                util.log err
                return next err, {}
            # try upgrading if key_columns have changed
            if (JSON.stringify allTags.key_columns) isnt (JSON.stringify @config.items?.key_columns)
                util.log "#{@config.name}: upgrading keys for #{@config.tags.file} from [#{allTags.key_columns}] to [#{@config.items?.key_columns}]"
                byNewKey = {}
                oldKeyColumns = allTags.key_columns
                for item,idx in allItems
                    oldKey = @keyFor item, idx, oldKeyColumns
                    if (tag = allTags.by_key[oldKey])?
                        newKey = @keyFor item, idx
                        byNewKey[newKey] = tag
                        delete allTags.by_key[oldKey]
                        break if (_.size allTags.by_key) == 0
                allTags.by_key = byNewKey
                allTags.key_columns = @config.items?.key_columns
            # offset, limit
            # TODO more sanity check offset, limit
            items =
                if offset? and limit?
                    allItems[offset...(offset+limit)]
                else if offset?
                    allItems[offset...]
                else if limit?
                    allItems[...limit]
                else
                    allItems
            # join items with tags
            tags = []
            for item,i in items
                idx = offset + i
                key = @keyFor item, idx
                tags.push allTags.by_key[key]
            next null, {
                itemsCount: allItems.length
                items
                tags
            }

    keyFor: (item, idx, key_columns = @config.items?.key_columns) =>
        if key_columns?.length > 0
            # use the configured key_columns
            (item[k] for k in key_columns).join "\t"
        else
            # or simply the row position
            idx

    getSchema: (next) => (@preferCached @schema, (next) =>
            @getItemsWithTags (err, {items, tags}) =>
                return next err if err
                @schema =
                    items: @config.items?.schema ? MindtaggerTask.deriveSchema items
                    itemKeys: @config.items?.key_columns
                    tags: MindtaggerTask.deriveSchema tags, @baseTagsSchema
                next null, @schema
        ) next
    @deriveSchema: (tags, baseSchema, oldTags) ->
        schema = {}
        _.extend schema, baseSchema if baseSchema?
        # compute frequency of all values of all tags
        # TODO sample if large?
        for tag in tags when tag?
            for name,value of tag when value?
                v = JSON.stringify value
                ((schema[name] ?= {}).frequency ?= {})[v] ?= 0
                schema[name].frequency[v] += 1
            for name,s of schema
                s.count = 0 unless oldTags?
                s.count += f for v,f of s.frequency
        if oldTags?
            # perform incremental maintenance of value frequencies if previous
            # values of the same tags were given as well
            for tag in oldTags when tag?
                for name,value of tag when value? and schema[name]?
                    v = JSON.stringify value
                    unless (schema[name].frequency?[v] -= 1) > 0
                        delete schema[name].frequency[v]
            for name,s of schema
                s.count -= f for v,f of s.frequency
                delete s.count unless s.count >= 0
        # infer type by induction on observed values
        for tagName,tagSchema of schema when not tagSchema.type?
            values = (JSON.parse v for v of tagSchema.frequency)
            values.push null
            tagSchema.type =
                if (values.every (v) -> not v? or (typeof v) is 'boolean') or
                        values.length == 2 and
                        not values[0] is not not values[1]
                    tagSchema.values = values
                    'binary'
                else
                    # TODO 'categorical'
                    delete tagSchema.frequency
                    'text'
        schema

    setTagsForItems: (updates, next) =>
        @getItemsWithTags (err, {items, tags}) =>
            oldTags = (@allTags.by_key[update.key] for update in updates)
            newTags =
                for update in updates
                    key = update.key
                    @areTagsDirty = yes
                    @allTags.by_key[key] = update.tag
            # update tags schema
            @getSchema (err, schema) =>
                return next err if err
                schema.tags = MindtaggerTask.deriveSchema newTags, schema.tags, oldTags
                next null


    writeChanges: (next) =>
        # write the tags to file
        tagsFile = path.resolve @config.path, @config.tags.file
        write = (next) =>
            MindbenderUtils.writeDataFile tagsFile, @allTags, (err) =>
                @areTagsDirty = no unless err
                next err
        # TODO persist schema as well
        if @areTagsDirty
            write next
        else
            fs.exists tagsFile, (exists) ->
                unless exists
                    write next
                else
                    next null

    @WRITER_T = null
    @WRITER_INTERVAL = 30 * 1000
    @registerTask: (task) ->
        util.log "Loaded Mindtagger task #{task.config.name}"
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
        allConcreteTasks = (task for task in _.values MindtaggerTask.ALL when not task.isAbstract())
        async.each allConcreteTasks, ((task, next) -> task.writeChanges next), next


# prepare Mindtagger tasks based on given json files
async.map mindtaggerConfFiles,
    (confFile, next) -> new MindtaggerTask confFile, null, next
, (err, tasks) ->
    throw err if err
    #util.log "Mindtagger task #{task.name}: #{JSON.stringify task.config, null, 2}" for task in _.values MindtaggerTask.ALL  # XXX debug
    util.log "Loaded #{_.size tasks} Mindtagger tasks: #{task.config.name for task in tasks}"
    # expose each task directory
    for task in tasks
        app.use "/mindtagger/tasks/#{task.config.name}/", express.static task.config.path


## Configure Mindtagger API URLs

# list of all tasks
app.get "/api/mindtagger/", (req, res) ->
    res.json (task.config for taskName,task of MindtaggerTask.ALL when not task.isAbstract())

# each task
withTask = (taskName, req, res, next) ->
    task = MindtaggerTask.ALL[taskName]
    unless task?
        res.status 404
            .send "No such task: #{taskName}"
    else
        if task.isAbstract()
            # collect supplied parameter values if task is parameterized
            params = {}
            for name in task.config.params
                value = req.param "task_#{name}"
                unless value?
                    res.status 400
                        .send "Missing parameter: task_#{name}"
                    return
                params[name] = value
            # find the task instance
            task.instantiateIfNeeded params, (err, taskInstance, taskInstanceName) ->
                if err
                    res.status 500
                        .send "Error loading task #{taskInstanceName}"
                    return
                next taskInstance, taskInstanceName
        else
            next task, taskName
app.get "/api/mindtagger/:task/schema", (req, res) ->
    withTask (req.param "task"), req, res, (task) ->
        task.getSchema (err, schema) ->
            if err
                return res.status 500
                    .send "Internal error: #{err}"
            res.json
                schema:  schema
app.get "/api/mindtagger/:task/items", (req, res) ->
    parseNum = (x) ->
        return null unless x?
        x = +x; if _.isNaN x then null else x
    offset = parseNum (req.param "offset") ? 0
    limit  = parseNum (req.param "limit" ) ? 10
    withTask (req.param "task"), req, res, (task) ->
        task.getItemsWithTags (err, {items, itemsCount, tags}) ->
            if err
                return res.status 500
                    .send "Internal error: #{err}"
            res.json {
                itemsCount
                limit
                offset
                tags
                items
            }
        , offset, limit
app.post "/api/mindtagger/:task/items", (req, res) ->
    withTask (req.param "task"), req, res, (task) ->
        task.setTagsForItems req.body, (err) ->
            if err
                return res.status 400
                    .send "Bad request: #{err}"
            res.json task.schema

# set up APIs for exporting
app.get ///^ /api/mindtagger/([^/]+)/tags\.(.*) $///, (req, res) ->
    [taskName, format] = req.params
    attrsToInclude = req.param("attrs")?.split(/\s*,\s*/)
    tagsToInclude = req.param("tags")?.split(/\s*,\s*/)
    unless attrsToInclude?.length > 0
        return res.status 400
            .send "Bad request: no attrs specified"
    withTask (taskName), req, res, (task, taskName) ->
        task.getItemsWithTags (err, taggedItems) ->
            if err
                return res.status 500
                    .send "Internal error: #{err}"
            # resolve any name collisions by appending suffixes
            tagNames =
                if tagsToInclude?.length > 0 then tagsToInclude
                else MindbenderUtils.findAllKeys taggedItems.tags
            columnIndex = {}
            columnNames =
                for name,j in [attrsToInclude..., tagNames...]
                    if columnIndex[name]?
                        suffix = 1
                        suffix++ while columnIndex[name + suffix]?
                        name += suffix
                    columnIndex[name] = j
                    name
            # construct rows to export
            rows =
                for attrs,i in taggedItems.items
                    tags = taggedItems.tags[i]
                    row = {}; j = 0
                    row[columnNames[j++]] = attrs[name] for name in attrsToInclude
                    row[columnNames[j++]] = tags?[name] for name in tagNames
                    row
            # send some headers
            res.contentType "text/plain"
            res.set "Content-Disposition": "attachment; filename=tags_#{
                taskName} #{tagNames.join "-"} by #{attrsToInclude.join "-"} #{
                    new Date().toISOString()}.#{format}"
            switch format
                when "update.sql", "insert.sql"
                    tableName = req.param "table"
                    unless tableName?.length > 0  # use default if table name isn't specified
                        tableName = "tags_#{taskName}_#{tagNames.join "_"}"
                    sqlTableName = MindbenderUtils.escapeSqlName tableName
                    switch format
                        when "update.sql"
                            sqlTagColumnNames = (MindbenderUtils.escapeSqlName c for c in tagNames).join ", "
                            res.send (for row in rows
                                """
                                UPDATE #{sqlTableName} SET (#{sqlTagColumnNames}) = (#{
                                    (MindbenderUtils.asSqlLiteral row[c] for c in tagNames).join ", "
                                })\tWHERE #{(
                                    "#{MindbenderUtils.escapeSqlName c} = #{
                                        MindbenderUtils.asSqlLiteral row[c]}" for c in attrsToInclude
                                ).join "\tAND "};
                                """
                            ).join "\n"
                        when "insert.sql"
                            res.send """
                                DROP TABLE IF EXISTS #{sqlTableName};
                                CREATE TABLE #{sqlTableName}
                                ( #{("#{MindbenderUtils.escapeSqlName c} TEXT" for c in columnNames).join "\n, "}
                                );
                                INSERT INTO #{sqlTableName}
                                (#{((MindbenderUtils.escapeSqlName c for c in columnNames).join ", ")})
                                VALUES
                                #{(
                                    for row in rows
                                        "(#{(MindbenderUtils.asSqlLiteral row[c] for c in columnNames).join ", "})"
                                ).join ",\n"
                                };
                                """
                when "tsv"
                    res.send TSV.stringify (MindbenderUtils.serializeNulls rows)
                when "csv"
                    csv.stringify (MindbenderUtils.serializeNulls rows), {
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

