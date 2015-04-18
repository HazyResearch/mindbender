###
# Dashboard
#
# For the API documentation, See: https://docs.google.com/document/d/1sWYeDmDSWWkS35-4GuVX4qm8NaS7kpQtJdqgriRJ9RI/edit#
###

util = require "util"
_ = require "underscore"

# Install Dashboard API handlers to the given ExpressJS app
exports.init = (app) ->

    ## Viewing Snapshots and Reports
    exampleSnapshots = """
        20150415-1
        20150415-2
        20150415-3
        20150416-1
        """.trim().split(/\s+/)
    # List Snapshots
    app.get "/api/snapshot/", (req, res) ->
        # TODO correct implementation
        res.json exampleSnapshots

    # List Reports of a Snapshot
    app.get "/api/snapshot/:snapshotId", (req, res) ->
        snapshotId = req.param "snapshotId"
        # TODO correct implementation
        return res.status(404).end() unless snapshotId in exampleSnapshots
        res.json  """
        corpus/stats
        variable
        variable/quality
        variable/inference
        variable/supervision
        variable/feature
        variable/feature/histogram-candidates-per-feature
        variable/candidate
        variable-2
        variable-2/quality
        variable-2/inference
        variable-2/supervision
        variable-2/feature
        variable-2/feature/histogram-candidates-per-feature
        variable-2/candidate
        """.trim().split(/\s+/)

    # Get Contents of a Report of a Snapshot
    app.get "/api/snapshot/:snapshotId/*", (req, res) ->
        snapshotId = req.param "snapshotId"
        reportId = req.params[0]

        report =
            report: "#{snapshotId}/#{reportId}"

        # TODO correct implementation
        return res.status 404 unless snapshotId in exampleSnapshots
        if /histogram/.test reportId
            # data-table type report
            _.extend report,
                data: [{"num_candidates":1,"num_features":24340},{"num_candidates":2,"num_features":3110},{"num_candidates":3,"num_features":1213},{"num_candidates":4,"num_features":620},{"num_candidates":5,"num_features":414},{"num_candidates":6,"num_features":265},{"num_candidates":7,"num_features":213},{"num_candidates":8,"num_features":147},{"num_candidates":9,"num_features":110},{"num_candidates":10,"num_features":81},{"num_candidates":11,"num_features":75},{"num_candidates":12,"num_features":68},{"num_candidates":13,"num_features":59},{"num_candidates":14,"num_features":43},{"num_candidates":15,"num_features":44},{"num_candidates":16,"num_features":34},{"num_candidates":17,"num_features":23},{"num_candidates":18,"num_features":31},{"num_candidates":19,"num_features":19},{"num_candidates":20,"num_features":20},{"num_candidates":21,"num_features":23},{"num_candidates":22,"num_features":23},{"num_candidates":23,"num_features":12},{"num_candidates":24,"num_features":16},{"num_candidates":25,"num_features":15},{"num_candidates":26,"num_features":19},{"num_candidates":27,"num_features":8},{"num_candidates":28,"num_features":9},{"num_candidates":29,"num_features":7},{"num_candidates":30,"num_features":7},{"num_candidates":31,"num_features":11},{"num_candidates":32,"num_features":14},{"num_candidates":33,"num_features":6},{"num_candidates":34,"num_features":6},{"num_candidates":35,"num_features":8},{"num_candidates":36,"num_features":8},{"num_candidates":37,"num_features":8},{"num_candidates":38,"num_features":11},{"num_candidates":39,"num_features":9},{"num_candidates":40,"num_features":8},{"num_candidates":41,"num_features":14},{"num_candidates":42,"num_features":10},{"num_candidates":43,"num_features":7},{"num_candidates":44,"num_features":5},{"num_candidates":45,"num_features":6},{"num_candidates":46,"num_features":8},{"num_candidates":47,"num_features":9},{"num_candidates":48,"num_features":9},{"num_candidates":49,"num_features":5},{"num_candidates":50,"num_features":8},{"num_candidates":51,"num_features":5},{"num_candidates":52,"num_features":6},{"num_candidates":53,"num_features":3},{"num_candidates":54,"num_features":5},{"num_candidates":56,"num_features":4},{"num_candidates":57,"num_features":2},{"num_candidates":58,"num_features":1},{"num_candidates":59,"num_features":3},{"num_candidates":60,"num_features":2},{"num_candidates":61,"num_features":3},{"num_candidates":62,"num_features":4},{"num_candidates":63,"num_features":2},{"num_candidates":64,"num_features":4},{"num_candidates":65,"num_features":4},{"num_candidates":66,"num_features":1},{"num_candidates":67,"num_features":3},{"num_candidates":68,"num_features":2},{"num_candidates":69,"num_features":2},{"num_candidates":70,"num_features":5},{"num_candidates":71,"num_features":5},{"num_candidates":73,"num_features":7},{"num_candidates":74,"num_features":5},{"num_candidates":75,"num_features":4},{"num_candidates":76,"num_features":7},{"num_candidates":77,"num_features":1},{"num_candidates":78,"num_features":3},{"num_candidates":80,"num_features":2},{"num_candidates":81,"num_features":2},{"num_candidates":82,"num_features":2},{"num_candidates":83,"num_features":2},{"num_candidates":84,"num_features":2},{"num_candidates":85,"num_features":2},{"num_candidates":86,"num_features":1},{"num_candidates":87,"num_features":2},{"num_candidates":89,"num_features":3},{"num_candidates":90,"num_features":1},{"num_candidates":91,"num_features":1},{"num_candidates":95,"num_features":1},{"num_candidates":98,"num_features":3},{"num_candidates":99,"num_features":1},{"num_candidates":100,"num_features":3},{"num_candidates":102,"num_features":1},{"num_candidates":104,"num_features":1},{"num_candidates":106,"num_features":3},{"num_candidates":110,"num_features":1},{"num_candidates":112,"num_features":1},{"num_candidates":116,"num_features":1},{"num_candidates":120,"num_features":1},{"num_candidates":122,"num_features":1},{"num_candidates":124,"num_features":2},{"num_candidates":126,"num_features":2},{"num_candidates":127,"num_features":2},{"num_candidates":129,"num_features":1},{"num_candidates":131,"num_features":2},{"num_candidates":132,"num_features":1},{"num_candidates":134,"num_features":2},{"num_candidates":135,"num_features":2},{"num_candidates":137,"num_features":1},{"num_candidates":138,"num_features":2},{"num_candidates":139,"num_features":3},{"num_candidates":140,"num_features":3},{"num_candidates":142,"num_features":1},{"num_candidates":143,"num_features":2},{"num_candidates":144,"num_features":1},{"num_candidates":145,"num_features":1},{"num_candidates":147,"num_features":1},{"num_candidates":150,"num_features":2},{"num_candidates":152,"num_features":1},{"num_candidates":153,"num_features":1},{"num_candidates":154,"num_features":1},{"num_candidates":156,"num_features":1},{"num_candidates":158,"num_features":1},{"num_candidates":161,"num_features":1},{"num_candidates":163,"num_features":1},{"num_candidates":169,"num_features":1},{"num_candidates":171,"num_features":1},{"num_candidates":177,"num_features":1},{"num_candidates":179,"num_features":2},{"num_candidates":180,"num_features":2},{"num_candidates":185,"num_features":1},{"num_candidates":187,"num_features":1},{"num_candidates":195,"num_features":1},{"num_candidates":196,"num_features":1},{"num_candidates":198,"num_features":1},{"num_candidates":199,"num_features":1},{"num_candidates":200,"num_features":1},{"num_candidates":206,"num_features":1},{"num_candidates":209,"num_features":2},{"num_candidates":211,"num_features":1},{"num_candidates":212,"num_features":1},{"num_candidates":216,"num_features":1},{"num_candidates":217,"num_features":1},{"num_candidates":219,"num_features":1},{"num_candidates":225,"num_features":1},{"num_candidates":227,"num_features":1},{"num_candidates":230,"num_features":1},{"num_candidates":231,"num_features":1},{"num_candidates":236,"num_features":1},{"num_candidates":242,"num_features":1},{"num_candidates":247,"num_features":1},{"num_candidates":264,"num_features":1},{"num_candidates":268,"num_features":1},{"num_candidates":281,"num_features":1},{"num_candidates":282,"num_features":1},{"num_candidates":286,"num_features":1},{"num_candidates":292,"num_features":2},{"num_candidates":298,"num_features":1},{"num_candidates":300,"num_features":1},{"num_candidates":302,"num_features":1},{"num_candidates":304,"num_features":1},{"num_candidates":322,"num_features":2},{"num_candidates":325,"num_features":2},{"num_candidates":326,"num_features":1},{"num_candidates":336,"num_features":1},{"num_candidates":353,"num_features":1},{"num_candidates":360,"num_features":1},{"num_candidates":374,"num_features":1},{"num_candidates":401,"num_features":1},{"num_candidates":414,"num_features":2},{"num_candidates":415,"num_features":1},{"num_candidates":417,"num_features":2},{"num_candidates":418,"num_features":1},{"num_candidates":429,"num_features":1},{"num_candidates":461,"num_features":1},{"num_candidates":462,"num_features":2},{"num_candidates":485,"num_features":1},{"num_candidates":502,"num_features":1},{"num_candidates":565,"num_features":1},{"num_candidates":609,"num_features":1},{"num_candidates":637,"num_features":1},{"num_candidates":649,"num_features":1},{"num_candidates":817,"num_features":1},{"num_candidates":964,"num_features":1},{"num_candidates":1059,"num_features":1},{"num_candidates":1096,"num_features":1},{"num_candidates":1220,"num_features":1},{"num_candidates":1373,"num_features":1},{"num_candidates":1574,"num_features":1},{"num_candidates":1699,"num_features":1},{"num_candidates":1837,"num_features":1},{"num_candidates":1894,"num_features":1},{"num_candidates":3183,"num_features":1},{"num_candidates":4721,"num_features":1}]
                chart: ["num_candidates", "num_features"]
        else
            # free-form type report
            _.extend report,
                html: """
                <ul>
                    <li>1234 documents</li>
                    <li>56789 sentences</li>
                </ul>
                """
        res.json report


    ## Creating New Snapshots
    # List Report Templates
    app.get "/api/report-templates/", (req, res) ->
        # TODO correct implementation
        res.json  """
        corpus/stats
        variable
        variable/quality
        variable/inference
        variable/supervision
        variable/feature
        variable/feature/histogram-candidates-per-feature
        variable/candidate
        """.trim().split(/\s+/)

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
        # TODO correct implementation
        res.json exampleSnapshotConfigs
        
    # Create a New Snapshot Configuration or Update an Existing One
    app.put "/api/snapshot-config/:configName", (req, res) ->
        configName = req.param "configName"
        return res.status(400).end() unless configName?.length > 0
        isValidInstantiation = (inst) ->
            inst.reportTemplate? and (not inst.params? or (_.size inst.params) > 0)
        return res.status(400).end() unless _.every req.body, isValidInstantiation
        # TODO correct implementation
        exampleSnapshotConfigs[configName] = req.body
        res
            .status 201
            .location "/api/snapshot-config/#{configName}"
            .end()

    # Read Contents of a Snapshot Configuration
    app.get "/api/snapshot-config/:configName", (req, res) ->
        configName = req.param "configName"
        # TODO correct implementation
        return res.status(404).end() unless exampleSnapshotConfigs[configName]?
        res.json exampleSnapshotConfigs[configName]

    # Delete a Snapshot Configuration
    app.delete "/api/snapshot-config/:configName", (req, res) ->
        configName = req.param "configName"
        # TODO correct implementation
        return res.status(404).end() unless exampleSnapshotConfigs[configName]?
        delete exampleSnapshotConfigs[configName]
        res
            .status 204
            .end()

    # Create a New Snapshot
    app.post "/api/snapshot", (req, res) ->
        configName = req.body.snapshotConfig
        # TODO correct implementation
        return res.status(404).end() unless exampleSnapshotConfigs[configName]?
        now = new Date
        snapshotId = "#{now.getYear() + 1900}#{now.getMonth()+1}#{now.getDate()}"
        suffix = 1
        suffix += 1 while "#{snapshotId}-#{suffix}" in exampleSnapshots
        snapshotId += "-#{suffix}"
        exampleSnapshots.push snapshotId
        res
            .status 201
            .location "/api/snapshot/#{snapshotId}"
            .end()


    # TODO
    ## Authoring Report Templates
    # Create a New Report Template or Update an Existing One
    # Read a Report Template
    # Delete a Report Template

    ## Running Tasks

    ## Authoring Task Templates

