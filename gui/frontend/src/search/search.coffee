#
# NOTE: THERE IS A PROBLEM WITH ONE OF THE IMPORTED LIBRARIES; YOU HAVE TO COMMENT
# OUT ONE LINE, BEFORE YOU CAN RUN EVIDENTLY.
# AFTER INSTALLATION, EDIT
#  gui/frontend/bower_components/bootstrap-tagsinput/dist/bootstrap-tagsinput.js
# AND MAKE TWO CHANGES
#
# 1. COMMENT OUT LINE 164
# // self.$input.typeahead('val', '');
# Maybe a similar problem:
# https://github.com/bassjobsen/Bootstrap-3-Typeahead/issues/145
#
# 2. CHANGE LINE 331
# matcher: function (text) {
#            return (text.toLowerCase().indexOf(this.query.trim().toLowerCase()) == 0); // changed from !== -1 to == 0
#          },
# More info: https://github.com/bootstrap-tagsinput/bootstrap-tagsinput/issues/297

angular.module "mindbender.search", [
    'elasticsearch'
    'json-tree'
    'ngSanitize'
    'mindbender.auth'
    'ngHandsontable'
    'ui.bootstrap'
]

.config ($routeProvider) ->
    $routeProvider.when "/search/:index*?",
        brand: "Evidently LE", brandIcon: "search"
        title: 'Search {{
                q ? "for [" + q + "] " : (s ? "for [" + s + "] " : "everything ")}}{{
                t ? "in " + t + " " : ""}}{{
                s ? (q ? "from sources matching [" + s + "] " : "") : ""}}{{
                index ? "(" + index + ") " : ""
            }}- DeepDive'
        templateUrl: "search/search.html"
        controller: "SearchResultCtrl"
        reloadOnSearch: no
    $routeProvider.when "/view/:index/:type",
        brand: "Evidently LE", brandIcon: "search"
        title: """{{type}}( {{id}} ) in {{index}} - DeepDive"""
        templateUrl: "search/view.html"
        controller: "SearchViewCtrl"
    $routeProvider.when "/search",
        redirectTo: "/search/"

## for searching extraction/source data
.controller "SearchResultCtrl", ($scope, $routeParams, $location, DeepDiveSearch, $modal) ->
    $scope.search = DeepDiveSearch.init $routeParams.index
    $scope.openModal = (options) ->
        $modal.open _.extend {
            scope: $scope
        }, options

    # make sure we show search results at first visit (when no parameters are there yet)
    if (_.size $location.search()) == 0
        do $scope.search.doSearch

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


.directive "myDatePicker", ->
    restrict: 'A'
    replace: true
    link: ($scope, $element) ->
        $element.bootstrapDP({
            format: "yyyy-mm-dd",
            immediateUpdates: true,
            orientation: "bottom auto"
        })


.directive "myToolTip", ->
    restrict: 'A'
    replace: true
    link: ($scope, $element) ->
        $element.tooltip()


.directive "queryDossierPicker", ->
    restrict: 'A'
    replace: true
    scope:
        search: "=for"
        query: "=queryString"
        docid: "=queryStringDocid"
        query_title: "=queryTitle"
    link: ($scope, $element) ->
        if $scope.docid
            query = 'doc_id: "' + $scope.docid + '"'
            query_is_doc = true
        else
            query = $scope.query
            query_is_doc = false
        query_title = $scope.query_title

        initialized = false
        old_all_dossiers = null

        handler = () ->
            options = []
            selected = {}
            _.each $scope.search.query_to_dossiers[query], (d) ->
                options.push
                    name: d
                    selected: true
                selected[d] = true
            _.each $scope.search.all_dossiers, (d) ->
                if not selected.hasOwnProperty d
                    options.push
                        name: d
                        selected: false

            old_all_dossiers = _.clone $scope.search.all_dossiers
            options_names = _.pluck options, 'name'

            window.setupMySelectPicker $element, options, (old_vals, new_vals) ->
                $.ajax
                    type: "POST",
                    url: "/api/dossier/by_query/",
                    processData: false,
                    contentType: 'application/json',
                    data: JSON.stringify
                        query_string: query
                        query_title: query_title
                        query_is_doc: query_is_doc
                        selected_dossier_names: _.difference(new_vals, old_vals)
                        unselected_dossier_names: _.difference(old_vals, new_vals)
                    success: ->
                        console.log '/dossier/by_query/:', query, old_vals, new_vals

                        _.each new_vals, (val) ->
                            old_all_dossiers.push val
                            $scope.search.add_dossier val
                            if val == $scope.search.active_dossier
                                # trigger dossierQueryPicker to reload
                                $scope.search.active_dossier_force_updates += 1
                        $scope.$apply()


        $scope.$watch 'search.query_to_dossiers', ->
            if not $scope.search.query_to_dossiers
                return
            handler()
            initialized = true

        $scope.$watch 'search.all_dossiers', ->
            if not initialized or not $scope.search.all_dossiers
                return

            new_names = _.difference $scope.search.all_dossiers, old_all_dossiers

            if new_names.length
                _.each new_names, (nm) ->
                    $element.prepend $('<option/>', {value: nm, text: nm})
                $element.selectpicker('refresh')
                old_all_dossiers = _.clone $scope.search.all_dossiers



