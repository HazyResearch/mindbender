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


.controller 'MindtaggerTaskCtrl', ($scope, $routeParams, MindtaggerTask, $timeout, $location) ->
    $scope.MindtaggerTask =
    task = MindtaggerTask.forName $routeParams.task,
            currentPage: +($location.search().p ? 1)
            itemsPerPage: +($location.search().s ? 10)
            $scope: $scope
    task.load()
        .catch (err) ->
            console.error "#{MindtaggerTask.name} not found"
            $location.path "/mindtagger"
        .finally ->
            do $scope.$digest

    # TODO replace with $watch (probably with a Ctrl?)
    $scope.commit = (item, tag) ->
        $timeout -> task.commitTagsOf item
    # pagination
    $scope.$watch ->
            $scope.MindtaggerTask.currentPage
        , (newPage) ->
            $location.search "p", newPage
    $scope.$watch ->
            $scope.MindtaggerTask.itemsPerPage
        , (newPageSize) ->
            $location.search "s", newPageSize

    $scope.keys = (obj) -> key for key of obj

# A controller that sets item and tag to those of the cursor
.controller 'MindtaggerTaskCursorFollowCtrl', ($scope) ->
    $scope.$watch 'MindtaggerTask.cursor.index', (cursorIndex) ->
        cursor = $scope.MindtaggerTask.cursor
        $scope.item = cursor.item
        $scope.tag = cursor.tag

.service 'MindtaggerTask', ($http, $q, $modal, $window) ->
  class MindtaggerTask
    @allTasks: {}
    @forName: (name, args) ->
        if (task = MindtaggerTask.allTasks[name])?
            task.init args
        else
            new MindtaggerTask name, args

    constructor: (@name, args) ->
        @currentPage = 1
        @itemsPerPage = 10
        @$scope = null
        @schema = {}
        @schemaTagsFixed = {}
        @itemsCount = null
        @init args
        MindtaggerTask.allTasks[name] = @

    init: (args) =>
        _.extend @, args
        @tags = null
        @items = null
        @cursor =
            index: null
            item: null
            tag: null
        @

    load: =>
        $q.all [
            ( $http.get "/api/mindtagger/#{@name}/schema"
                .success ({schema}) =>
                    @updateSchema schema
            )
            ( $http.get "/api/mindtagger/#{@name}/items",
                    params:
                        offset: @itemsPerPage * (@currentPage - 1)
                        limit:  @itemsPerPage
                .success ({tags, items, itemsCount}) =>
                    @tags = tags
                    @items = items
                    @itemsCount = itemsCount
                    @moveCursorTo 0
            )
        ]

    defineTags: (tagsSchema...) =>
        console.log "defineTags", tagsSchema...
        _.extend @schemaTagsFixed, tagsSchema...
        do @updateSchema
    updateSchema: (schema...) =>
        _.extend @schema, schema... if schema.length > 0
        # TODO a recursive version of _.extend
        @schema.tags ?= {}
        for tagName,tagSchema of @schemaTagsFixed
            _.extend (@schema.tags[tagName] ?= {}), tagSchema
        # set default export options
        for attrName,attrSchema of @schema.items when attrName in @schema.itemKeys
            attrSchema.shouldExport ?= yes
        for tagName,tagSchema of @schema.tags
            tagSchema.shouldExport ?= yes

    indexOf: (item) =>
        if (typeof item) is "number" then item
        else @items?.indexOf item
    keyFor: (item) =>
        # use itemKeys if available
        if @schema.itemKeys?.length > 0
            item = @items[item] if (typeof item) is "number"
            (item[k] for k in @schema.itemKeys).join "\t"
        else
            index = @indexOf item
            index + (@currentPage - 1) * @itemsPerPage
    tagOf: (item) => @tags[@indexOf item] ?= {}

    # cursor
    moveCursorTo: (index) =>
        @cursor.index = index
        @cursor.item  = @items[index]
        @cursor.tag   = @tags[index]

    # create/add tag
    addTagToCursor: (args...) => @addTagTo @cursor.index, args...
    addTagTo: (item, name, type = 'binary', value = true) =>
        console.log "adding tag to item #{@keyFor item}", name, type, value
        index = @indexOf item
        tag = (@tags[index] ?= {})
        tag[name] = value
        @commitTagsOf index
    commitTagsOf: (items...) =>
        updates =
            for item in items
                index = @indexOf item
                {
                    tag: @tags[index]
                    key: @keyFor item
                }
        $http.post "/api/mindtagger/#{@name}/items", updates
            .success (schema) =>
                console.log "committed tags updates", updates
                @updateSchema schema
            .error (result) =>
                # FIXME revert tag to previous value
                console.error "commit failed for updates", updates
            .error (err) =>
                # prevent further changes to the UI with an error message
                $modal.open templateUrl: "mindtagger/commit-error.html"
                    .result.finally => do $window.location.reload

    export: (format) =>
        $window.location.href = "/api/mindtagger/#{@name}/tags.#{format
        }?table=#{
            "" # TODO allow table name to be customized
        }&attrs=#{
            encodeURIComponent ((attrName for attrName,attrSchema of @schema.items when attrSchema.shouldExport).join ",")
        }&tags=#{
            encodeURIComponent ((tagName for tagName,tagSchema of @schema.tags when tagSchema.shouldExport).join ",")
        }"



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
    restrict: 'E', transclude: true, priority: 2000
    templateUrl: ($element, $attrs) -> "mindtagger/mode-#{$attrs.mode}.html"
    compile: (tElement, tAttrs) ->
        # Keep a clone of the template element so we can fill in the
        # mb-transclude selectors as we link later.
        templateToExpand = tElement.clone()
        ($scope, $element, $attrs, controller, $transclude) ->
            $transclude (clone, scope) ->
                # Fill the elements with mb-transclude selectors by finding
                # them in the clone, which is the element the directive is
                # originally used on.
                t = templateToExpand.clone()
                t.find("[mb-transclude]").each ->
                    container = $ @
                    selector = container.attr("mb-transclude")
                    container.empty()
                    clone.find(selector).addBack(selector).clone().appendTo(container)
                # Replace the element on DOM by compiling the whole expanded
                # template again.
                $element.empty()
                $element.append $compile(t.children())(scope)

