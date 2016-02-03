# 

angular.module "mindbender.search.dossier", [
    'elasticsearch'
    'json-tree'
    'ngSanitize'
    'mindbender.auth'
    'ui.bootstrap'
    'mindbender.search.queryparse'
]

.service "DossierService", ($http, $uibModal, QueryParseService) ->
    class DossierService
        constructor: () ->
            @all_dossiers = null
            @active_dossier = null
            @active_dossier_force_updates = 0
            @query_to_dossiers = null
            @queryparse = QueryParseService

        init: () =>
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

        fetch_dossier_by_name: (dossier_name) =>
            $http.get '/api/dossier/by_dossier/', { params: { dossier_name : dossier_name } }

    new DossierService

.directive "queryDossierPicker", (DossierService) ->
    restrict: 'A'
    replace: true
    scope:
        search: "=for"
        query: "=queryString"
        docid: "=queryStringDocid"
        query_title: "=queryTitle"
    controller: ($scope) ->
        $scope.dossier = DossierService
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
            _.each $scope.dossier.query_to_dossiers[query], (d) ->
                options.push
                    name: d
                    selected: true
                selected[d] = true
            _.each $scope.dossier.all_dossiers, (d) ->
                if not selected.hasOwnProperty d
                    options.push
                        name: d
                        selected: false

            old_all_dossiers = _.clone $scope.dossier.all_dossiers
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
                            $scope.dossier.add_dossier val
                            if val == $scope.dossier.active_dossier
                                # trigger dossierQueryPicker to reload
                                $scope.dossier.active_dossier_force_updates += 1
                        $scope.$apply()


        $scope.$watch 'dossier.query_to_dossiers', ->
            if not $scope.dossier.query_to_dossiers
                return
            handler()
            initialized = true

        $scope.$watch 'dossier.all_dossiers', ->
            if not initialized or not $scope.dossier.all_dossiers
                return

            new_names = _.difference $scope.dossier.all_dossiers, old_all_dossiers

            if new_names.length
                _.each new_names, (nm) ->
                    $element.prepend $('<option/>', {value: nm, text: nm})
                $element.selectpicker('refresh')
                old_all_dossiers = _.clone $scope.dossier.all_dossiers


.directive "globalDossierPicker", ->
    restrict: 'A'
    replace: true
    scope:
        search: "=for"
    link: ($scope, $element) ->
        $scope.$watch 'search.dossier.all_dossiers', ->
            if not $scope.search.dossier.all_dossiers
                return
            $element.empty()
            _.each $scope.search.dossier.all_dossiers, (name) ->
                $option = $('<option/>', {
                    value: name,
                    text: name
                })
                $element.append($option)

            picker = $element.selectpicker('refresh').data('selectpicker')
            if $scope.search.dossier.active_dossier
                picker.val $scope.search.dossier.active_dossier
            picker = $element.selectpicker('refresh').data('selectpicker')
            picker.$searchbox.attr('placeholder', 'Search')
            picker.$newElement.find('button').attr('title',
                'Select an existing folder to list its queries and docs.').tooltip()
            $element.on 'change', ->
                $scope.search.dossier.active_dossier = picker.val()
                $scope.$apply()


.directive "dossierQueryPicker", ->
    restrict: 'A'
    replace: true
    scope:
        search: "=for"
    link: ($scope, $element) ->
        handler = () ->
            dossier_name = $scope.search.dossier.active_dossier
            if not dossier_name
                $element.empty()
                $element.prop('disabled', true)
                $element.selectpicker('refresh')
                return
            $element.data('selectpicker').$newElement.fadeOut()
            $.getJSON '/api/dossier/by_dossier/', {dossier_name: dossier_name}, (items) ->
                $element.empty()
                $element.prop('disabled', false)
                $scope.search.dossier.active_dossier_queries = {}
                _.each items, (item) ->
                    $scope.search.dossier.active_dossier_queries[item.query_string] = true
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
                console.log $scope.search.dossier.active_dossier_queries

        $scope.$watch 'search.dossier.active_dossier', handler
        $scope.$watch 'search.dossier.active_dossier_force_updates', handler


