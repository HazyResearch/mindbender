angular.module "mindbenderApp.dashboard", [
]

.run ($rootScope) ->
    $rootScope.navLinks = [
        { url: '/#/snapshot-run', name: 'Run Snapshot', img: 'run.png' }
        { url: '/#/report-templates/edit', name: 'Configure Templates', img: 'gear.png' }
        { url: '/#/snapshot', name: 'View Snapshots', img: 'report.png' }
        { url: '/#/dashboard', name: 'Task', img: 'task.png' }
    ]

.config ($routeProvider) ->
    $routeProvider.when "/dashboard/",
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
    $scope.title = "Snapshot " + $routeParams.snapshotId + ": Reports"
    
    $scope.loadReport = (r) ->
        $http.get "/api/snapshot/" + $routeParams.snapshotId + "/histogram/.test"
        .success (data, status, headers, config) -> 
            $scope.tableHeaders = ["num_candidates", "num_features"]
            $scope.tableRows = data.data
            $scope.json = {"graph": 1, "x": "num_candidates", "y":"num_features", "data": data.data}
            renderCharts($scope.json)

    $http.get "/api/snapshot/" + $routeParams.snapshotId
        .success (data, status, headers, config) -> 
            $scope.reports = data



.controller "EditTemplatesCtrl", ($scope, $http) ->
    $scope.title = "Configure Templates"
    $scope.variableFields = ['name', 'required', 'default', 'description']

    $scope.templateList = ["template1", "template2"]
    $scope.template = {
        name: "my template"
        formatted: true
        variables: [
            { name: "test", required: "a", default: "def", description: "Description" }
        ]
        chart: {show: true, x: "test x", y: "test y"}
    }

    $scope.$watch "currentTemplateName", (newValue, oldValue) ->
        if newValue
            $scope.template = {
                name: "my template 2"
                formatted: true
                variables: [
                    { name: "test", required: "a", default: "def", description: "Description" }
                ]
                chart: {show: true, x: "test x", y: "test y"}
            }

.filter 'capitalize', () ->
    (input) ->
        input[0].toUpperCase() + input.substring(1)