.directive "globalDossierPicker", ->
    restrict: 'A'
    replace: true
    scope:
        search: "=for"
    link: ($scope, $element) ->
        $scope.$watch 'search.all_dossiers', ->
            if not $scope.search.all_dossiers
                return
            $element.empty()
            _.each $scope.search.all_dossiers, (name) ->
                $option = $('<option/>', {
                    value: name,
                    text: name
                })
                $element.append($option)

            picker = $element.selectpicker('refresh').data('selectpicker')
            if $scope.search.active_dossier
                picker.val $scope.search.active_dossier
            picker = $element.selectpicker('refresh').data('selectpicker')
            picker.$searchbox.attr('placeholder', 'Search')
            picker.$newElement.find('button').attr('title',
                'Select an existing folder to list its queries and docs.').tooltip()
            $element.on 'change', ->
                $scope.search.active_dossier = picker.val()
                $scope.$apply()


.directive "dossierQueryPicker", ->
    restrict: 'A'
    replace: true
    scope:
        search: "=for"
    link: ($scope, $element) ->
        handler = () ->
            dossier_name = $scope.search.active_dossier
            if not dossier_name
                $element.empty()
                $element.prop('disabled', true)
                $element.selectpicker('refresh')
                return
            $element.data('selectpicker').$newElement.fadeOut()
            $.getJSON '/api/dossier/by_dossier/', {dossier_name: dossier_name}, (items) ->
                $element.empty()
                $element.prop('disabled', false)
                $scope.search.active_dossier_queries = {}
                _.each items, (item) ->
                    $scope.search.active_dossier_queries[item.query_string] = true
                    ts = new Date(item.ts_created)
                    date = (ts.getMonth() + 1) + '/' + ts.getDate()
                    time = ts.getHours() + ':' + ts.getMinutes()
                    datetime = date + ' ' + time
                    icon = if item.query_is_doc then 'file-o' else 'search'
                    item_html = '<i class="fa fa-' + icon + '"></i>&nbsp; '
                    item_html += item.query_string
                    if item.query_title
                        item_html += ' (' + item.query_title + ')'
                    item_html += ' <em class="small muted">' + item.user_name + ' - ' + datetime +  '</em>'
                    $element.append($('<option/>', {
                        value: item.query_string,
                        text: item.query_string
                    }).data('content', item_html))
                picker = $element.selectpicker('refresh').data('selectpicker')
                $element.data('selectpicker').$newElement.fadeIn()
                picker.$searchbox.attr('placeholder', 'Search')
                $element.on 'change', ->
                    $scope.search.params.s = picker.val()
                    $scope.search.doSearch()

        $scope.$watch 'search.active_dossier', handler
        $scope.$watch 'search.active_dossier_force_updates', handler


## for viewing individual extraction/source data
.controller "SearchViewCtrl", ($scope, $routeParams, $location, DeepDiveSearch) ->
    $scope.search = DeepDiveSearch.init $routeParams.indexs
    _.extend $scope, $routeParams
    searchParams = $location.search()
    $scope.id = searchParams.id
    $scope.routing = searchParams.parent
    $scope.data =
        _index: $scope.index
        _type:  $scope.type
        _id:    $scope.id


