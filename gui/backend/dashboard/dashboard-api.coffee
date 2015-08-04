###
# Dashboard
#
# For the API documentation, See: https://docs.google.com/document/d/1sWYeDmDSWWkS35-4GuVX4qm8NaS7kpQtJdqgriRJ9RI/edit#
###

util = require "util"
_ = require "underscore"
{spawn} = require "child_process"
byline = require "byline"

# shorthand for sending JSON array responses without buffering
noop = ->
sendJSONArray = (res, stream, next, mapper = String) ->
    res.type "json"
    first = yes
    stream.on "readable", ->
        while (item = stream.read())?
            res.write if first then first = no; "[" else ","
            res.write JSON.stringify mapper item
    stream.on "end", ->
        res.write "]" unless first
        next?()

# shorthand for sending standard output lines of a command as a JSON array
sendStdoutOf = (res, command, args, errorStatus = 404) ->
    res.type "json"
    proc = spawn command, args
    proc.on "exit", (code) -> try res.sendStatus errorStatus if code != 0
    proc.on "close", (code) -> res.end()
    proc.stdout.on "readable", ->
        while (data = proc.stdout.read())?
            res.write data
    proc
sendStdoutLinesAsJSONArray = (res, command, args, errorStatus = 404) ->
    proc = spawn command, args
    proc.on "exit", (code) -> try res.sendStatus errorStatus if code != 0
    proc.on "close", (code) -> res.end()
    sendJSONArray res, byline proc.stdout
    proc

