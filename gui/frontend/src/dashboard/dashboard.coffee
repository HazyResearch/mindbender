angular.module "mindbenderApp.dashboard", [
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

    $routeProvider.when "/snapshot/:snapshotId",
        templateUrl: "dashboard/snapshot-view-reports.html"
        controller: "SnapshotReportsCtrl"

    $routeProvider.when "/report-templates/edit",
        templateUrl: "dashboard/report-templates-editor.html"
        controller: "EditTemplatesCtrl"


.controller "IndexCtrl", ($scope) ->
    $scope.hideNav = true

.controller "SnapshotRunCtrl", ($scope, $http) ->
    $scope.title = "Snapshot Run"

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
        if $scope.configs
            $scope.configTemplates = $scope.configs[newValue]

    $scope.addConfig = () ->
        $http.put("/api/snapshot-config/" + $scope.newSnapshotName, "[]")
        $scope.loadConfigs($scope.newSnapshotName)
        $scope.newSnapshotName = ""

    $scope.addTemplate = () ->
        # Need Template API functionality
        $scope.configTemplates.push({"reportTemplate":"", "params": {}})
    
    $scope.updateConfig = () ->
        $http.put("/api/snapshot-config/" + $scope.currentSnapshotConfig, $scope.configTemplates)
    
    $scope.deleteConfig = () ->
        $http.delete("/api/snapshot-config/" + $scope.currentSnapshotConfig)
        delete $scope.configs[$scope.currentSnapshotConfig]
        $scope.currentSnapshotConfig = ""

.controller "SnapshotListCtrl", ($scope, $http) ->
    $scope.title = "View Snapshots"

    $http.get "/api/snapshot"
        .success (data, status, headers, config) -> 
            $scope.snapshots = data


.controller "SnapshotReportsCtrl", ($scope, $http, $routeParams) ->
    $scope.title = "Snapshot " + $routeParams.snapshotId
    $scope.loading = true

    $scope.loadReport = (report_key) ->
        $scope.loading = true
        $http.get "/api/snapshot/" + $routeParams.snapshotId + "/" + report_key
            .success (data, status, headers, config) -> 
                $scope.currentReport = report_key
                table = $scope.convertToRowOrder(data[report_key].table['num_candidates_per_feature'])
                $scope.tableHeaders = table.headers
                $scope.tableRows = table.data
                $scope.json = {"graph": 1, "x": "num_candidates", "y":"num_features", "data": table.data}
                renderCharts($scope.json)
                $scope.loading = false

    $http.get "/api/snapshot/" + $routeParams.snapshotId
        .success (data, status, headers, config) -> 
            $scope.reports = data
            $scope.sortReports(Object.keys(data))

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
        console.log($scope.nav)


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


.controller "EditTemplatesCtrl", ($scope, $http) ->
    $scope.title = "Configure Templates"
    $scope.variableFields = ['name', 'required', 'default', 'description']

    $http.get "/api/report-templates/"
        .success (data, status, headers, config) -> 
            $scope.templateList = data

    $scope.$watch "currentTemplateName", (newValue, oldValue) ->
        if newValue
            $http.get "/api/report-templates/" + newValue
                .success (data, status, headers, config) -> 
                    $scope.template = data

.filter 'capitalize', () ->
    (input) ->
        input[0].toUpperCase() + input.substring(1)


