angular.module "mindbenderApp.search", [
    'elasticsearch'
    'json-tree'
    'ngSanitize'
]

.config ($routeProvider) ->
    $routeProvider.when "/search/:index*?",
        brand: "DeepDive", brandIcon: "search"
        title: 'Search {{
                q ? "for [" + q + "] " : "everything "}}{{
                t ? "in " + t + " " : ""}}{{
                index ? "(" + index + ") " : ""
            }}- DeepDive'
        templateUrl: "search/search.html"
        controller: "SearchResultCtrl"
        reloadOnSearch: no
    $routeProvider.when "/view/:index/:type",
        brand: "DeepDive", brandIcon: "search"
        title: """{{type}}( {{id}} ) in {{index}} - DeepDive"""
        templateUrl: "search/view.html"
        controller: "SearchViewCtrl"
    $routeProvider.when "/search",
        redirectTo: "/search/"

## for searching extraction/source data
.controller "SearchResultCtrl", ($scope, $routeParams, DeepDiveSearch, $modal) ->
    $scope.search = DeepDiveSearch.init $routeParams.index
    $scope.openModal = (options) ->
        $modal.open _.extend {
            scope: $scope
        }, options

.directive "deepdiveSearchBar", ->
    scope:
        search: "=for"
    templateUrl: "search/searchbar.html"
    controller: ($scope, $routeParams, $location, DeepDiveSearch) ->
        $scope.search ?= DeepDiveSearch.init $routeParams.index
        if $location.path() is "/search/"
            # detect changes to URL
            do doSearchIfNeeded = ->
                DeepDiveSearch.doSearch yes if DeepDiveSearch.importParams $location.search()
            $scope.$on "$routeUpdate", doSearchIfNeeded
            # reflect search parameters to the location on the URL
            $scope.$watch (-> DeepDiveSearch.query), ->
                search = $location.search()
                $location.search k, v for k, v of DeepDiveSearch.params when search.k isnt v
        else
            # switch to /search/
            $scope.$watch (-> DeepDiveSearch.queryRunning), (newQuery, oldQuery) ->
                return unless oldQuery?  # don't mess $location upon load
                $location.search DeepDiveSearch.params
                $location.path "/search/"

## for viewing individual extraction/source data
.controller "SearchViewCtrl", ($scope, $routeParams, $location, DeepDiveSearch) ->
    $scope.search = DeepDiveSearch.init $routeParams.index
    _.extend $scope, $routeParams
    searchParams = $location.search()
    $scope.id = searchParams.id
    $scope.routing = searchParams.parent
    $scope.data =
        _index: $scope.index
        _type:  $scope.type
        _id:    $scope.id

.directive "deepdiveVisualizedData", (DeepDiveSearch) ->
    scope:
        data: "=deepdiveVisualizedData"
        searchResult: "="
        routing: "="
    template: """
        <span ng-include="'search/template/' + data._type + '.html'"></span>
        <span class="alert alert-danger" ng-if="error">{{error}}</span>
        """
    link: ($scope) ->
        showError = (err) ->
            msg = err?.message ? err
            console.error msg
            # TODO display this in template
            $scope.error = msg
        unless $scope.data._type? and ($scope.data._source? or $scope.data._id?)
            return showError "_type with _id or _type with _source must be given to deepdive-visualized-data"
        initScope = (data) ->
            DeepDiveSearch.fetchSourcesAsParents [data]
            .then ([data]) ->
                if data.parent?  # extraction
                    $scope.extractionDoc = data
                    $scope.extraction    = data._source
                    DeepDiveSearch.fetchSourcesAsParents $scope.data
                    .then ->
                        $scope.sourceDoc = data.parent
                        $scope.source    = data.parent._source
                    , showError
                else  # source
                    $scope.extractionDoc = null
                    $scope.extraction    = null
                    $scope.sourceDoc = data
                    $scope.source    = data._source
            , showError
        if $scope.data?._source?
            initScope $scope.data
        else
            DeepDiveSearch.fetchWithSource {
                    index: $scope.data._index
                    type: $scope.data._type
                    id: $scope.data._id
                    routing: $scope.routing
                }
            .then (data) ->
                _.extend $scope.data, data
                initScope data
            , showError


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
        console.error "elasticsearch cluster is down", err if err
    # return the instance
    elasticsearch