.directive "deepdiveVisualizedData", (DeepDiveSearch, $q, $timeout) ->
    scope:
        data: "=deepdiveVisualizedData"
        searchResult: "="
        routing: "="
    template: """
        <span ng-include="'search/template/' + data._type + '.html'" onload="finishLoadingCustomTemplate()"></span>
        <span class="alert alert-danger" ng-if="error">{{error}}</span>
        """
    link: ($scope, $element) ->

        $scope.finishLoadingCustomTemplate = () ->
            # parse json for images; with better json support in the database we may be able
            # to avoid this step
            if $scope.searchResult?
                if $scope.searchResult._source.images?
                    images = []
                    _.each $scope.searchResult._source.images, (item) ->
                        #images.push(JSON.parse(item))
                        images.push({ hash: item })
                    $scope.searchResult._source.images_j = images

            # load tooltips, lazyload and colorbox
            $timeout () ->
                $element.find('[data-toggle=tooltip]').tooltip()
                $element.find('img').lazyload()
                $element.find('a.img-link').colorbox({rel:'imggroup-' + $scope.searchResult.idx })

            return false

        $scope.search = DeepDiveSearch.init()
        $scope.isArray = angular.isArray
        showError = (err) ->
            msg = err?.message ? err
            console.error msg
            # TODO display this in template
            $scope.error = msg
        unless $scope.data._type? and ($scope.data._source? or $scope.data._id?)
            return showError "_type with _id or _type with _source must be given to deepdive-visualized-data"
        fetchParentIfNeeded = (data) -> $q (resolve, reject) ->
            if $scope.searchResult?
                # no need to fetch parents ourselves
                resolve data
            else
                DeepDiveSearch.fetchSourcesAsParents [data]
                .then ([data]) -> resolve data
                , reject
        initScope = (data) ->
            switch kind = DeepDiveSearch.types?[data._type]?.kind
                when "extraction"
                    $scope.extractionDoc = data
                    $scope.extraction    = data._source
                    fetchParentIfNeeded data
                    unwatch = $scope.$watch (-> data.parent), (source) ->
                        $scope.sourceDoc = source
                        $scope.source    = source?._source
                        do unwatch if source?
                    , showError
                when "source"
                    $scope.extractionDoc = null
                    $scope.extraction    = null
                    $scope.sourceDoc = data
                    $scope.source    = data._source
                else
                    console.error "#{kind}: Unrecognized kind for type #{data._type}"

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


.directive "showRawData", ->
    restrict: "A"
    scope:
        data: "=showRawData"
        level: "@"
    template: ($element, $attrs) ->
        if +$attrs.level > 0
            """<json-tree edit-level="readonly" json="data" collapsed-level="{{level}}">"""
        else
            """
            <span ng-hide="showJsonTree"><tt>{<span ng-click="showJsonTree = 1" style="cursor:pointer;">...</span>}</tt></span>
            <json-tree ng-if="showJsonTree" edit-level="readonly" json="data" collapsed-level="2"></json-tree>
            """


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
                s: null # query string for source
                t: 'everything' # type to search
                n: 10   # number of items in a page
                p: 1    # page number (starts from 1)
            @params = _.extend {}, @paramsDefault
            @types = null
            @indexes = null
            @elastic = elasticsearch
            @collapsed_facets = { 
                'domain': true
                'locations': true
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
            }

            @all_dossiers = null
            @active_dossier = null
            @active_dossier_force_updates = 0
            @query_to_dossiers = null

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

        fetch_dossiers: (queries) =>
            $.getJSON '/api/dossier/by_query/', {queries: JSON.stringify(queries)}
            .success (data) =>
                @all_dossiers = data.all_dossiers
                if queries and queries.length
                    @query_to_dossiers = data.query_to_dossiers

        add_dossier: (dossier_name) =>
            if dossier_name and dossier_name not in @all_dossiers
                @all_dossiers = [dossier_name].concat @all_dossiers

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
            if window.visualSearch
                window.visualSearch.searchBox.value(qs)
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
                                    size: 
                                        switch navigable
                                            when "flags"
                                                100
                                            else
                                                100
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
            elasticsearch.search query
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
                best_facets = ['domain_type', 'flags', 'yelp', 'domain', 'locations', 'phones', 'post_date']
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

                dossier_queries = [qs]

                idx = query.body.from + 1
                for hit in data.hits.hits
                    hit.idx = idx++
                    dossier_queries.push('doc_id: "' + hit._id + '"')

                @fetch_dossiers dossier_queries

            , (err) =>
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

        doNavigate: (field, value, newSearch = false) =>
            qsExtra =
                if field and value
                    # use field-specific search for navigable fields
                    # VisualSearch may have added the quotes already
                    if value.indexOf("'") == 0 or value.indexOf('"') == 0
                        "#{field}: #{value}"
                    else
                        "#{field}: \"#{value}\""
                else if value?
                    "#{value}"
                else if field?
                    # filtering down null has a special query_string syntax
                    "_missing_:#{field}"
                else
                    ""
            qsExtra = qsExtra || ''
            # TODO check if qsExtra is already there in @params.q
            qs = if (@getSourceFor @params.t)? then "q" else "s"
            @params[qs] =
                if newSearch or not @params[qs]
                    qsExtra
                else if qsExtra and @params[qs].indexOf(qsExtra) == -1
                    "#{@params[qs]} #{qsExtra}"
                else
                    @params[qs]
            @doSearch no

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

    new DeepDiveSearch


