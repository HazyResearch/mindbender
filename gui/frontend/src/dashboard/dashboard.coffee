angular.module "mindbenderApp.dashboard", [
    "ui.ace"
    'ui.bootstrap'
]

.service "Dashboard", ($rootScope, $location, $http) ->
    NUM_MOST_RECENT_SNAPSHOTS_TO_SHOW = 10

    class Dashboard
        constructor: ->
            console.log "Dashboard initializing"

            # prepare array of links for navbar
            $rootScope.navLinks = [
                { url: '#/snapshot-run', name: 'Run Snapshot', img: 'run.png' }
                { url: '#/report-templates/edit', name: 'Configure Templates', img: 'gear.png' }
                { url: '#/snapshot/', name: 'View Snapshots', img: 'report.png' }
                { url: '#/dashboard', name: 'Task', img: 'task.png' }
            ]
            do @updateNavLinkForSnapshots
            $rootScope.isNavLinkActive = (navLink) ->
                matchesLocation = ({url}) -> url is "##{$location.$$url}"
                (matchesLocation navLink) or
                    not (_.isEmpty navLink.links) and
                        (_.any navLink.links, matchesLocation)
            $rootScope.location = $location

        updateNavLinkForSnapshots: (snapshotParams) =>
            # query string to append
            qs =
                if _.isEmpty snapshotParams then ""
                else "?#{"#{encodeURIComponent k}=#{encodeURIComponent v}" for k,v of snapshotParams}"
            # how to populate snapshot links for navbar
            updateLinks = =>
                navLinkForSnapshots = _.find $rootScope.navLinks, name: "View Snapshots"
                navLinkForSnapshots.links =
                    for snapshotId in $rootScope.mostRecentSnapshots
                        # TODO use different style to indicate whether snapshotParams is applicable to this snapshot or not
                        { url: "#/snapshot/#{snapshotId}/#{qs}", name: snapshotId }
                if $rootScope.mostRecentSnapshots > NUM_MOST_RECENT_SNAPSHOTS_TO_SHOW
                    navLinkForSnapshots.links = [
                        navLinkForSnapshots.links...
                        { isDivider: yes }
                        { url: navLinkForSnapshots.url, name: "View All" }
                    ]
            # after getting the snapshots from backend
            if $rootScope.mostRecentSnapshots?
                do updateLinks
            else
                $rootScope.mostRecentSnapshots = []
                @getSnapshotList()
                    .success (snapshots) =>
                        $rootScope.mostRecentSnapshots = _.first (snapshots.reverse()), NUM_MOST_RECENT_SNAPSHOTS_TO_SHOW
                        do updateLinks

        getSnapshotList: =>
            $http.get "/api/snapshot"

        # TODO move some common parts to the Dashboard class

    # the singleton instance registered as an Angular service
    new Dashboard

.config ($routeProvider) ->
    $routeProvider.when "/dashboard",
        templateUrl: "dashboard/index.html"
        controller: "IndexCtrl"

    $routeProvider.when "/snapshot-run",
        templateUrl: "dashboard/snapshot-run.html"
        controller: "SnapshotRunCtrl"

    $routeProvider.when "/snapshot/",
        templateUrl: "dashboard/snapshot-list.html"
        controller: "SnapshotListCtrl"

    $routeProvider.when "/snapshot/:snapshotId/",
        templateUrl: "dashboard/snapshot-view-reports.html"
        controller: "SnapshotReportsCtrl",
        reloadOnSearch: false

    $routeProvider.when "/report-templates/edit",
        templateUrl: "dashboard/report-templates-editor.html"
        controller: "EditTemplatesCtrl",
        reloadOnSearch: false

.controller "IndexCtrl", ($scope, Dashboard) ->
    $scope.hideNav = true

