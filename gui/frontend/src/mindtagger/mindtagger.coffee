angular.module 'mindbenderApp.mindtagger', [
    'ui.bootstrap'
    'mindbenderApp.mindtagger.wordArray'
    'mindbenderApp.mindtagger.arrayParsers'
]

.config ($routeProvider) ->
    $routeProvider.when '/mindtagger',
        templateUrl: 'mindtagger/tasklist.html',
        controller: 'MindtaggerTaskListCtrl'
    $routeProvider.when '/mindtagger/:task',
        templateUrl: 'mindtagger/task.html',
        controller: 'MindtaggerTaskCtrl'

.controller 'MindtaggerTaskListCtrl', ($scope, $http, $location) ->
    $scope.tasks ?= []
    $http.get "/api/mindtagger/"
        .success (tasks) ->
            $scope.tasks = tasks
            if $location.path() is "/mindtagger" and tasks?.length > 0
                $location.path "/mindtagger/#{tasks[0].name}"


.controller 'MindtaggerTaskCtrl', ($scope, $routeParams, MindtaggerUtils, commitTags, $http, $window, $timeout, $location) ->
    $scope.$utils = MindtaggerUtils

    $scope.MindtaggerTask =
    MindtaggerTask =
        name: $routeParams.task

        schema: {}
        schemaTagsFixed: {}
        defineTags: (tagsSchema...) ->
            _.extend MindtaggerTask.schemaTagsFixed, tagsSchema...
            do MindtaggerTask.updateSchema
        updateSchema: (schema...) ->
            _.extend MindtaggerTask.schema, schema... if schema.length > 0
            _.extend MindtaggerTask.schema.tags, MindtaggerTask.schemaTagsFixed

        tags: null
        items: null
        itemsCount: null

        currentPage: +($location.search().p ? 1)
        itemsPerPage: +($location.search().s ? 10)
        cursorIndex: 0

    $scope.keys = (obj) -> key for key of obj

    $http.get "/api/mindtagger/#{MindtaggerTask.name}/schema"
        .success ({schema}) ->
            MindtaggerTask.updateSchema schema
            $http.get "/api/mindtagger/#{MindtaggerTask.name}/items", {
                params:
                    offset: MindtaggerTask.itemsPerPage * (MindtaggerTask.currentPage - 1)
                    limit:  MindtaggerTask.itemsPerPage
            }
                .success ({tags, items, itemsCount}) ->
                    MindtaggerTask.tags = tags
                    MindtaggerTask.items = items
                    MindtaggerTask.itemsCount = itemsCount
        .error ->
            $location.path "/mindtagger"

    $scope.exportFormat = "sql"
    $scope.export = (format) ->
        $window.location.href = "/api/mindtagger/#{MindtaggerTask.name}/tags.#{format ? $scope.exportFormat
        }?table=#{
            "" # TODO allow table name to be customized
        }&attrs=#{
            encodeURIComponent ((attrName for attrName,attrSchema of MindtaggerTask.schema.items when attrSchema.export).join ",")
        }&tags=#{
            encodeURIComponent ((tagName for tagName,tagSchema of MindtaggerTask.schema.tags when tagSchema.export).join ",")
        }"

    # cursor
    $scope.moveCursorTo = (index) -> MindtaggerTask.cursorIndex = index
    # pagination
    $scope.pageChanged = -> $location.search "p", MindtaggerTask.currentPage
    $scope.pageSizeChanged = _.debounce -> $scope.$apply ->
            $location.search "s", MindtaggerTask.itemsPerPage
        , 750

    # create/add tag
    $scope.addTagToCurrentItem = (name, type = 'binary', value = true) ->
        console.log "adding tag to item under cursor", name, type, value
        tag = (MindtaggerTask.tags[MindtaggerTask.cursorIndex] ?= {})
        tag[name] = value
        $scope.$emit "tagChangedForCurrentItem"
    $scope.commit = -> $timeout ->
        $scope.$emit "tagChangedForCurrentItem"
    $scope.$on "tagChangedForCurrentItem", (event) ->
        index = MindtaggerTask.cursorIndex
        item = MindtaggerTask.items[index]
        tag = MindtaggerTask.tags[index]
        itemIndex = index +
            (MindtaggerTask.currentPage - 1) * MindtaggerTask.itemsPerPage
        console.log "some tags of current item (##{itemIndex}) changed, committing", tag
        key =
            # use itemKeys if available
            if MindtaggerTask.schema.itemKeys?.length > 0
                (item[k] for k in MindtaggerTask.schema.itemKeys).join "\t"
            else
                itemIndex
        updates = [
            { tag, key }
        ]
        commitTags MindtaggerTask, updates

.controller 'MindtaggerTagsCtrl', ($scope) ->
    index = $scope.$parent.$index
    # FIXME Is there any way to avoid $parent?
    $scope.tag = ($scope.$parent.MindtaggerTask.tags[index] ?= {})


# TODO move other $http usages into a service that also covers commitTags
.service 'commitTags', ($http, $modal, $window) ->
    (MindtaggerTask, updates) ->
        $http.post "/api/mindtagger/#{MindtaggerTask.name}/items", updates
            .success (schema) ->
                console.log "committed tags updates", updates
                MindtaggerTask.updateSchema schema
            .error (result) ->
                # FIXME revert tag to previous value
                console.error "commit failed for updates", updates
            .error (err) ->
                # prevent further changes to the UI with an error message
                $modal.open templateUrl: "mindtagger/commit-error.html"
                    .result.finally -> do $window.location.reload

.service 'MindtaggerUtils', (parsedArrayFilter) ->
    class MindtaggerUtils
        @progressBarClassForValue: (json, index) ->
            value = (try JSON.parse json) ? json
            switch value
                when true, "true"
                    "progress-bar-success"
                when false, "false"
                    "progress-bar-danger"
                when null, "null"
                    "progress-bar-warning"
                else
                    "progress-bar-info#{
                        if index % 2 == 0 then ""
                        else " progress-bar-striped"
                    }"



.directive 'mindtagger', ($compile) ->
    restrict: 'EAC', transclude: true, priority: 2000
    templateUrl: ($element, $attrs) -> "mindtagger/mode-#{$attrs.mode}.html"
    compile: (tElement, tAttrs) ->
        # Keep a clone of the template element so we can fill in the
        # mb-transclude selectors as we link later.
        templateToExpand = $(tElement).clone()
        ($scope, $element, $attrs, controller, $transclude) ->
            $transclude (clone, scope) ->
                # Fill the elements with mb-transclude selectors by finding
                # them in the clone, which is the element the directive is
                # originally used on.
                templateToExpand.find("[mb-transclude]").each ->
                    container = $ @
                    selector = container.attr("mb-transclude")
                    found = $(clone).find(selector).addBack(selector)
                    container.empty()
                    container.append found
                # Replace the element on DOM by compiling the whole expanded
                # template again.
                $element.empty()
                $element.append $compile(templateToExpand.children())(scope)

.directive 'mindtaggerNavbar', ->
    restrict: 'EAC', transclude: true
    templateUrl: "mindtagger/navbar.html"

.directive 'mindtaggerPagination', ->
    restrict: 'EAC', transclude: true
    templateUrl: "mindtagger/pagination.html"