# a handy filter for generating safe id strings for HTML
.filter "safeId", () ->
    (text) ->
        text?.replace /[^A-Za-z0-9_-]/g, "_"


.directive "scoresTable", ($q, $timeout, $http, hotRegisterer, $compile) ->
    template: """
        <hot-table
          hot-id="myTable"
          settings="db.settings"
          datarows="db.items">
        </hot-table>
        """
    controller: ($scope) ->

        $scope.phoneRenderer = (hotInstance, td, row, col, prop, value, cellProperties) =>
            Handsontable.renderers.TextRenderer.apply(this, arguments)
            td.innerHTML = "<a style='cursor:pointer; margin-right: 4px;'
                        data-toggile='tooltip' title='New search with this filter'
                        ng-click=\"search.doNavigate('phones', '" +value+"', true)\">" + 
                        value + "</a>"
            $compile(angular.element(td))($scope)

        $scope.locRenderer = (hotInstance, td, row, col, prop, value, cellProperties) =>
            Handsontable.renderers.TextRenderer.apply(this, arguments)
            if value == 'Unknown'
                value = ''
            if value.length > 50
                value = value.substring(0,50)
            td.innerHTML = value

        $scope.scoreRenderer = (hotInstance, td, row, col, prop, value, cellProperties) =>
            Handsontable.renderers.TextRenderer.apply(this, arguments)
            td.innerHTML = '<div style="height:15px;width:' + Math.round(parseFloat(value) * 50.0) + 'px;background-color:#f0ad4e"></div>'

        $scope.columns = [
          {
           data:'phone_number'
           title:'Phone Number'
           renderer:$scope.phoneRenderer
           readOnly:true 
          },
          { data:'ads_count', title:'#Ads', readOnly:true, type:'numeric' },
          { data:'reviews_count', title:'#Reviews', readOnly:true, type:'numeric' },
          { data:'organization_score', title:'Organization', readOnly:true, renderer:$scope.scoreRenderer },
          { data:'control_score', title:'Control', readOnly:true, renderer:$scope.scoreRenderer },
          { data:'underage_score', title:'Underage', readOnly:true, renderer:$scope.scoreRenderer },
          { data:'movement_score', title:'Movement', readOnly:true, renderer:$scope.scoreRenderer },
          { data:'overall_score', title:'Overall', readOnly:true, renderer:$scope.scoreRenderer },
          { data:'city', title:'City', readOnly:true, renderer:$scope.locRenderer },
          { data:'state', title:'State', readOnly:true, renderer:$scope.locRenderer }
        ]

        $scope.db = {
           settings : {
               colHeaders: true
               rowHeaders: true
               contextMenu: true
               columns: $scope.columns
               afterGetColHeader: (col, TH) => 
                   if col > 0 && col < 8 
                      TH.innerHTML = '<span ng-click="sortByColumn(' + col + 
                          ')" style="cursor:pointer;padding-left:5px;padding-right:5px">' + 
                          $scope.columns[col].title + '</span>'
                      $compile(angular.element(TH.firstChild))($scope)
           }
           items : []
        }

        $scope.sortByColumn = (col) =>
            field = $scope.columns[col].data
            if field.endsWith('_score') || field.endsWith('_count')
                field = field + ' DESC'
            $scope.fetchScores(field)

    link: ($scope, $element) ->

        $scope.fetchScores = (sort_order) =>
            $http.get "/api/scores", { params: {sort_order:sort_order} }
                  .success (data) =>
                      $scope.db.items = data
                  .error (err) =>
                      console.error err.message

        $scope.fetchScores('overall_score DESC')


