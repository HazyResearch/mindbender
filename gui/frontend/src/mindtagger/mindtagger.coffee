angular.module 'mindbenderApp.mindtagger', [
    'ui.bootstrap'
]

.config ($routeProvider) ->
    $routeProvider.when '/mindtagger',
        templateUrl: 'mindtagger/tasklist.html',
        controller: 'MindtaggerTasksCtrl'
    $routeProvider.when '/mindtagger/:task',
        templateUrl: 'mindtagger/task.html',
        controller: 'MindtaggerItemsCtrl'

.controller 'MindtaggerTasksCtrl', ($scope, $http, $location) ->
    $scope.tasks ?= []
    $http.get "/api/mindtagger/"
        .success (tasks) ->
            $scope.tasks = tasks
            if $location.path() is "/mindtagger" and tasks?.length > 0
                $location.path "/mindtagger/#{tasks[0].name}"


.controller 'MindtaggerItemsCtrl', ($scope, $routeParams, MindtaggerUtils, commitTags, $http, $window, $timeout, $location) ->
    $scope.$utils = MindtaggerUtils
    $scope.taskName = $routeParams.task

    # TODO fold other variables into this
    $scope.MindtaggerTask =
        name: $routeParams.task

    $scope.items = null
    $scope.itemsCount = null
    $scope.tags = null

    $scope.itemKeys = null
    $scope.itemSchema = null
    $scope.tagsSchema = {}
    $scope.keys = (obj) -> key for key of obj

    $http.get "/api/mindtagger/#{$scope.taskName}/schema"
        .success ({presets, schema}) ->
            $scope.MindtaggerTask.presets = presets
            $scope.$presets = presets
            $scope.tagsSchema = schema.tags
            $scope.itemSchema = schema.items
            $scope.itemKeys = schema.itemKeys
            $http.get "/api/mindtagger/#{$scope.taskName}/items", {
                params:
                    offset: $scope.itemsPerPage * ($scope.currentPage - 1)
                    limit:  $scope.itemsPerPage
            }
                .success ({tags, items, itemsCount}) ->
                    $scope.tags = tags
                    $scope.items = items
                    $scope.itemsCount = itemsCount
        .error ->
            $location.path "/mindtagger"

    $scope.exportFormat = "sql"
    $scope.export = (format) ->
        $window.location.href = "/api/mindtagger/#{$scope.taskName}/tags.#{format ? $scope.exportFormat
        }?table=#{
            "" # TODO allow table name to be customized
        }&attrs=#{
            encodeURIComponent ((attrName for attrName,attrSchema of $scope.itemSchema when attrSchema.export).join ",")
        }&tags=#{
            encodeURIComponent ((tagName for tagName,tagSchema of $scope.tagsSchema when tagSchema.export).join ",")
        }"

    # cursor
    $scope.cursorIndex = 0
    $scope.moveCursorTo = (index) ->
        $scope.cursorIndex = index
    # pagination
    $scope.currentPage = +($location.search().p ? 1)
    $scope.itemsPerPage = +($location.search().s ? 10)
    $scope.pageChanged = -> $location.search "p", $scope.currentPage
    $scope.pageSizeChanged = _.debounce ->
        $scope.$apply ->
            $location.search "s", $scope.itemsPerPage
    , 750

    # create/add tag
    $scope.addTagToCurrentItem = (name, type = 'binary', value = true) ->
        console.log "adding tag to item under cursor", name, type, value
        tag = ($scope.tags[$scope.cursorIndex] ?= {})
        tag[name] = value
        $scope.$emit "tagChangedForCurrentItem"
    $scope.commit = -> $timeout ->
        $scope.$emit "tagChangedForCurrentItem"
    $scope.$on "tagChangedForCurrentItem", (event) ->
        index = $scope.cursorIndex
        item = $scope.items[index]
        tag = $scope.tags[index]
        itemIndex = index +
            ($scope.currentPage - 1) * $scope.itemsPerPage
        console.log "some tags of current item (##{itemIndex}) changed, committing", tag
        key =
            # use itemKeys if available
            if $scope.itemKeys?.length > 0
                (item[k] for k in $scope.itemKeys).join "\t"
            else
                itemIndex
        updates = [
            { tag, key }
        ]
        commitTags $scope, updates

.controller 'MindtaggerTagsCtrl', ($scope) ->
    index = $scope.$parent.$index
    $scope.tag = ($scope.$parent.tags[index] ?= {})


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