.controller "SnapshotRunCtrl", ($scope, $http, Dashboard) ->
    $scope.title = "Run Snapshot"

    $scope.loadConfigs = (switchToConfig) ->
        $http.get "/api/snapshot-config/"
            .success (data, status, headers, config) -> 
                $scope.configs = data
                if switchToConfig
                    $scope.currentSnapshotConfig = switchToConfig

    $scope.loadConfigs()

    $http.get "/api/report-templates/"
        .success (data, status, headers, config) -> 
            $scope.templates = data 

    $scope.$watch "currentSnapshotConfig", (newValue, oldValue) ->
        if newValue
            $http.get "/api/snapshot-config/" + newValue
                .success (data, status, headers, config) -> 
                    $scope.configTemplates = data

    $scope.addTemplate = () ->
        $scope.configTemplates.push({"reportTemplate":"", "params": {}})

    $scope.updateParams = (configTemplate) ->
        $http.get "/api/report-template/" + configTemplate.reportTemplate
            .success (data, status, headers, config) -> 
                for param in Object.keys(data.params)
                    data.params[param] = data.params[param]['defaultValue']

                configTemplate.params = data.params

    $scope.updateConfig = () ->
        $http.put("/api/snapshot-config/" + $scope.currentSnapshotConfig, $scope.configTemplates)
    
    $scope.deleteConfig = () ->
        $http.delete("/api/snapshot-config/" + $scope.currentSnapshotConfig)
        delete $scope.configs[$scope.currentSnapshotConfig]
        $scope.currentSnapshotConfig = ""

    $scope.copyConfig = () ->
        $http.put("/api/snapshot-config/" + $scope.copySnapshotName, $scope.configTemplates)
            .success (data, status, headers, config) ->
                $scope.loadConfigs($scope.copySnapshotName)

    $scope.createConfig = () ->
        $http.put("/api/snapshot-config/" + $scope.newSnapshotName, "[]")
        $scope.loadConfigs($scope.newSnapshotName)
        $scope.newSnapshotName = ""

    $scope.runConfig = () ->
        $http.post("/api/snapshot", { snapshotConfig: $scope.currentSnapshotConfig })

.controller "SnapshotListCtrl", ($scope, $http, Dashboard) ->
    $scope.title = "View Snapshots"

    $http.get "/api/snapshot"
        .success (data, status, headers, config) -> 
            $scope.snapshots = data


.controller "SnapshotReportsCtrl", ($scope, $http, $routeParams, $location, $sce, Dashboard) ->
    $scope.title = "Snapshot " + $routeParams.snapshotId
    $scope.loading = false
    $scope.hideLoader = true

    $scope.loadReportFromNav = (nav) ->
        if nav.$show || nav.$leaf
            $scope.loadReport(nav.$report_key)
        else
            nav.$show = true

    reportNotFound = (report_key) ->
        $scope.reportLoadError =
            "#{report_key} does not exist in snapshot #{$routeParams.snapshotId}"

    $scope.loadReport = (report_key) ->
        $scope.loading = true
        $scope.reportLoadError = null
        $scope.table = false
        $location.search('report', report_key)
        reportIdFull = "#{$routeParams.snapshotId}/#{report_key}"

        # TODO check report_key from $scope.reports first

        $http.get "/api/snapshot/#{reportIdFull}"
            .success (data, status, headers, config) -> 
                $scope.loading = false
                $scope.chart = false
                $scope.currentReport = report_key
                report = data[report_key]
                return reportNotFound report_key unless report?
                if report.data?
                    # data-table (formatted) report
                    $scope.html = $sce.trustAsHtml("")
                    data_name = Object.keys(report.data)[0]
                    {table, chart} = report.data[data_name]
                    table = $scope.convertToRowOrder(table)
                    $scope.tableHeaders = table.headers
                    $scope.tableRows = table.data
                    if ($scope.chart = chart)?
                        # with chart
                        $scope.json = {
                            x: chart.x
                            y: chart.y
                            data: table.data
                            headers: table.headers
                        }
                        renderCharts($scope.json)
                else
                    # free-text (custom) report
                    $scope.html = $sce.trustAsHtml(report.html ? report.markdown)
                Dashboard.updateNavLinkForSnapshots $location.search()

            .error (data, status, headers, config) ->
                $scope.loading = false
                $scope.currentReport = report_key
                $scope.reportLoadError = status
                console.error "#{reportIdFull}: #{status} error while loading"

    $http.get "/api/snapshot/" + $routeParams.snapshotId
        .success (data, status, headers, config) -> 
            $scope.reports = data
            $scope.sortReports(Object.keys(data))

            $scope.$watch (-> $location.search()['report']), (newValue, oldValue) ->
                return if $scope.loading
                search_report = $location.search().report
                return unless search_report?
                if $scope.reports[search_report]?
                    $scope.loadReport(search_report)
                    search_report_split = $scope.convertReportKey(search_report)
                    traverse_nav = $scope.nav
                    for s in search_report_split
                        traverse_nav[s]['$show'] = true
                        traverse_nav = traverse_nav[s]
                else
                    reportNotFound search_report


    $scope.buildTree = (params, path_splits) ->
        result = {}

        for full_split in path_splits
            split = full_split[0]
            i = 0
            on_path = true
            for k in params
                if split[i] != k
                    on_path = false
                i += 1

            if on_path && split.length > i
                new_params = params.slice()
                new_params.push(split[i])
                children = $scope.buildTree(new_params, path_splits)
                result[split[i]] = children

                if Object.keys(children).length == 0
                    result[split[i]]['$leaf'] = true 

                tmp = full_split[1].split(" ")

                result[split[i]]['$report_key'] = tmp[0].split("/").slice(0, new_params.length).join("/") + " " + tmp[1]
                if i == 0
                    result[split[i]]['$show'] = true

        return result

    $scope.convertReportKey = (report_key) ->
        var_split = report_key.split(" ")
        path_split = var_split[0].split("/")
        path_split[0] += " (" + var_split[1] + ")"
        return path_split

    $scope.sortReports = (report_keys) ->
        path_splits = []
        
        for k in report_keys 
            path_splits.push([$scope.convertReportKey(k), k])

        $scope.nav = $scope.buildTree([], path_splits)

    $scope.convertToRowOrder = (table) ->
        if table.headers
            return table
        else
            new_table = { headers: Object.keys(table), data: [] }
            for header in new_table.headers
                for k, v of table[header]
                    if !new_table.data[k]
                        new_table.data[k] = []

                    new_table.data[k].push(v)

            return new_table