.directive "labelPopover", ($timeout, $document, $uibPosition) ->
    transclude:true
    scope:
        k: "="
    template: """<span uib-popover-template="'labelPopoverTemplate.html'" 
           popover-trigger="manual" ng-class="{'highlight':true,
            'highlight-correct': tag.is_correct == 'correct',
            'highlight-incorrect': tag.is_correct == 'incorrect',
            'highlight-unknown': tag.is_correct == 'unknown' }"
           popover-placement="bottom"
           popover-is-open="isOpen"
           ng-click="isOpen = true"
           ng-transclude></span>"""

    controller: ($scope) ->
        $scope.isOpen = false
        # the popover creates it's own scope which protoypically inherits from this scope;
        # we thus wrap is_correct into an object, so that we don't need to synchronize state
        $scope.tag = { is_correct : '' }
        $scope.last_user_name = ''

        $scope.commit = (val) =>
            # if user clicks on active button, we reset the value
            cur = $scope.curFeedback()
            if cur && cur.value == val
                $scope.tag.is_correct = val = ''
            $timeout () =>
                $scope.$parent.writeFeedback $scope.extraction.doc_id, $scope.extraction.mention_id, val 

        $scope.curFeedback = (f) =>
            if !f
                f = $scope.$parent.feedback
            if !f || !$scope.extraction
                return false
            cur = f[$scope.extraction.doc_id + ',' + $scope.extraction.mention_id]
            if !cur
               return false
            return cur

        $scope.tagHandler = (f) =>
            cur = $scope.curFeedback(f)
            if cur && cur.value != $scope.tag.is_correct
               $scope.tag.is_correct = cur.value
            if cur.user_name != $scope.last_user_name
               if cur.value == ''
                   $scope.last_user_name = ''
               else
                   $scope.last_user_name = cur.user_name

        # we set initial state by listening to broadcast from parent
        $scope.$on 'update_feedback', (event, feedback) =>
            $scope.tagHandler feedback

    link: ($scope, $element, attrs) ->
        k = parseInt(attrs.k)
        $scope.extraction = JSON.parse($scope.$parent.searchResult._source.extractions[k])
        $scope.extractor = $scope.extraction.extractor

        # hide popover on click away
        handler = (e) ->
            if $scope.isOpen && !$element[0].contains(e.target)
                $scope.$apply () ->
                    $scope.isOpen = false

        $document.on 'click', handler

        $scope.$on '$destroy', () =>
            $document.off('click', handler)


