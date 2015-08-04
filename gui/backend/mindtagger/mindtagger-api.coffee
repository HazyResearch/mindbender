###
# Mindtagger
###

util = require "util"
express = require "express"
async = require "async"
_ = require "underscore"

{TSV,CSV} = require "tsv"
csv = require "csv"

{MindtaggerTask} = require "./mindtagger-task"
{MindbenderUtils} = require "../mindbender-utils"

## Configure Mindtagger API URLs to the given ExpressJS app
exports.configureRoutes = (app, args) ->
    # TODO use a more sophisticated command-line parser
    mindtaggerConfFiles = args

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
        group = req.param "group"
        offset = parseNum (req.param "offset") ? 0
        limit  = parseNum (req.param "limit" ) ? 10
        withTask (req.param "task"), req, res, (task) ->
            task.getItemsWithTags (err, {grouping, items, itemsCount, tags}) ->
                if err
                    return res.status 500
                        .send "Internal error: #{err}"
                res.json {
                    grouping
                    itemsCount
                    limit
                    offset
                    tags
                    items
                }
            , group, offset, limit
    app.post "/api/mindtagger/:task/items", (req, res) ->
        withTask (req.param "task"), req, res, (task) ->
            task.setTagsForItems req.body, (err) ->
                if err
                    return res.status 400
                        .send "Bad request: #{err}"
                res.json task.schema

    # filter item groups (for typeahead/autocompletion)
    app.get "/api/mindtagger/:task/groups", (req, res) ->
        q = req.param "q"
        if q?.length >= 2
            withTask (req.param "task"), req, res, (task) ->
                task.getAllItemsAndTags (err, {allItems}) ->
                    if err
                        return res.status 500
                            .send "Internal error: #{err}"
                    groupedItems = task.groupItems allItems
                    allGroups = _.keys groupedItems
                    res.json (g for g in allGroups when ~g.indexOf q)
        else
            res.status 400
                .send "Bad request: parameter 'q' is too short"


    # set up APIs for exporting
    app.get ///^ /api/mindtagger/([^/]+)/tags\.(.*) $///, (req, res) ->
        [taskName, format] = req.params
        attrsToInclude = req.param("attrs")?.split(/\s*,\s*/)
        tagsToInclude = req.param("tags")?.split(/\s*,\s*/)
        unless attrsToInclude?.length > 0
            return res.status 400
                .send "Bad request: no attrs specified"
        withTask (taskName), req, res, (task, taskName) ->
            # TODO use getAllItemsAndTags and do the join here
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