.controller "EditTemplatesCtrl", ($scope, $http, $location, Dashboard) ->
    $scope.title = "Configure Templates"

    $scope.loadTemplates = (switchToTemplate) ->
        $http.get "/api/report-templates/"
            .success (data, status, headers, config) -> 
                $scope.templateList = data

                if switchToTemplate
                    $scope.currentTemplateName = switchToTemplate

                $scope.$watch (-> $location.search()['template']), (newValue) ->   
                    if newValue
                        $scope.currentTemplateName = newValue
                        $http.get "/api/report-template/" + $scope.currentTemplateName
                            .success (data, status, headers, config) -> 
                                $scope.template = $.extend({}, data);
                                $scope.template.params = []
                                for param in Object.keys(data.params)
                                    $scope.template.params.push($.extend({ name: param }, data.params[param]))

                                if data.markdownTemplate
                                    $scope.formatted = false
                                else
                                    $scope.formatted = true

                                if data.chart
                                    $scope.template.hasChart = true
                                else
                                    $scope.template.hasChart = false

    $scope.loadTemplates()

    $scope.changeCurrentTemplate = () ->
        $location.search('template', $scope.currentTemplateName)

    $scope.addVariable = () ->
        $scope.template.params.push({})

    $scope.formatTemplateForUpdate = () ->
        params = {}
        
        for param in $scope.template.params
            params[param.name] = $.extend({}, param);
            delete params[param.name]['name']

        template = { params: params }
        if $scope.formatted
            template.sqlTemplate = $scope.template.sqlTemplate
        else
            template.markdownTemplate = $scope.template.markdownTemplate

        if $scope.template.hasChart
            template.chart = $scope.template.chart

        return template

    $scope.updateTemplate = () ->
        $scope.updateTemplateName($scope.currentTemplateName)

    $scope.updateTemplateName = (name, callback) ->
        template = $scope.formatTemplateForUpdate()
        $http.put("/api/report-template/" + name, template)
            .success (data, status, headers, config) ->
                if callback 
                    callback()

    $scope.deleteTemplate = () ->
        $http.delete("/api/report-template/" + $scope.currentTemplateName)

    $scope.copyTemplate = () ->
        $scope.updateTemplateName($scope.template.copyTemplateName, -> 
            $scope.loadTemplates($scope.template.copyTemplateName)
        )

.filter 'capitalize', () ->
    (input) ->
        input[0].toUpperCase() + input.substring(1)


.directive 'flash', ['$document', ($document) ->
    return {
        link: (scope, element, attr) ->
            element.on("click", (event) ->
                $('.flash').css('background-color', attr['flash'])
                setTimeout(() ->
                    $('.flash').css('background-color', '#FFF')
                , 1000)
            )
    }
]