.directive "textWithAnnotations", ($q, $timeout, $http, $compile, tagsService) ->
    scope:
        searchResult: "="
    template: """
        <div></div>
        """
    controller: ($scope) ->
        # map from doc_id,mention_id -> feedback
        $scope.feedback = {}

        $scope.fetchFeedback = () =>
            doc_id = $scope.searchResult._source.doc_id
            $http.get "/api/feedback/" + doc_id 
                  .success (data) =>
                      data.forEach (d) ->
                          $scope.feedback[d.doc_id + ',' + d.mention_id] = d
                      $scope.$broadcast('update_feedback', $scope.feedback)
                  .error (err) =>
                      console.error err.message

        $scope.writeFeedback = (doc_id, mention_id, value) =>
            $http.post "/api/feedback", { doc_id:doc_id, mention_id:mention_id, value:value }
                .success (data) =>
                    # update model
                    $scope.feedback[doc_id + ',' + mention_id] = data
                    $scope.$broadcast('update_feedback', $scope.feedback)
                .error (err) =>
                    console.error err.message

        $scope.fetchFeedback()

        $scope.annotations = {}

        $scope.fetchAnnotations = () =>
            doc_id = $scope.searchResult._source.doc_id
            $http.get "/api/annotation/" + doc_id
                .success (data) =>
                    data.forEach (d) ->
                        $scope.showAnnotation(d.value, false)
                .error (err) =>
                    console.error err.message

        $scope.writeAnnotation = (doc_id, mention_id, value, callback) =>
            $http.post "/api/annotation", { doc_id:doc_id, mention_id:mention_id, value:value }
                .success (data) =>
                    value.user_name = data.user_name
                    if callback
                        callback()
                .error (err) =>
                    console.error err.message

        $scope.removeAnnotation = (doc_id, mention_id, callback) =>
            $http.delete '/api/annotation/' + doc_id + '/' + mention_id, { }
                .success (data) =>
                    if callback
                        callback()
                .error (err) =>
                    console.error err.message

        $scope.fetchAnnotations()

        $scope.onSelection = (ranges, event) =>
            if ranges.length > 0
                doc_id = $scope.searchResult._source.doc_id
                mention_id = Object.keys($scope.annotations).length
                annotation = $scope.makeAnnotation(ranges)
                obj = { doc_id:doc_id, mention_id:mention_id, value:annotation, tags:[] }
                $scope.showAnnotation(obj, true)
                document.getSelection().removeAllRanges()

        $scope.showAnnotation = (ann, openPopup = false) =>
            highlightSpans = $scope.hl.draw(ann.value)
            key = ann.doc_id + ',' + ann.mention_id
            $scope.annotations[key] = ann
            for i in highlightSpans
                el = angular.element(i)
                el.attr('annotation-popover', '')
                el.attr('doc-id', ann.doc_id)
                el.attr('mention-id', ann.mention_id)
                el.attr('annotation-open', openPopup)
            $compile(el)($scope)

        $scope.hideAnnotation = (doc_id, mention_id) =>
            key = doc_id + ',' + mention_id
            ann = $scope.annotations[key]
            $scope.hl.undraw(ann.value)
            delete $scope.annotations[key]

        $scope.getAnnotation = (doc_id, mention_id) =>
            key = doc_id + ',' + mention_id
            return $scope.annotations[key]

    link: ($scope, $element) ->
        el = TextWithAnnotations.create($scope.searchResult)
        $element.append(el)

        $compile(el)($scope)

        # enable annotations
        $scope.hl = new annotator.ui.highlighter.Highlighter $element[0], {}
        $scope.ts = new annotator.ui.textselector.TextSelector $element[0], { 
            onSelection: $scope.onSelection }

        # trims whitespace, usually in native code but not ie8
        trim = (s) =>
            if typeof String.prototype.trim == 'function'
                String.prototype.trim.call s
            else
                s.replace(/^[\s\xA0]+|[\s\xA0]+$/g, '')

        # construct annotation from list of ranges
        annotationFactory = (contextel, ignoreSelector) =>
            return (ranges) =>
                text = []
                serializedRanges = []
                for i in [0...ranges.length]
                    r = ranges[i]
                    text.push trim(r.text())
                    serializedRanges.push(r.serialize(contextel, ignoreSelector))
                return {
                    quote: text.join(' / ')
                    ranges: serializedRanges
                }

        $scope.makeAnnotation = annotationFactory($element[0], '.annotator-hl')


.directive "annotationPopover", ($http, $compile, $document, $timeout, tagsService) ->
    scope: {}
    controller: ($scope) ->
        $scope.tags = tagsService
        $scope.togglePopup = () =>
            $scope.isOpen = !$scope.isOpen

        #$scope.cancel = () =>
        #    $scope.isOpen = false
        #    tags = $scope.annotation.tags
        #    $scope.$parent.removeAnnotation $scope.docId, $scope.mentionId, () -> 
        #        for t in $scope.annotation.tags
        #            tagsService.maybeRemove t
        #    $scope.$parent.hideAnnotation $scope.docId, $scope.mentionId

        $scope.add = (st) =>            
            $scope.annotation.tags.push(st)
            $scope.$parent.writeAnnotation($scope.docId, $scope.mentionId,
                $scope.annotation)
            tagsService.maybeCreate(st)

        $scope.remove = (st) =>
            index = $scope.annotation.tags.indexOf(st)
            if index > -1
                $scope.annotation.tags.splice index, 1
                $scope.$parent.writeAnnotation $scope.docId, $scope.mentionId,
                    $scope.annotation, () ->
                         tagsService.maybeRemove st

        $scope.onSelect = ($item, $model, $label) ->
            $scope.commit($item)

    link: ($scope, $element, attrs) ->
        $scope.isOpen = attrs['annotationOpen'] == 'true'
        $scope.docId = attrs['docId']
        $scope.mentionId = attrs['mentionId']

        $scope.annotation = $scope.$parent.getAnnotation $scope.docId, $scope.mentionId

        # remove self to avoid infinite loop
        $element.removeAttr('annotation-popover')

        # add popover
        $element.attr('uib-popover-template', "'annotationPopoverTemplate.html'")
        $element.attr('popover-trigger', 'manual')
        $element.attr('popover-placement', 'bottom')
        $element.attr('popover-is-open', 'isOpen')

        # add tooltip
        $element.attr('data-toggle', 'tooltip')
        $element.attr('data-placement', 'top')
        $element.attr('data-original-title', '{{annotation.tags.join(", ")}}')

        $element.attr('ng-click', 'togglePopup()')

        $compile($element)($scope)

        $timeout () =>
          $element.tooltip()

        # hide popover on click away
        handler = (e) ->
            if $scope.isOpen && !$(e.target).parents('.popover').length && !$element[0].contains(e.target) && 
                document.body.contains(e.target)
                    $scope.$apply () ->
                        $scope.isOpen = false
                        if $scope.annotation.tags.length == 0
                            $scope.$parent.removeAnnotation $scope.docId, $scope.mentionId
                            $scope.$parent.hideAnnotation $scope.docId, $scope.mentionId

        $timeout () =>
            $document.on 'click', handler

        $scope.$on '$destroy', () =>
            $document.off('click', handler)

