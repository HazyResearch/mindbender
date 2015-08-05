angular.module "mindbenderApp.search", [
    'elasticsearch'
]

# elasticsearch client as an Angular service
.service "elasticsearch", (esFactory) ->
    BASEURL = location.href.substring(0, location.href.length - location.hash.length)
    elasticsearch = esFactory {
        host: "#{BASEURL}api/elasticsearch"
    }
    # do a ping
    elasticsearch.ping {
        requestTimeout: 30000
    }, (err) ->
        console.error "elasticsearch cluster is down" if err
    # return the instance
    elasticsearch

.config ($routeProvider) ->
    $routeProvider.when "/search/:index*?",
        brand: "DeepDive", brandIcon: "search"
        title: 'Search {{
                q ? "for [" + q + "] " : "everything "}}{{
                t ? "in " + t + " " : ""}}{{
                index ? "(" + index + ") " : ""
            }}- DeepDive'
        templateUrl: "search/search.html"
        controller: "SearchCtrl"
        reloadOnSearch: no
    $routeProvider.when "/search",
        redirectTo: "/search/"

.controller "SearchCtrl", ($scope, $location, $routeParams, elasticsearch) ->
    class Navigator
        constructor: (@elasticsearchIndexName = "_all", @params = {}) ->
            @query = @results = null
            @params.t ?= null # type to search
            @params.n ?= 10   # number of items in a page
            @params.p ?= 1    # page number (starts from 1)
            @doSearch yes if @params.q?

            # find out what types are in the index
            @types = null
            elasticsearch.indices.get
                index: @elasticsearchIndexName
            .then (data) =>
                @types = _.union (_.keys mappings for idx,{mappings} of data)...
            , (err) =>
                console.trace err.message

        doSearch: (isContinuing = no) =>
            @params.p = 1 unless isContinuing
            query =
                index: @elasticsearchIndexName
                type: @params.t
                body:
                    # elasticsearch Query DSL (See: https://www.elastic.co/guide/en/elasticsearch/client/javascript-api/current/quick-start.html#_elasticsearch_query_dsl)
                    size: @params.n
                    from: (@params.p - 1) * @params.n
                    query: if @params.q
                        query_string:
                            default_operator: "AND"
                            query: @params.q
                    # TODO support filters
                    # TODO support aggs
            elasticsearch.search query
            .then (data) =>
                @results = data
                @query = query
                # reflect search parameters to the location on the URL
                $location.search k, v for k, v of @params
            , (err) =>
                console.trace err.message

    $scope.search = new Navigator $routeParams.index, $location.search()

    # watch page number changes
    $scope.$watch "search.params.p", -> $scope.search.doSearch yes