.directive 'mindtaggerNavbar', ->
    restrict: 'EA', transclude: true, templateUrl: "mindtagger/navbar.html"
.directive 'mindtaggerPagination', ->
    restrict: 'EA', transclude: true, templateUrl: "mindtagger/pagination.html"

.directive 'mindtaggerItemDetails', ->
    restrict: 'EA', transclude: true, templateUrl: "mindtagger/item-details.html"

.directive 'mindtaggerAdhocTags', ->
    restrict: 'EA', transclude: true, templateUrl: "mindtagger/tags-adhoc.html"
    controller: ($scope, $element, $attrs) ->
        $scope.$watch $attrs.withValue, (newValue) ->
            $scope.tagValue = newValue
.directive 'mindtaggerValueSetTag', ($parse, $interpolate) ->
    restrict: 'A', transclude: true, templateUrl: "mindtagger/tags-value-set.html"
    controller: ($scope, $element, $attrs) ->
        $scope.$watch $attrs.mindtaggerValueSetTag, (newValue) -> $scope.tagName = newValue
        tagValueModel = $parse $attrs.withValue
        $scope.$watch $attrs.withValue, (newValue) -> $scope.tagValue = newValue
        $scope.toggleValueFromSet = (tag, tagName, tagValue) ->
            if tag? and tagValue?
                jsonTagValue = JSON.stringify tagValue
                set = tag[tagName] ?= []
                newSet = (v for v in set when jsonTagValue isnt (JSON.stringify v))
                newSet.push tagValue if newSet.length == set.length
                tag[tagName] = newSet
        $scope.containsValueInSet = (tag, tagName, tagValue) ->
            if tagValue? and tag?[tagName]?
                jsonTagValue = JSON.stringify tagValue
                for v in tag[tagName] when jsonTagValue is (JSON.stringify v)
                    return yes
            no
        $scope.setTheValue = (tagValue) ->
            tagValueModel.assign $scope, tagValue
            $timeout -> $scope.$digest()
        # custom rendering of each value
        # TODO support html template
        # html = $element.find("[type='text/ng-template']").html()
        # exp = if html? then $interpolate html
        #$scope.renderValueOfSet =
        #    if exp?
        #        (value) -> exp (_.extend {value}, $scope)
        #    else
        #        (value) -> html ? value
        renderEachValueExp =
            if $attrs.renderEachValue then $interpolate $attrs.renderEachValue
        $scope.renderValueOfSet =
            if renderEachValueExp?
                (value) -> renderEachValueExp (_.extend {value}, $scope)
            else
                (value) -> value
.directive 'mindtaggerNoteTags', ->
    restrict: 'EA', transclude: true, templateUrl: "mindtagger/tags-note.html"