.directive "tagsinputCustomEvents", ($parse, $timeout, tagsService) ->
    restrict: 'A'
    scope:
        add:'=add'
        remove:'=remove'
        activeTags:'=tags'
    link: ($scope, elem, attrs) ->
        elem.tagsinput({
            confirmKeys: [13]
            trimValue: true
            typeahead: {
                source: tagsService.tags
                minLength: 0
                showHintOnFocus: false
                #matcher: 'case insensitive'
                matcher: (a) ->
                   a.toUpperCase().indexOf(this.query.toUpperCase()) == 0
                autoSelect: false
            }
        })

        # add initial set of items
        elem.tagsinput('removeAll')
        for t in $scope.activeTags
            elem.tagsinput('add', t)

        elem.on 'itemAdded', (evt) ->
            $scope.add evt.item
            # fix bug where the input val does not clear
            $timeout () ->
              elem.tagsinput('input').val('')
        elem.on 'itemRemoved', (evt) ->
            $scope.remove evt.item

        triggerFunc = (evt) ->
            if !$scope.activeTags || $scope.activeTags.length == 0
                  # hack to force open drawer
                  elem.tagsinput('input').typeahead('lookup', '')

        elem.tagsinput('input').bind('focus', triggerFunc)

        $timeout () ->
            elem.tagsinput('findInputWrapper').css('min-width','200px')
            elem.tagsinput('input').parent().css('width','100%')
            elem.tagsinput('focus')

.service "tagsService", ($http) ->
    cmp = (a,b) ->
        a.toUpperCase().localeCompare(b.toUpperCase())

    tags = {
        # array of tags used shown in the annotation typeahead
        tags: []
        maybeCreate: (value) ->
            # creates tag if it does not exist
            if $.inArray(value, tags.tags) == -1
                $http.post "/api/tags", { value:value }
                    .success (data) =>
                        tags.tags.push value
                        tags.tags.sort cmp
                    .error (err) =>
                        console.error err.message
        maybeRemove: (value) ->
            # checks if tag is used by any annotation and if not, removes tag
            $http.get "/api/tags/maybeRemove/" + encodeURIComponent(value), {}
                 .success (data) =>
                    if parseInt(data) > 0
                        index = tags.tags.indexOf(value)
                        if index > -1
                            tags.tags.splice index, 1
                 .error (err) =>
                    console.error err
        fetchTags: () ->
            $http.get "/api/tags", {}
                .success (data) =>
                    tags.tags = $.map data, (t) -> t.value
                    tags.tags.sort cmp
                .error (err) =>
                    console.error err.message
    }

    tags.fetchTags()

    return tags

.directive "helpVideo", ($timeout, $templateCache) -> 

    link: ($scope, elem, attrs) ->
       elem.tooltip({
           title:'Demo Video'
           placement:'bottom'
       })
       videoHtml = $templateCache.get('helpVideo.html')
       elem.colorbox({
           html:videoHtml
           innerWidth:'800px'
           onComplete:() ->
               colorbox = $(document.getElementById('colorbox'))
               video = colorbox.find('video')
               video[0].play()
       })
        
