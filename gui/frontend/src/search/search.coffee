angular.module "mindbenderApp.search", [
    'elasticui'
    'ui.bootstrap'
]

.constant 'euiHost', 'http://localhost:9200' #'/api/elasticsearch'

.config ($routeProvider) ->
    $routeProvider.when "/search",
        templateUrl: "search/search.html"
        controller: "SearchCtrl"

.controller "SearchCtrl", ($scope) ->
    #$scope.indexVM = {}
