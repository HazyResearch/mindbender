findAllKeys = (rows) ->
    merged = {}
    angular.extend merged, rows...
    key for key of merged

FALLBACK_PRESETS = [['_default']]
directiveForIncludingPresetTemplate = (templateName) ->
    restrict: 'EA'
    scope: true
    controller: ($scope) ->
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
        templateUrl: 'mindtagger/tasklist.html',
        controller: 'MindtaggerTasksCtrl'
    $routeProvider.when '/mindtagger/:task',
        templateUrl: 'mindtagger/task.html',
        controller: 'MindtaggerItemsCtrl'

.controller 'MindtaggerTasksCtrl', ($scope, $http) ->
    $scope.tasks ?= []
    $http.get "/api/mindtagger/"
        .success (tasks) ->
            $scope.tasks = tasks


.controller 'MindtaggerItemsCtrl', ($scope, $routeParams, commitTags, $http, $window, $location) ->
    $scope.taskName = $routeParams.task

    $scope.$presets ?= FALLBACK_PRESETS
    $scope.items ?= []
    $scope.tags ?= []

    $scope.tagsSchema ?= {}
    $scope.keys = (obj) -> key for key of obj

    $http.get "/api/mindtagger/#{$scope.taskName}/schema"
        .success ({presets, schema}) ->
            $scope.$presets = presets
            $scope.tagsSchema = schema.tags
            $scope.itemSchema = schema.items
            $http.get "/api/mindtagger/#{$scope.taskName}/items"
                .success ({tags, items}) ->
                    $scope.items = items ? []
                    $scope.tags = tags ? []

    $scope.exportFormat = "sql"
    $scope.export = (format) ->
        $window.location.href = "/api/mindtagger/#{$scope.taskName}/tags.#{format ? $scope.exportFormat}?keys=#{
            encodeURIComponent ((attrName for attrName,attrSchema of $scope.itemSchema when attrSchema.export).join ",")
        }"
        # TODO table=

    $scope.$on "tagChanged", ->
        # update schema
        console.log "some tags changed"

    # cursor
    $scope.cursorIndex = 0
    $scope.moveCursorTo = (index) ->
        $scope.cursorIndex = index
    # pagination
    $scope.currentPage = +($location.search().p ? 1)
    $scope.itemsPerPage = 10
    $scope.itemsOnCurrentPage = ->
        a = $scope.itemsPerPage * ($scope.currentPage - 1)
        b = $scope.itemsPerPage * ($scope.currentPage    )
        $scope.items[a...b]
    $scope.pageChanged = ->
        #$location.search 'p', $scope.currentPage

    # create/add tag
    $scope.addTagToCurrentItem = (name, type = 'binary', value = true) ->
        index = $scope.cursorIndex +
            ($scope.currentPage - 1) * $scope.itemsPerPage
        console.log "adding tag to item #{index}", name, type, value
        tag = ($scope.tags[index] ?= {})
        tag[name] = value
        $scope.$emit "tagChanged"
        commitTags $scope, tag, index

.controller 'MindtaggerTagsCtrl', ($scope, commitTags, $timeout) ->
    itemIndex = $scope.$parent.$index +
            ($scope.$parent.currentPage - 1) * $scope.$parent.itemsPerPage
    $scope.tag = ($scope.$parent.tags[itemIndex] ?= {})
    $scope.commit = (tag) -> $timeout ->
        $scope.$parent.cursorIndex = $scope.$parent.$index
        $scope.$emit "tagChanged"
        commitTags $scope.$parent, tag, itemIndex
        # TODO handle error

.directive 'mbRenderItem', ->
    directiveForIncludingPresetTemplate 'item'
.directive 'mbRenderTags', ->
    directiveForIncludingPresetTemplate 'tags'

# a handy filter for parsing Postgres ARRAYs serialized in CSV outputs
.filter 'parsedPostgresArray', ->
    (text, index) ->
        # extract the csv-like piece in the text
        return null unless (m = /^{(.*)}$/.exec text?.trim())?
        csvLikeText = m[1]
        # convert backslash escapes to standard CSV escapes
        csvText = csvLikeText
            .replace /\\(.)/g, (m, c) ->
                switch c
                    when '"'
                        '""'
                    else
                        c
        array = $.csv.toArray csvText
        if index?
            array[index]
        else
            array

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

