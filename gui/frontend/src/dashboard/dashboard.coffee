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
        templateUrl: "dashboard/snapshot-view-chart.html"

    $routeProvider.when "/report-templates/edit",
        templateUrl: "dashboard/report-templates-editor.html"
        controller: "EditTemplatesCtrl"

.controller "IndexCtrl", ($scope) ->
    $scope.title = "DeepDive Dashboard"
    $scope.hideNav = true

.controller "SnapshotListCtrl", ($scope, $http) ->
    # TODO use AJAX
    $scope.snapshots = [
        {name: "SNAPSHOT 1"}
        {name: "SNAPSHOT 2"}
        {name: "SNAPSHOT 3"}
        {name: "SNAPSHOT 4"}
    ]
    #$http.get 'test.txt'
    #    .success (data, status, headers, config) -> 
    #        console.log(data)

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


