#

angular.module "mindbender.search.search", [
    'elasticsearch'
    'json-tree'
    'ngSanitize'
    'mindbender.auth'
    'ngHandsontable'
    'ui.bootstrap'
    'mindbender.search.queryparse'
    'mindbender.search.util'
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
        console.error "elasticsearch cluster is down", err if err
    # return the instance
    elasticsearch

.service "DeepDiveSearch", (elasticsearch, $http, $q, $timeout, $location, $uibModal, DossierService, QueryParseService) ->
    MULTIKEY_SEPARATOR = "@"
    class DeepDiveSearch
        constructor: (@elasticsearchIndexName = "_all") ->
            @query = @results = @error = null
            @paramsDefault =
                q: null # query string
                s: null # query string for source
                t: 'everything' # type to search
                n: 10   # number of items in a page
                p: 1    # page number (starts from 1)
                #ro: 'false'  # is it read-only
                advanced: 'false'
            @params = _.extend {}, @paramsDefault
            @types = null
            @indexes = null
            @elastic = elasticsearch
            @collapsed_facets = { 
                'domain': true
                'locations_raw': true
                'phones': true 
                'post_date': true
                'screening': true
                'ethnicity': true
                'emails': true
                'rates': true
                'names': true
                'service': true
                'ages':true
                'username':true
                'annotated_flags':true
                'images': true
                'locations': true
                'cities': true
                'states': true
                'countries': true
                'metropolitan_areas': true
                'embedded_websites': true
                'massage_places': true
                'massage_places_sites': true
                'homology': true
                'language': true
                'business_addresses': true
                'business_address_streets':true
            }
            @flag_infos = {
                'Foreign Providers': { 'ads':true }
                'Traveling': { 'ads':true }
                'Organized': { 'ads':true, 'reviews':true }
                'Risky Services': { 'ads':true }
                'Derogatory Descriptions': { 'ads':true }
                'Bad Experience': { 'reviews':true }
                'Porn / Cam Services': { 'ads':true }
                'LE Cautious': { 'reviews':true }
                'New to Biz': { 'reviews':true }
                'Fake Photo': { 'reviews':true }
                'Poor English': { 'reviews':true }
                'Juvenile': { 'reviews':true, 'ads':true }
                'Educated': { 'reviews':true }
                'Drug Use': { 'reviews':true }
                'Coercion': { 'reviews':true }
                'Physical Abuse': { 'reviews':true }
                'Theft / Robbery': { 'reviews':true }
                'Incompletion': { 'reviews':true }
                'Armed & Dangerous': { 'reviews':true }
                'Massage Parlor': { 'ads': true }
                'URL Embedding': { 'ads': true }
                'Hotel': { 'ads': true }
                'Agency': { 'ads': true }
                'Accepts Credit Cards': { 'ads': true }
                'Accepts Walk-ins': { 'ads': true }
                'Business Addresses': { 'ads': true }
                'Multiple Girls': { 'ads': true }
            }

            @dossier = DossierService
            @queryparse = QueryParseService
            #@read_only_query = false
            @suggestions = []

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

        toggleFacetCollpase: (field) =>
            if field of @collapsed_facets
                delete @collapsed_facets[field]
            else
                @collapsed_facets[field] = true

        doSearch: (isContinuing = no) => @initialized.then =>
            @params.p = 1 unless isContinuing
            fieldsSearchable = @getFieldsFor "searchable", @params.t
            @error = null
            # query_string query
            if (st = (@getSourceFor @params.t)?.type)?
                # extraction type
                sq = @params.s
                qs = @params.q
            else
                # source type
                sq = null
                qs = @params.s

            qs = qs || ''

            p1 = @queryparse.parse_query qs
            p1.then (pq) =>
                isSimple = @queryparse.isSimpleQuery(pq)
                if !isSimple && @params.advanced is 'false'
                    @params.advanced = 'true'
                if isSimple && window.visualSearch
                    window.visualSearch.searchBox.value(qs)
                    #window.visualSearch.searchBox.renderFacets()
                    #window.visualSearch.searchBox.setQuery(qs)

                #if window.visualSearch && @params.advanced isnt 'true'
                #    window.visualSearch.searchBox.value(qs)
                    
                q =
                    if qs?.length > 0
                        # Take care of quotations added by VisualSearch
                        qs_for_es = qs.replace(/["']\[/g, '[').replace(/\]["']/g, ']')
                        query_string:
                            default_field: "content"
                            default_operator: "AND"
                            query: qs_for_es
                # also search source when possible
                # TODO highlight what's found here?
                if st? and sq?.length > 0
                    q = bool:
                        should: [
                            q
                          , has_parent:
                                parent_type: st
                                query:
                                    query_string:
                                        default_field: "content"
                                        default_operator: "AND"
                                        query: sq
                        ]
                        minimum_should_match: 2
                # forumate aggregations
                aggs = {}
                if @indexes?
                    for navigable in @getFieldsFor ["navigable", "searchableXXXXXX"], @params.t
                        aggs[navigable] =
                            switch @getFieldType navigable
                                when "boolean"
                                    terms:
                                        field: navigable
                                when "stringXXXXXX"
                                    # significant_terms buckets are empty if query is empty;
                                    # terms buckets are not empty in that case.
                                    # we want to show facets even for initial page with empty query.
                                    if qs?.length > 0
                                        significant_terms:
                                            field: navigable
                                            min_doc_count: 1
                                    else
                                        terms:
                                            field: navigable
                                when "long"
                                    # TODO range? with automatic rnages
                                    # TODO extended_stats?
                                    stats:
                                        field: navigable
                                else # TODO any better default for unknown types?
                                    terms:
                                        field: navigable
                                        shard_size: 1000
                                        size: 
                                            switch navigable
                                                when "flags" || "annotated_flags"
                                                    100
                                                when "images"
                                                    10
                                                else
                                                    50
                        aggs[navigable + '__count'] =
                            value_count:
                                field: navigable
                query =
                    index: @elasticsearchIndexName
                    type: @params.t
                    body:
                        # elasticsearch Query DSL (See: https://www.elastic.co/guide/en/elasticsearch/client/javascript-api/current/quick-start.html#_elasticsearch_query_dsl)
                        size: @params.n
                        from: (@params.p - 1) * @params.n
                        query: q
                        # TODO support filters
                        aggs: aggs
                        highlight:
                            tags_schema: "styled"
                            fields: _.object ([f,{require_field_match: true}] for f in fieldsSearchable)
                @queryRunning = query
                @querystringRunning = qs
                shouldNormalize = q?
    
                #shouldNormalize = false
                normalized_query = @queryparse.normalize_query (if shouldNormalize then q.query_string.query else ''), @dossier.fetch_dossier_by_name
                normalized_query.then (nq) =>
                  nquery = jQuery.extend(true, {}, query)
                  if shouldNormalize
                    nquery.body.query.query_string.query = nq 
                  console.log 'normalized query: ' + nq
                  elasticsearch.search nquery
                  .then (data) =>
                    @error = null
                    @queryRunning = null
                    @querystringRunning = null
                    @query = query
                    @query._query_string = qs
                    @query._source_type = st
                    @query._source_query_string = sq
                    @results = data
                    @fetchSourcesAsParents @results.hits.hits
                    facets = []
                    best_facets = ['domain_type', 'flags', 'annotated_flags', 'massage_places', 'massage_places_sites', 'domain', 'phones', 'post_date', 'images', 'locations_raw', 'locations', 'cities', 'states', 'countries', 'metropolitan_areas', 'business_addresses', 'business_address_streets', 'embedded_websites', 'homology' ]
                    range_facets = ['ages', 'post_date', 'phones', 'ages']
                    date_facets = ['post_date']
                    for f in best_facets
                        if f of data.aggregations
                            facet = data.aggregations[f]
                            facet.field = f
                            facet.count = data.aggregations[f + '__count'].value
                            facet.is_range = (f in range_facets)
                            facet.is_date = (f in date_facets)
                            if f of @collapsed_facets
                                facet.collapsed = true
                            facets.push facet
                    for k, v of data.aggregations
                        if k not in best_facets and k + '__count' of data.aggregations
                            facet = data.aggregations[k]
                            facet.field = k
                            facet.count = data.aggregations[k + '__count'].value
                            facet.is_range = (k in range_facets)
                            facet.is_date = (k in date_facets)
                            if k of @collapsed_facets
                                facet.collapsed = true
                            facets.push facet
                    @results.facets = facets
    
                    # update DossierService
                    dossier_queries = [qs]
    
                    idx = query.body.from + 1
                    for hit in data.hits.hits
                        hit.idx = idx++
                        dossier_queries.push('doc_id:"' + hit._id + '"')
    
                    @dossier.fetch_dossiers dossier_queries
   
                  , (err) => #normalize query fails
                      @error = err
                      console.error err.message
                      @queryRunning = null
                , (err) => # query parse fails
                    @error = err
                    console.error err.message
                    @queryRunning = null
    
        fetchSourcesAsParents: (docs) => $q (resolve, reject) =>
            # TODO cache sources and invalidate upon ever non-continuing search?
            # find out what source docs we need fetch for current search results
            docRefs = []; docsByMgetOrder = []
            for doc in docs when (parentRef = @getSourceFor doc._type)? and not doc.parent?
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


        doNavigateMultiple: (event, field_value_pairs, newSearch = false) =>
            # if current query is read only, then always do a new search
            #if @params.ro == 'true'
            #    newSearch = true
            for field, value of field_value_pairs
                qsExtra =
                    if field and value
                        # use field-specific search for navigable fields
                        # VisualSearch may have added the quotes already
                        if value.indexOf("'") == 0 or value.indexOf('"') == 0
                            "#{field}:#{value}"
                        else
                            "#{field}:\"#{value}\""
                    else if value?
                        "#{value}"
                    else if field?
                        # filtering down null has a special query_string syntax
                        "_missing_:#{field}"
                    else
                        ""
                if qsExtras?
                   qsExtras = qsExtras + ' '
                else
                   qsExtras = ''
                qsExtras = qsExtras + qsExtra
            #qsExtra = qsExtra || ''
            qs = if (@getSourceFor @params.t)? then "q" else "s"
            params_qs =
                if newSearch or not @params[qs]    # replace query string
                    qsExtras
                else if qsExtras and @params[qs].indexOf(qsExtras) == -1
                    "#{@params[qs]} #{qsExtras}"   # concat query strings
                else
                    @params[qs]

            # open in new tab?
            if (event.shiftKey || event.ctrlKey || event.metaKey)
                # clone params object
                newParams = {}
                for k,v of @params
                    newParams[k] = v
                # update params
                newParams[qs] = params_qs
                #if @params.ro == 'true'
                #    delete newParams['ro']
                url = '/#' + $location.path() + '?' + $.param(newParams)
                window.open(url, '_blank')
                return true
            else
                #if @params.ro == 'true'
                #    delete @params['ro']
                @params[qs] = params_qs
                @doSearch no, no

        doNavigate: (event, field, value, newSearch = false) =>
            params = {}
            params[field] = value
            @doNavigateMultiple event, params, newSearch

        doNavigateActiveDossier: () =>
            adq = 'folder: \"' + @queryparse.escape_query_term(@dossier.active_dossier)    + '\"'
            qs = if (@getSourceFor @params.t)? then "q" else "s"
            @params[qs] = adq #union
            #@params['ro'] = 'true'
            @doSearch no, true

        splitQueryString: (query_string) =>
            # TODO be sensitive to "phrase with spaces"
            query_string.split /\s+/

        getSourceFor: (type) =>
            @types?[type]?.source

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

        bulk_search: (field, values) =>
            union = ''
            for v in values.split('\n')
                if v.trim().length > 0
                    if union.length
                        union = union + ' || '
                    union = union + '"' + @queryparse.escape_query_term(v.trim()) + '"'
            if union.length
                union = field + ': (' + union + ')'
                qs = if (@getSourceFor @params.t)? then "q" else "s"
                @params[qs] = union
                @doSearch no, true

        showBulkSearchDialog: () =>
            m = $uibModal.open {
                animation: true
                templateUrl: 'bulkSearchModal.html'
                controller: 'ModalInstanceCtrl'
                resolve: {}
            }
            m.result.then ((item) =>
                console.log item
                # add queries to folder
                @bulk_search item.field, item.values
                ),
             () ->
                console.log 'dismissed'



    new DeepDiveSearch

.controller "ModalInstanceCtrl", ($scope, $routeParams, $uibModalInstance, DeepDiveSearch) ->
    $scope.search = DeepDiveSearch
    $scope.all_fields = DeepDiveSearch.getFieldsFor ['navigable', 'searchable'], DeepDiveSearch.params.t
    $scope.field = ''
    $scope.values = ''

    $scope.ok = () =>
        $uibModalInstance.close {
            field:$scope.field
            values:$scope.values
        }

    $scope.cancel = () =>
        $uibModalInstance.dismiss 'cancel'

