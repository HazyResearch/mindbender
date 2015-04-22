angular.module "mindbenderApp.dashboard", [
]

.config ($routeProvider) ->
    $routeProvider.when "/dashboard/",
        templateUrl: "dashboard/index.html"
        controller: "IndexCtrl"

    $routeProvider.when "/snapshot-run",
        templateUrl: "dashboard/snapshot-run.html"

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
    $scope.title = "DeepDive Dashboard"
    $scope.hideNav = true

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