# Install Dashboard API handlers to the given ExpressJS app
exports.configureRoutes = (app, args) ->

    ## Viewing Snapshots and Reports
    # List Snapshots
    app.get "/api/snapshot/", (req, res) ->
        sendStdoutLinesAsJSONArray res, "dashboard-ls-snapshots"

    # List Reports of a Snapshot
    app.get "/api/snapshot/:snapshotId", (req, res) ->
        snapshotId = req.param "snapshotId"
        sendStdoutOf res, "dashboard-ls-reports", [snapshotId, "json"]

    # Get Contents of a Report of a Snapshot
    app.get "/api/snapshot/:snapshotId/*", (req, res) ->
        snapshotId = req.param "snapshotId"
        [reportId] = req.params
        sendStdoutOf res, "dashboard-report-content", [snapshotId, reportId]


    ## Creating New Snapshots
    # List Report Templates
    app.get "/api/snapshot-template/", (req, res) ->
        if (req.param "type") is "task"
            sendStdoutOf res, "dashboard-report-template", ["ls-tasks"]
        else
            sendStdoutOf res, "dashboard-report-template", ["ls"]

    # List Snapshot Configurations
    app.get "/api/snapshot-config/", (req, res) ->
        sendStdoutOf res, "dashboard-snapshot-config", ["ls"]
        
    # Create a New Snapshot Configuration or Update an Existing One
    app.put "/api/snapshot-config/:configName", (req, res) ->
        configName = req.param "configName"
        return res.status(400).send "no configName" unless configName?.length > 0
        isValidInstantiation = (inst) ->
            inst.reportTemplate? and (not inst.params? or (typeof inst.params) is "object")
        return res.status(400).send "invalid instantiation" unless _.every req.body, isValidInstantiation
        res
            .location "/api/snapshot-config/#{configName}"
            .status 201
        sendStdoutOf res, "dashboard-snapshot-config", ["put", configName]
            .stdin.end JSON.stringify req.body

    # Read Contents of a Snapshot Configuration
    app.get "/api/snapshot-config/:configName", (req, res) ->
        configName = req.param "configName"
        sendStdoutOf res, "dashboard-snapshot-config", ["get", configName]

    # Delete a Snapshot Configuration
    app.delete "/api/snapshot-config/:configName", (req, res) ->
        configName = req.param "configName"
        res
            .status 204 # no content
        sendStdoutOf res, "dashboard-snapshot-config", ["delete", configName]

    # Create a New Snapshot
    app.post "/api/snapshot", (req, res) ->
        configName = req.body.snapshotConfig
        proc = spawn "mindbender-snapshot", [configName], detached: yes
        lineStream = byline proc.stdout
        lineStream
            .once "data", (line) ->
                snapshotId = line
                res
                    .location "/api/snapshot/#{snapshotId}"
                    .sendStatus 201
                proc.unref()  # detach
            .on "error", ->
                res
                    .sendStatus 500
    # Cancel a Running Snapshot
    app.delete "/api/snapshot/:snapshotId", (req, res) ->
        snapshotId = req.param "snapshotId"
        res
            .location "/api/snapshot/#{snapshotId}"
            .status 204 # no content
        sendStdoutOf res, "mindbender-cancel-snapshot", [snapshotId]


    ## Authoring Report Templates
    # Create a New Report Template or Update an Existing One
    app.put "/api/snapshot-template/*", (req, res) ->
        [reportTemplateId] = req.params
        res
            .location "/api/snapshot-template/#{reportTemplateId}"
            .status 201
        sendStdoutOf res, "dashboard-report-template", ["put", reportTemplateId]
            # XXX it's silly to parse and stringify the body right away
            .stdin.end JSON.stringify req.body

    # Read a Report Template
    app.get "/api/snapshot-template/*", (req, res) ->
        [reportTemplateId] = req.params
        sendStdoutOf res, "dashboard-report-template", ["get", reportTemplateId]

    # Delete a Report Template
    app.delete "/api/snapshot-template/*", (req, res) ->
        [reportTemplateId] = req.params
        res
            .status 204 # no content
        sendStdoutOf res, "dashboard-report-template", ["delete", reportTemplateId]

    ## Running Tasks
    app.post "/api/snapshot/LATEST/task/", (req, res) ->
        reportId = req.body.report
        taskName = req.body.taskTemplate
        params =
            "#{name}=#{value}" for name,value of req.body.params
        # run mindbender-report-task command
        proc = spawn "mindbender-report-task", [reportId, taskName, params...], detached: yes
        # read two lines from it containing snapshotId and reportId
        # XXX You're right. This is pretty ugly.
        lineNo = 0
        snapshotId = reportId = null
        exitStatus = null
        lineStream = byline proc.stdout
        lineStream
            .on "data", (line) ->
                switch ++lineNo
                    when 1
                        snapshotId = line
                    when 2
                        reportId = line
                        if not exitStatus? or exitStatus == 0
                            res.json {
                                    snapshot: String snapshotId
                                    report:   String reportId
                                }
                        proc.unref()  # detach
            .on "error", ->
                res.status 500
                    .send "Error while processing output of report-task"
        proc
            .on "close", (code) ->
                exitStatus = code
                unless exitStatus == 0
                    res.status 500
                        .send "report-task exited with status #{exitStatus}"

    ## Trends
    # Enumerate All Report Values
    app.get "/api/report-value/", (req, res) ->
        # TODO cache aggregate values
        # FIXME xargs will produce more than one JSON when there are too many snapshots
        sendStdoutOf res, "sh", ["-c", "dashboard-ls-snapshots | xargs dashboard-aggregate-values"]

    ## Dashboard Values
    # Enumerate Dashboard Values
    app.get "/api/dashboard/values/", (req, res) ->
        sendStdoutOf res, "dashboard-trends-config", ["get.json"]

    # Update Dashboard Values
    app.put "/api/dashboard/values/", (req, res) ->
        sendStdoutOf res, "dashboard-trends-config", ["put"]
            # XXX it's silly to parse and stringify the body right away
            .stdin.end JSON.stringify req.body

    # Add a Dashboard Value
    app.post "/api/dashboard/values/", (req, res) ->
        reportId = req.body.report
        valueName = req.body.value
        sendStdoutOf res, "dashboard-trends-config", ["add", reportId, valueName]



