#

angular.module "mindbender.search.suggest", [
    'elasticsearch'
    'json-tree'
    'ngSanitize'
    'mindbender.auth'
    'ngHandsontable'
    'ui.bootstrap'
    'mindbender.search.search'
    'mindbender.search.queryparse'
]

.directive "searchQueryInput", (DeepDiveSearch, SuggestService) ->
    controller: ($scope) ->
        $scope.suggest = SuggestService

    link: (scope, element, attrs) =>
        scope.cursor = 0
        element.bind "keyup", () =>
          #console.log "Current position: " + element.caret().start

          el = $(element).get(0)
          pos = 0
          if 'selectionStart' of el
              pos = el.selectionStart
          else if 'selection' of document
              el.focus()
              Sel = document.selection.createRange()
              SelLength = document.selection.createRange().text.length
              Sel.moveStart('character', -el.value.length)
              pos = Sel.text.length - SelLength
          scope.cursor = pos
          #console.log pos
          #return pos


.service "SuggestService", (elasticsearch, $http, $q, $timeout, QueryParseService) ->

    class SuggestService
        constructor: () ->
            @elastic = elasticsearch
            @queryparse = QueryParseService
            @suggestions = []

        init: (@elasticsearchIndexName = "_all") =>
            @

        getValueMatches: (facet, searchTerm) =>
            deferred = $q.defer()

            #if (!_.contains(navigable, facet)) return
            request = {
                index: '_all'
                type: @params.t
            }
            if (!searchTerm)
                # ES suggest API doesn't return results when query is empty.
                # We use the aggs API instead in that case.
                request.body = {
                    aggs: {
                        hist: {
                            terms: {
                                size: 20
                                field: facet
                            }
                        }
                    }
                }
                promise = @search(request)
            else
                comp = {
                    size: 20
                    field : facet + "__suggest"
                }
                if facet != 'phones'
                    comp.fuzzy = {
                        prefix_length: 3
                    }
                request.body = {
                    suggest: {
                        text: searchTerm
                        completion: comp
                    }
                }
                promise = @elastic.suggest(request)
            
            promise.then (data) =>
                console.log 'received data'
                results = []
                if data.suggest && data.suggest.length 
                    results = data.suggest[0].options.map (item) =>
                        {
                            # Although we do set weight=1 when indexing suggest fileds,
                            # the final score is not the sum.
                            label: item.text # + ' (' + item.score + ')'
                            type: 'suggestion'
                        }
                    
                else if data.aggregations && data.aggregations.hist
                    results = data.aggregations.hist.buckets.map (item) =>
                        {
                            value: item.key
                            label: item.key + ' (' + item.doc_count + ')'
                            type: 'suggestion'
                        }
                else
                    return

                console.log 'returning'
                console.log results
                deferred.resolve results
            return deferred.promise

        getSearchSuggestions: (viewValue, cursor) =>
            console.log 'getting search suggestions'

            deferred = $q.defer()
            deferred.resolve [ 
              {  
                label: 'test'
                type: 'test'
              }
            ]


            #p = @queryparse.parse_query viewValue
            #p.then \
            #     ((pq) => 
            #         console.log 'parsed query'
            #         console.log pq
            #         console.log 'cursor ' + cursor
            #         map = @queryparse.mapPositionToQueryTerm pq
            #         # generate suggestions
            #         console.log map[cursor]
            #         qt = map[cursor]
            #         p2 = @getValueMatches qt.field, qt.term
            #         p2.then (results) =>
            #             console.log 'resolving'
            #             console.log results
            #             deferred.resolve results), \ 
            #     ((error) =>
            #        console.log 'ERROR'
            #        console.log error
            #        deferred.resolve [
            #            {
            #                label: error.message
            #                type: 'error'
            #            }
            #        ]
            #        )
            return deferred.promise

    new SuggestService
