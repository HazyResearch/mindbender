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

.controller "SearchCtrl", ($scope, $location, $routeParams, elasticsearch, $http, $interpolate, $modal) ->
    RENDER_SOURCE_JSON = $interpolate "{{_source | json | limitTo:500}}"
    class Navigator
        constructor: (@elasticsearchIndexName = "_all", @$scope) ->
            @query = @results = null
            @paramsDefault =
                q: null # query string
                t: null # type to search
                n: 10   # number of items in a page
                p: 1    # page number (starts from 1)
            @params = _.extend {}, @paramsDefault
            do @importParams

            $http.get "/api/search/schema.json"
                .success (data) =>
                    @schema = data
                    # TODO initial @doSearch should wait for both elasticsearch.indices.get and this
                    @doSearch yes
                .error (err) ->
                    console.trace err

            # find out what types are in the index
            @types = null
            @indices = null
            elasticsearch.indices.get
                index: @elasticsearchIndexName
            .then (data) =>
                @indices = data
                @types = _.union (_.keys mappings for idx,{mappings} of @indices)...
                # refresh results since we now have more info
                @doSearch yes
            , (err) =>
                @indices = null
                @error = err
                console.trace err.message

            # watch page number changes
            @$scope.$watch (=> @params.p), => @doSearch yes
            @$scope.$on "$routeUpdate", =>
                @doSearch yes if do @importParams

        doSearch: (isContinuing = no) =>
            @params.p = 1 unless isContinuing
            fieldsSearchable = @getFieldsFor "searchable", @params.t
            # forumate aggregations
            aggs = {}
            if @indices?
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
            @queryRunning =
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
                @query = @queryRunning
                @queryRunning = null
                @fieldsSearchable = fieldsSearchable
                do @reflectParams
            elasticsearch.search @queryRunning
            .then (data) =>
                @error = null
                @results = data
                do postProcessSearchResults
            , (err) =>
                @error = err
                console.trace err.message
                @results = null
                do postProcessSearchResults

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
            # TODO check if qExtra is already there
            @params.q += " #{qExtra}"
            @doSearch no

        getFieldsFor: (what, type = @params.t) =>
            if what instanceof Array
                # union if multiple purposes
                _.union (@getFieldsFor w, type for w in what)...
            else
                # get all fields for something for the type or all types
                if type?
                    @schema?[type]?[what] ? []
                else
                    _.union (s[what] for t,s of @schema)...

        getFieldType: (path) =>
            for idxName,{mappings} of @indices ? {}
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

        importParams: =>
            search = $location.search()
            changed = no
            for k,v of @params when (search[k] ? @paramsDefault[k]) isnt v
                @params[k] = search[k] ? @paramsDefault[k]
                changed = yes
            changed

        reflectParams: =>
            # reflect search parameters to the location on the URL
            search = $location.search()
            $location.search k, v for k, v of @params when search.k isnt v

    $scope.search = new Navigator $routeParams.index, $scope

    $scope.openModal = (options) ->
        $modal.open _.extend {
            scope: $scope
        }, options

