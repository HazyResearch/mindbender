angular.module "mindbenderApp.dashboard", [
    "ui.ace"
]

.run ($rootScope, $location) ->
    $rootScope.navLinks = [
        { url: '#/snapshot-run', name: 'Run Snapshot', img: 'run.png' }
        { url: '#/report-templates/edit', name: 'Configure Templates', img: 'gear.png' }
        { url: '#/snapshot/', name: 'View Snapshots', img: 'report.png' }
        { url: '#/dashboard', name: 'Task', img: 'task.png' }
    ]
    $rootScope.location = $location

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


.controller "IndexCtrl", ($scope) ->
    $scope.hideNav = true

.controller "SnapshotRunCtrl", ($scope, $http) ->
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

.controller "SnapshotListCtrl", ($scope, $http) ->
    $scope.title = "View Snapshots"

    $http.get "/api/snapshot"
        .success (data, status, headers, config) -> 
            $scope.snapshots = data


.controller "SnapshotReportsCtrl", ($scope, $http, $routeParams, $location, $sce) ->
    $scope.title = "Snapshot " + $routeParams.snapshotId
    $scope.loading = false
    $scope.hideLoader = true

    $scope.loadReportFromNav = (nav) ->
        if nav.$show || nav.$leaf
            $scope.loadReport(nav.$report_key)
        else
            nav.$show = true

    $scope.loadReport = (report_key) ->
        $scope.loading = true
        $scope.table = false
        $location.search('report', report_key)

        $http.get "/api/snapshot/" + $routeParams.snapshotId + "/" + report_key
            .success (data, status, headers, config) -> 
                $scope.loading = true
                $scope.chart = false
                $scope.currentReport = report_key
                report = data[report_key]

                if report.data?
                    $scope.html = $sce.trustAsHtml("")
                    data_name = Object.keys(report.data)[0]
                    {table, chart} = report.data[data_name]
                    table = $scope.convertToRowOrder(table)
                    $scope.tableHeaders = table.headers
                    $scope.tableRows = table.data
                    if ($scope.chart = chart)?
                        $scope.json = {
                            x: chart.x
                            y: chart.y
                            data: table.data
                            headers: table.headers
                        }
                        renderCharts($scope.json)
                else
                    $scope.html = $sce.trustAsHtml(report.html ? report.markdown)
                
                $scope.loading = false

    $http.get "/api/snapshot/" + $routeParams.snapshotId
        .success (data, status, headers, config) -> 
            $scope.reports = data
            $scope.sortReports(Object.keys(data))

            $scope.$watch (-> $location.search()['report']), (newValue, oldValue) ->
                search_report = $location.search()['report']
                if search_report && !$scope.loading
                    $scope.loadReport(search_report)
                    search_report_split = $scope.convertReportKey(search_report)
                    traverse_nav = $scope.nav
                    for s in search_report_split
                        traverse_nav[s]['$show'] = true
                        traverse_nav = traverse_nav[s]


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


.controller "EditTemplatesCtrl", ($scope, $http, $location) ->
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
