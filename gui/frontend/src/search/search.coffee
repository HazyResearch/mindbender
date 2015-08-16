angular.module "mindbenderApp.search", [
    'elasticsearch'
    'json-tree'
    'ngSanitize'
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
        console.trace "elasticsearch cluster is down", err if err
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

.controller "SearchCtrl", ($scope, $location, $routeParams, deepdiveSearch, $modal) ->
    $scope.search = deepdiveSearch.init $scope, $routeParams.index, $location.search()

    $scope.$on "$routeUpdate", =>
        deepdiveSearch.doSearch yes if deepdiveSearch.importParams $location.search()

    $scope.$watch (-> deepdiveSearch.query), ->
        # reflect search parameters to the location on the URL
        search = $location.search()
        $location.search k, v for k, v of deepdiveSearch.params when search.k isnt v

    $scope.openModal = (options) ->
        $modal.open _.extend {
            scope: $scope
        }, options

.service "deepdiveSearch", (elasticsearch, $http, $rootScope) ->
    MULTIKEY_SEPARATOR = "@"
    class DeepDiveSearch
        constructor: (args...) ->
            @query = @results = @error = null
            @paramsDefault =
                q: null # query string
                t: null # type to search
                n: 10   # number of items in a page
                p: 1    # page number (starts from 1)
            @params = _.extend {}, @paramsDefault
            @types = null
            @indexes = null
            @init args... if args.length > 0

        init: (@$scope = $rootScope, @elasticsearchIndexName = "_all", params) =>
            @importParams params

            # watch page number changes
            @$scope.$watch (=> @params.p), => @doSearch yes

            # load the search schema
            $http.get "/api/search/schema.json"
                .success (data) =>
                    @types = data
                    # TODO initial @doSearch should wait for both elasticsearch.indices.get and this
                    @doSearch yes
                .error (err) =>
                    console.trace err

            # find out what types are in the index
            elasticsearch.indices.get
                index: @elasticsearchIndexName
            .then (data) =>
                @indexes = data
                # refresh results since we now have more info
                @doSearch yes
            , (err) =>
                @indexes = null
                @error = err
                console.trace err.message

            # return itself
            @

        doSearch: (isContinuing = no) =>
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
            postProcessSearchResults = =>
                @query = query
                @queryRunning = null
                do @doFetchResultSources
            @queryRunning = query
            elasticsearch.search query
            .then (data) =>
                @error = null
                @results = data
                do postProcessSearchResults
            , (err) =>
                @error = err
                console.trace err.message
                @results = null
                do postProcessSearchResults

        doFetchResultSources: =>
            # TODO cache sources and invalidate upon ever non-continuing search?
            # find out what source docs we need fetch for current search results
            docs = []; hitsByDocsOrder = []
            for hit in @results.hits.hits when @types?[hit._type]?.source
                parentRef = @types[hit._type].source
                hitsByDocsOrder.push hit
                docs.push
                    _index: hit._index
                    _type: parentRef.type
                    _id: (hit._source[f] for f in parentRef.fields).join MULTIKEY_SEPARATOR
            return unless docs.length > 0
            # fetch sources
            elasticsearch.mget { body: { docs } }
            .then (data) =>
                # update the source (parent) for every hits
                for doc,i in data.docs
                    hitsByDocsOrder[i].parent = doc
            , (err) =>
                console.trace err.message

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

.directive "visualizedSearchResult", (deepdiveSearch) ->
    scope:
        visualizedSearchResult: "="
        result: "="
        resultType: "="
        source: "="
        sourceType: "="
    template: """<span ng-include="'search/template/' + resultType + '.html'"></span>"""