.service "DeepDiveSearch", (elasticsearch, $http, $q) ->
    MULTIKEY_SEPARATOR = "@"
    class DeepDiveSearch
        constructor: (@elasticsearchIndexName = "_all") ->
            @query = @results = @error = null
            @paramsDefault =
                q: null # query string
                t: null # type to search
                n: 10   # number of items in a page
                p: 1    # page number (starts from 1)
            @params = _.extend {}, @paramsDefault
            @types = null
            @indexes = null

            @initialized = $q.all [
                # load the search schema
                $http.get "/api/search/schema.json"
                    .success (data) =>
                        @types = data
                    .error (err) =>
                        console.error err.message
            ,
                # find out what types are in the index
                elasticsearch.indices.get
                    index: @elasticsearchIndexName
                .then (data) =>
                    @indexes = data
                , (err) =>
                    @indexes = null
                    @error = err
                    console.error err.message
            ]

        init: (@elasticsearchIndexName = "_all") =>
            @

        doSearch: (isContinuing = no) => @initialized.then =>
            @params.p = 1 unless isContinuing
            fieldsSearchable = @getFieldsFor "searchable", @params.t
            # forumate aggregations
            aggs = {}
            if @indexes?
                for navigable in @getFieldsFor ["navigable", "searchable"], @params.t
                    aggs[navigable] =
                        switch @getFieldType navigable
                            when "boolean"
                                terms:
                                    field: navigable
                            when "string"
                                significant_terms:
                                    field: navigable
                            when "long"
                                # TODO range? with automatic rnages
                                # TODO extended_stats?
                                stats:
                                    field: navigable
                            else # TODO any better default for unknown types?
                                terms:
                                    field: navigable
            @error = null
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
                    aggs: aggs
                    highlight:
                        tags_schema: "styled"
                        fields: _.object ([f,{}] for f in fieldsSearchable)
            @queryRunning = query
            elasticsearch.search query
            .then (data) =>
                @error = null
                @queryRunning = null
                @query = query
                @results = data
                @fetchSourcesAsParents @results.hits.hits
            , (err) =>
                @error = err
                console.error err.message
                @queryRunning = null

        fetchSourcesAsParents: (docs) => $q (resolve, reject) =>
            # TODO cache sources and invalidate upon ever non-continuing search?
            # find out what source docs we need fetch for current search results
            docRefs = []; docsByMgetOrder = []
            for doc in docs when @types?[doc._type]?.source and not doc.parent?
                parentRef = @types[doc._type].source
                docsByMgetOrder.push doc
                docRefs.push
                    _index: doc._index
                    _type: parentRef.type
                    _id: (doc._source[f] for f in parentRef.fields).join MULTIKEY_SEPARATOR
            return resolve docs unless docRefs.length > 0
            # fetch sources
            elasticsearch.mget { body: { docs: docRefs } }
            .then (data) =>
                # update the source (parent) for every extractions
                for sourceDoc,i in data.docs
                    docsByMgetOrder[i].parent = sourceDoc
                resolve docs
            , reject

        fetchWithSource: (docRef) => $q (resolve, reject) =>
            docRef.index ?= @elasticsearchIndexName
            # TODO lifted version of this with mget
            elasticsearch.get docRef
            .then (data) =>
                @fetchSourcesAsParents [data]
                .then => resolve data
                , reject
            , reject

        doNavigate: (field, value) =>
            qExtra =
                switch @getFieldType field
                    when "string"
                        # just add extra keyword to the search
                        value
                    else # use field-specific search for non-text types
                        if value?
                            "#{field}:#{value}"
                        else # filtering down null has a special query_string syntax
                            "_missing_:#{field}"
            # TODO check if qExtra is already there in @params.q
            @params.q =
                if @params.q?
                    "#{@params.q} #{qExtra}"
                else
                    qExtra
            @doSearch no

        getFieldsFor: (what, type = @params.t) =>
            if what instanceof Array
                # union if multiple purposes
                _.union (@getFieldsFor w, type for w in what)...
            else
                # get all fields for something for the type or all types
                if type?
                    @types?[type]?[what] ? []
                else
                    _.union (s[what] for t,s of @types)...

        getFieldType: (path) =>
            for idxName,{mappings} of @indexes ? {}
                for typeName,mapping of mappings
                    # traverse down the path
                    pathSoFar = ""
                    for field in path.split "."
                        if pathSoFar?
                            pathSoFar += ".#{field}"
                        else
                            pathSoFar = field
                        if mapping.properties?[field]?
                            mapping = mapping.properties[field]
                        else
                            #console.debug "#{pathSoFar} not defined in mappings for [#{idxName}]/[#{typeName}]"
                            mapping = null
                            break
                    continue unless mapping?.type?
                    return mapping.type
            console.error "#{path} not defined in any mappings"
            null

        countTotalDocCountOfBuckets: (aggs) ->
            return aggs._total_doc_count if aggs?._total_doc_count? # try to hit cache
            total = 0
            if aggs?.buckets?
                total += bucket.doc_count for bucket in aggs.buckets
                aggs._total_doc_count = total # cache sum
            total

        importParams: (params) =>
            changed = no
            for k,v of @params when (params[k] ? @paramsDefault[k]) isnt v
                @params[k] = params[k] ? @paramsDefault[k]
                changed = yes
            changed

    new DeepDiveSearch