.directive 'mindtaggerWordArray', ->
    restrict: 'EAC', transclude: true
    priority: 1
    scope:
        mindtaggerWordArray: '='
        arrayFormat: '@'
    template: """
        <span class="mindtagger-word"
            ng-repeat="word in mindtaggerWordArray | parsedArray:arrayFormat track by $index">
            {{word}}
            <span ng-transclude></span>
        </span>
    """

.directive 'mindtaggerHighlightWords', (parsedArrayFilter) ->
    restrict: 'EAC'
    scope:
        from: '='
        to: '='
        indexArray: '='
    compile: (tElement, tAttrs) ->
        arrayFormat = tAttrs.arrayFormat ? "json"
        style = tElement.attr("style")
        # remove style
        ($scope, $element) ->
            $element.attr("style", null)
            $scope.$watch (-> JSON.stringify [$scope.indexArray, $element.find(".mindtagger-word").length]), ->
                words = $element.find(".mindtagger-word")
                wordsToHighlight =
                    if $scope.from? and $scope.to? and 0 <= +$scope.from <= +$scope.to < words.length
                         words.slice +$scope.from-1, +$scope.to
                    else if $scope.indexArray?.length > 0
                        indexes = (+i for i in parsedArrayFilter $scope.indexArray, arrayFormat)
                        $().add (words.eq(i) for i in indexes)...
                if wordsToHighlight?.length > 0
                    # apply style
                    console.log style, wordsToHighlight
                    wordsToHighlight.attr("style", (i, css = "") -> css + style)


# a handy filter for parsing Postgres ARRAYs serialized in CSV outputs
.filter 'parsedPostgresArray', ->
    (text, index) ->
        # extract the csv-like piece in the text
        return null unless text? and (m = /^{(.*)}$/.exec text?.trim())?
        csvLikeText = m[1]
        # convert backslash escapes to standard CSV escapes
        csvText = csvLikeText
            .replace /\\(.)/g, "$1"
            .replace /\\(.)/g, (m, c) ->
                switch c
                    when '"'
                        '""'
                    else
                        c
        array =
            try $.csv.toArray csvText
            catch err
                console.error "csv parse error", text, csvLikeText, csvText, err
                [text]
        if index?
            array[index]
        else
            array

.filter 'parsedPythonArray', ->
    (text, index) ->
        return null unless text? and (m = /^\[(.*)\]$/.exec text?.trim())?
        array = []
        headTailRegex = ///^
                '([^']*)'  # head # FIXME handle escaping problem
                (, (.*))?  # optional tail
            $///
        remainder = m[1].trim()
        while remainder?.length > 0
            if (m = headTailRegex.exec remainder)?
                array.push m[1]
                remainder = m[3]?.trim()
            else
                return [text]
        array

.filter 'parsedArray', (parsedPostgresArrayFilter, parsedPythonArrayFilter) ->
    (text, format) ->
        switch format
            when "postgres"
                parsedPostgresArrayFilter text
            when "python"
                parsedPythonArrayFilter text
            else # when "json"
                try JSON.parse text
                catch err
                    console.error err
                    [text]

.service 'commitTags', ($http, $modal, $window) ->
    ($scope, updates) ->
        $http.post "/api/mindtagger/#{$scope.taskName}/items", updates
            .success (schema) ->
                console.log "committed tags updates", updates
                $scope.tagsSchema = schema.tags
                $scope.itemSchema = schema.items
            .error (result) ->
                # FIXME revert tag to previous value
                console.error "commit failed for updates", updates
            .error (err) ->
                # prevent further changes to the UI with an error message
                $modal.open templateUrl: "mindtagger/commit-error.html"
                    .result.finally -> do $window.location.reload

.service 'MindtaggerUtils', (parsedArrayFilter) ->
    class MindtaggerUtils
        @findAllKeys: (rows) ->
            merged = {}
            angular.extend merged, rows...
            key for key of merged

        # for word-array's style_indexes_columns
        @valueOfArrayColumnContaining: (columnMap, item, element) ->
            if columnMap? and columnMap instanceof Object
                for column,[format, value] of columnMap
                    array = parsedArrayFilter item[column], format
                    # find and return immediately if found without conversion
                    return value if element in array
                    # then, look for identical String representation
                    for e in array when (String e) is (String element)
                        return value
            return null

        @valueOfRangeColumnContaining: (rangeColumns, item, element) ->
            if rangeColumns? and rangeColumns instanceof Array
                for [columnStart, columnEnd, value] in rangeColumns
                    if +item[columnStart] <= +element <= +item[columnEnd]
                        return value
            return null

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

