angular.module "mindbenderApp.dashboard", [
]

.config ($routeProvider) ->
    $routeProvider.when "/dashboard/",
        templateUrl: "dashboard/index.html"
    $routeProvider.when "/snapshot/",
        templateUrl: "dashboard/snapshot-run.html"
    $routeProvider.when "/snapshot/:snapshotId",
        templateUrl: "dashboard/snapshot-view.html"
    $routeProvider.when "/report-templates/",
        templateUrl: "dashboard/report-templates-editor.html"
    $routeProvider.when "/report-templates/:templateName",
        templateUrl: "dashboard/report-templates-editor.html"

