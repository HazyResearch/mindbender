FALLBACK_PRESETS = [['_default']]
directiveForIncludingPresetTemplate = (templateName) ->
    restrict: 'EA'
    scope: true
    controller: ($scope, MindtaggerUtils) ->
        $scope.$utils = MindtaggerUtils
        # pop the preset stack to resolve the current preset
        [[presetName, $scope.$preset], $scope.$presets...] =
            if $scope.$parent.$presets?.length > 0
                $scope.$parent.$presets
            else
                # fallback to _default preset if the stack is empty but a render is forced
                FALLBACK_PRESETS
        $scope.$preset ?= {}
        angular.extend $scope.$preset,
            $name: presetName
            $path: "/mindtagger/preset/#{presetName}"
    template: """
        <span ng-include="$preset.$path + '/#{templateName}-template.html'"></span>
        """

angular.module 'mindbenderApp.mindtagger', [
    'ui.bootstrap'
]

.config ($routeProvider) ->
    $routeProvider.when '/mindtagger',
        template: 'mindtagger/tasklist.html',
        controller: 'MindtaggerTasksCtrl'
    $routeProvider.when '/mindtagger/:task',
        templateUrl: 'mindtagger/task.html',
        controller: 'MindtaggerItemsCtrl'

.controller 'MindtaggerTasksCtrl', ($scope, $http, $location) ->
    $scope.tasks ?= []
    $http.get "/api/mindtagger/"
        .success (tasks) ->
            $scope.tasks = tasks
            if $location.path() is "/mindtagger"
                $location.path "/mindtagger/#{tasks[0].name}"


.controller 'MindtaggerItemsCtrl', ($scope, $routeParams, commitTags, $http, $window, $location) ->
    $scope.taskName = $routeParams.task

    $scope.$presets = FALLBACK_PRESETS
    $scope.items = null
    $scope.itemsCount = null
    $scope.tags = null

    $scope.tagsSchema = {}
    $scope.keys = (obj) -> key for key of obj

    $http.get "/api/mindtagger/#{$scope.taskName}/schema"
        .success ({presets, schema}) ->
            $scope.$presets = presets
            $scope.tagsSchema = schema.tags
            $scope.itemSchema = schema.items
            $http.get "/api/mindtagger/#{$scope.taskName}/items", {
                params:
                    offset: $scope.itemsPerPage * ($scope.currentPage - 1)
                    limit:  $scope.itemsPerPage
            }
                .success ({tags, items, itemsCount}) ->
                    $scope.tags = tags
                    $scope.items = items
                    $scope.itemsCount = itemsCount

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

    $scope.$on "tagChanged", ->
        # update schema
        console.log "some tags changed"

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
        index = $scope.cursorIndex +
            ($scope.currentPage - 1) * $scope.itemsPerPage
        console.log "adding tag to item #{index}", name, type, value
        tag = ($scope.tags[index] ?= {})
        tag[name] = value
        $scope.$emit "tagChanged"
        commitTags $scope, tag, index

.controller 'MindtaggerTagsCtrl', ($scope, commitTags, $timeout, $modal, $window) ->
    itemIndex = $scope.$parent.$index +
            ($scope.$parent.currentPage - 1) * $scope.$parent.itemsPerPage
    $scope.tag = ($scope.$parent.tags[itemIndex] ?= {})
    $scope.commit = (tag) -> $timeout ->
        $scope.$parent.cursorIndex = $scope.$parent.$index
        $scope.$emit "tagChanged"
        commitTags $scope.$parent, tag, itemIndex
            .error (err) ->
                # prevent further changes to the UI with an error message
                $modal.open templateUrl: "mindtagger/commit-error.html"
                    .result.finally -> do $window.location.reload

.directive 'mbRenderItem', ->
    directiveForIncludingPresetTemplate 'item'
.directive 'mbRenderTags', ->
    directiveForIncludingPresetTemplate 'tags'

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

.service 'commitTags', ($http) ->
    ($scope, tag, index) ->
        $http.post "/api/mindtagger/#{$scope.taskName}/items", {index, tag}
            .success (schema) ->
                console.log "committed tags for item #{index}", tag
                $scope.tagsSchema = schema.tags
                $scope.itemSchema = schema.items
            .error (result) ->
                # FIXME revert tag to previous value
                console.error "commit failed for item #{index}", tag

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

