#

angular.module "mindbender.search", [
    'elasticsearch'
    'json-tree'
    'ngSanitize'
    'mindbender.auth'
    'ngHandsontable'
    'ui.bootstrap'
    'frapontillo.bootstrap-switch'
    'mindbender.search.scores'
    'mindbender.search.dossier'
    'mindbender.search.annotation'
    'mindbender.search.search'
    'mindbender.search.suggest'
    'mindbender.search.queryparse'
    'mindbender.search.util'
]

.config ($routeProvider) ->
    $routeProvider.when "/search/:index*?",
        brand: "Evidently", brandIcon: "search"
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
        brand: "Evidently", brandIcon: "search"
        title: """{{type}}( {{id}} ) in {{index}} - DeepDive"""
        templateUrl: "search/view.html"
        controller: "SearchViewCtrl"
    $routeProvider.when "/search",
        redirectTo: "/search/"


## for searching extraction/source data
.controller "SearchResultCtrl", ($scope, $routeParams, $location, DeepDiveSearch, $modal, tagsService, $http, DossierService) ->
    $scope.search = DeepDiveSearch.init $routeParams.index
    $scope.dossier = DossierService
    $scope.tags = tagsService
    $scope.openModal = (options) ->
        $modal.open _.extend {
            scope: $scope
        }, options

    # make sure we show search results at first visit (when no parameters are there yet)
    if (_.size $location.search()) == 0
        do $scope.search.doSearch

    $scope.organization = ''
    $http({
        method: 'GET'
        url: "/api/organization"
    }).success (data) ->
            $scope.organization = data

.directive "deepdiveSearchBar", ($timeout, DossierService) ->
    scope:
        search: "=for"
    templateUrl: "search/searchbar.html"
    controller: ($scope, $routeParams, $location, DeepDiveSearch, DossierService) ->
        $scope.dossier = DossierService
        $scope.advancedMode = $scope.search.params['advanced']

        $scope.$watch 'advancedMode', (val) ->
            #update search/URL when switch is used
            $scope.search.params['advanced'] = val 
            search = $location.search()
            $location.search k, v for k, v of DeepDiveSearch.params

            #re-render visualsearch, this fixes a rendering bug of visualsearch where part of query is not shown unless you click on it
            qs = $scope.search.params.s || ''
            p1 = $scope.search.queryparse.parse_query qs
            p1.then (pq) =>
                isSimple = $scope.search.queryparse.isSimpleQuery(pq)
                r = if isSimple then qs else ''
                console.log 'isSimple ' + isSimple + ' ' + r
                if window.visualSearch
                    window.visualSearch.searchBox.value(r)

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
            # update switch when URL parameter for advanced changes
            $scope.$watch (-> DeepDiveSearch.params), (->
                $scope.advancedMode = DeepDiveSearch.params['advanced']), true
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

        $scope.getMassagePlaces = () ->
            urls_a = $scope.extraction['massage_places_urls']
            sites = $scope.extraction['massage_places_sites']
            titles = $scope.extraction['massage_places'] 
            values = []
            for val, i in titles
                a = { 
                    'url':urls_a[i],
                    'title':titles[i],
                    'site':sites[i]
                }
                values.push a
            return values

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

# a handy filter for generating safe id strings for HTML
.filter "safeId", () ->
    (text) ->
        text?.replace /[^A-Za-z0-9_-]/g, "_"

