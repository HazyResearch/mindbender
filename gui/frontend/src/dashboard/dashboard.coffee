angular.module "mindbenderApp.dashboard", [
]

.config ($routeProvider) ->
    $routeProvider.when "/dashboard/",
        templateUrl: "dashboard/index.html"

    $routeProvider.when "/snapshot-run",
        templateUrl: "dashboard/snapshot-run.html"

    $routeProvider.when "/snapshot/",
        templateUrl: "dashboard/snapshot-list.html"
        controller: "SnapshotListCtrl"

    $routeProvider.when "/snapshot/:snapshotId",
        templateUrl: "dashboard/snapshot-view-chart.html"

    $routeProvider.when "/report-templates/",
        templateUrl: "dashboard/report-templates-editor.html"
    $routeProvider.when "/report-templates/:templateName",
        templateUrl: "dashboard/report-templates-editor.html"

.controller "SnapshotListCtrl", ($scope, $http) ->
    # TODO use AJAX
    $scope.snapshots = [
        {name: "SNAPSHOT 1"}
        {name: "SNAPSHOT 2"}
        {name: "SNAPSHOT 3"}
        {name: "SNAPSHOT 4"}
    ]

    $scope.switchSnapshot = (snapshotName) ->
        $scope.currentSnapshot = snapshotName
