angular.module "mindbenderApp.search", [
    'elasticsearch'
]

# elasticsearch client as an Angular service
.service "elasticsearch", (esFactory) ->
    BASEURL = location.href.substring(0, location.href.length - location.hash.length)
    esFactory {
        host: "#{BASEURL}api/elasticsearch"
    }

.config ($routeProvider) ->
    $routeProvider.when "/search",
        templateUrl: "search/search.html"
        controller: "SearchCtrl"

.controller "SearchCtrl", ($scope, $http, $routeParams, elasticsearch) ->
    class Navigator
        constructor: (@elasticsearchIndexName) ->
            @results = null
            # TODO find out what types are in the index

        doSearch: (query_string) =>
            elasticsearch.search index: @elasticsearchIndexName, body: {
                # elasticsearch Query DSL (See: https://www.elastic.co/guide/en/elasticsearch/client/javascript-api/current/quick-start.html#_elasticsearch_query_dsl)
                query:
                    query_string:
                        query: query_string
                # TODO support filters
                # TODO support aggs
            }
            .then (data) =>
                @results = data

    $scope.search = new Navigator $routeParams.index

