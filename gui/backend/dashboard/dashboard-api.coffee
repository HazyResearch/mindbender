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
exports.init = (app) ->

    ## Viewing Snapshots and Reports
    # TODO remove
    exampleSnapshots = """
        20150415-1
        20150415-2
        20150415-3
        20150416-1
        """.trim().split(/\s+/)

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
    # TODO fix the singular/plural issue of report-template[s]
    app.get "/api/report-templates/", (req, res) ->
        sendStdoutOf res, "dashboard-report-template", ["ls"]

    exampleSnapshotConfigs =
        default: [
                    {
                        reportTemplate: "corpus"
                    }
                    {
                        reportTemplate: "variable"
                        params:
                            variable: "gene.is_correct"
                    }
                    {
                        reportTemplate: "variable"
                        params:
                            variable: "phenotype.is_correct"
                    }
                    {
                        reportTemplate: "variable"
                        params:
                            variable: "genepheno.is_correct"
                    }
                ]
        featuresOnly: [
                    {
                        reportTemplate: "variable/feature"
                        params:
                            variable: "gene.is_correct"
                    }
                    {
                        reportTemplate: "variable/feature"
                        params:
                            variable: "phenotype.is_correct"
                    }
                    {
                        reportTemplate: "variable/feature"
                        params:
                            variable: "genepheno.is_correct"
                    }
                ]
        mentions: [
                    {
                        reportTemplate: "variable"
                        params:
                            variable: "gene.is_correct"
                    }
                    {
                        reportTemplate: "variable"
                        params:
                            variable: "phenotype.is_correct"
                    }
                ]
        relationships: [
                    {
                        reportTemplate: "variable"
                        params:
                            variable: "genepheno.is_correct"
                    }
                ]

    # List Snapshot Configurations
    app.get "/api/snapshot-config/", (req, res) ->
        sendStdoutOf res, "dashboard-snapshot-config", ["ls"]
        
    # Create a New Snapshot Configuration or Update an Existing One
    app.put "/api/snapshot-config/:configName", (req, res) ->
        configName = req.param "configName"
        return res.sendStatus 400 unless configName?.length > 0
        isValidInstantiation = (inst) ->
            inst.reportTemplate? and (not inst.params? or (_.size inst.params) > 0)
        return res.sendStatus 400 unless _.every req.body, isValidInstantiation
        # TODO correct implementation
        exampleSnapshotConfigs[configName] = req.body
        res
            .location "/api/snapshot-config/#{configName}"
            .sendStatus 201

    # Read Contents of a Snapshot Configuration
    app.get "/api/snapshot-config/:configName", (req, res) ->
        configName = req.param "configName"
        sendStdoutOf res, "dashboard-snapshot-config", ["get", configName]

    # Delete a Snapshot Configuration
    app.delete "/api/snapshot-config/:configName", (req, res) ->
        configName = req.param "configName"
        # TODO correct implementation
        return res.sendStatus 404 unless exampleSnapshotConfigs[configName]?
        delete exampleSnapshotConfigs[configName]
        res
            .sendStatus 204

    # Create a New Snapshot
    app.post "/api/snapshot", (req, res) ->
        configName = req.body.snapshotConfig
        # TODO correct implementation
        return res.sendStatus 404 unless exampleSnapshotConfigs[configName]?
        now = new Date
        snapshotId = "#{now.getYear() + 1900}#{now.getMonth()+1}#{now.getDate()}"
        suffix = 1
        suffix += 1 while "#{snapshotId}-#{suffix}" in exampleSnapshots
        snapshotId += "-#{suffix}"
        exampleSnapshots.push snapshotId
        res
            .location "/api/snapshot/#{snapshotId}"
            .sendStatus 201


    ## Authoring Report Templates
    # Create a New Report Template or Update an Existing One
    app.put "/api/report-template/*", (req, res) ->
        [reportTemplateId] = req.params
        sendStdoutOf res, "dashboard-report-template", ["put", reportTemplateId]
            # XXX it's silly to parse and stringify the body right away
            .stdin.write JSON.stringify req.body

    # Read a Report Template
    app.get "/api/report-template/*", (req, res) ->
        [reportTemplateId] = req.params
        sendStdoutOf res, "dashboard-report-template", ["get", reportTemplateId]

    # Delete a Report Template
    app.delete "/api/report-template/*", (req, res) ->
        [reportTemplateId] = req.params
        sendStdoutOf res, "dashboard-report-template", ["delete", reportTemplateId]

    ## Running Tasks
    # TODO

    ## Authoring Task Templates
    # TODO

