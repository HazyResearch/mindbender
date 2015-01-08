angular.module 'mindbenderApp.mindtagger', [
    'ui.bootstrap'
    'cfp.hotkeys'
    'mindbenderApp.mindtagger.wordArray'
    'mindbenderApp.mindtagger.arrayParsers'
    'mindbenderApp.mindtagger.tags.valueSet'
]

.config ($routeProvider) ->
    $routeProvider.when '/mindtagger',
        templateUrl: 'mindtagger/tasklist.html'
        controller: 'MindtaggerTaskListCtrl'
    $routeProvider.when '/mindtagger/:task',
        template: ({task}) -> """<div mindtagger-task="#{task}" mindtagger-task-keeps-cursor-visible></div>"""
        # TODO reloadOnSearch: no

.controller 'MindtaggerTaskListCtrl', ($scope, $http, $location, localStorageState) ->
    $scope.tasks ?= []
    $http.get "api/mindtagger/"
        .success (tasks) ->
            $scope.tasks = tasks
            if $location.path() is "/mindtagger" and tasks?.length > 0
                index = $location.search().index
                if index?
                    $location.path "/mindtagger/#{tasks[+index].name}"
                else
                    savedState = localStorageState "MindtaggerTask", $scope, [ "MindtaggerTask.name" ], no
                    $location.path "/mindtagger/#{savedState["MindtaggerTask.name"] ? tasks[0].name}"


.directive 'mindtaggerTask', (
    $templateRequest, $templateCache, $document, $compile, # for per-task template handling
) ->
    templateUrl: "mindtagger/task.html"
    controller: ($scope, $element, $attrs, MindtaggerTask, MindtaggerUtils
            $modal, $location, $timeout, $window,
            hotkeys, overrideDefaultEventWith, localStorageState) ->
        $scope.MindtaggerUtils = MindtaggerUtils
        $scope.taskName =
        @name = $attrs.mindtaggerTask
        # load current page and cursor position saved in localStorage
        savedState = localStorageState "MindtaggerTask_#{@name}", $scope, [
            "MindtaggerTask.currentPage"
            "MindtaggerTask.itemsPerPage"
            "MindtaggerTask.cursor.index"
            "MindtaggerTask.params"
            "MindtaggerTask.tagShortcutKey"
        ], no
        # make sure the search part of $location includes the required parameters
        search = $location.search()
        unless search.p? and search.s?
            $location.search "p", savedState["MindtaggerTask.currentPage"]  ? 1
            $location.search "s", savedState["MindtaggerTask.itemsPerPage"] ? 10
            for name,value of savedState["MindtaggerTask.params"] ? {}
                $location.search name, value
            return
        # passthru task parameters
        @params = {}
        for name,value of search when /^task_/.test name
            @params[name] = value
        # initialize or load task
        $scope.MindtaggerTask =
        task = MindtaggerTask.forName @name, @params,
            currentPage:  +$location.search().p
            itemsPerPage: +$location.search().s
            $scope: $scope
            tagShortcutKey: savedState["MindtaggerTask.tagShortcutKey"]
        task.cursorInitIndex ?= savedState["MindtaggerTask.cursor.index"]
        task.load()
            .catch (err) =>
                console.error "#{MindtaggerTask.name} not found"
                $modal.open templateUrl: "mindtagger/load-error.html", scope: $scope
                    .result.finally => $location.path("/mindtagger").search(index: 0)
            .finally ->
                do $scope.$digest
        do savedState.startWatching
        # remember the last task
        localStorageState "MindtaggerTask", $scope, [ "MindtaggerTask.name" ]

        # TODO replace with $watch (probably with a Ctrl?)
        $scope.commit = (item, tag) ->
            $timeout -> task.commitTagsOf item
        # pagination
        $scope.$watch ->
                $scope.MindtaggerTask.currentPage
            , (newPage) ->
                $location.search "p", newPage
                task.moveCursorTo 0 unless task.cursorInitIndex?
        $scope.$watch ->
                $scope.MindtaggerTask.itemsPerPage
            , (newPageSize) ->
                $location.search "s", newPageSize
                task.moveCursorTo 0 unless task.cursorInitIndex?

        $scope.keys = (obj) -> key for key of obj

        # map keyboard events
        hotkeys.bindTo $scope
            .add combo: "up",   description: "Move cursor to previous item", callback: (overrideDefaultEventWith -> $scope.MindtaggerTask.moveCursorBy -1)
            .add combo: "down", description: "Move cursor to next item",     callback: (overrideDefaultEventWith -> $scope.MindtaggerTask.moveCursorBy +1)

    link: ($scope, $element, $attrs) ->
        # load Mindtagger per-task template
        $templateRequest "mindtagger/tasks/#{$attrs.mindtaggerTask}/template.html"
            .then (template) ->
                # parse mindtagger template fragments (template[for=...]) from it
                parsedTemplate =
                    $($.parseHTML template, $document[0])
                        # TODO keep a list of valid template names and put all of them in $templateCache
                        .find("template")
                            .each (i, t) ->
                                $t = $(t)
                                $templateCache.put "mindtagger/tasks/#{$attrs.mindtaggerTask
                                    }/template-#{$t.attr("for")}.html", $t.html()
                            .remove()
                        .end()
                $element.prepend (($compile parsedTemplate) $scope)
            .catch ->
                # TODO use default template?

# a shorthand for inserting a named fragment of the Mindtagger task specific template
.directive 'mindtaggerInsertTemplate', ->
    template: (tElement, tAttrs) -> """
        <ng-include src="'mindtagger/tasks/'+ MindtaggerTask.name +
            '/template-#{tAttrs.mindtaggerInsertTemplate}.html'"></ng-include>
        """

# TODO fold this into mindtaggerTask directive's controller
.service 'MindtaggerTask', ($http, $q, $modal, $window, $timeout) ->
  class MindtaggerTask
    @allTasks: {}
    @qnameFor: (taskName, params) ->
        if params?
            for name,value of params
                taskName += " #{name}=#{value}"
        taskName
    @forName: (name, params, args) ->
        if (task = MindtaggerTask.allTasks[MindtaggerTask.qnameFor name, params])?
            task.init args
        else
            new MindtaggerTask name, params, args

    constructor: (@name, @params, args) ->
        @qname = MindtaggerTask.qnameFor @name, @params
        @currentPage = 1
        @itemsPerPage = 10
        @$scope = null
        @schema = {}
        @schemaTagsFixed = {}
        @itemsCount = null
        @init args
        MindtaggerTask.allTasks[@qname] = @

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
            # TODO consider using $resource instead
            ( $http.get "api/mindtagger/#{@name}/schema",
                    params: @params
                .success ({schema}) =>
                    @updateSchema schema
            )
            ( $http.get "api/mindtagger/#{@name}/items",
                    params: _.extend {}, @params,
                        offset: @itemsPerPage * (@currentPage - 1)
                        limit:  @itemsPerPage
                .success ({tags, items, itemsCount}) =>
                    @tags = tags
                    @items = items
                    @itemsCount = itemsCount
                    $timeout =>
                        # XXX we need to defer this so the mindtaggerTaskKeepsCursorVisible can scroll after the items are rendered
                        @moveCursorTo @cursorInitIndex
                        @cursorInitIndex = null
            )
        ]

    encodeParamsAsQueryString: (prefixIfNonEmpty = "") =>
        # gives task parameters encoded as query strings of URI
        qs = (
                "#{encodeURIComponent name}=#{encodeURIComponent value}" for name,value of @params
            ).join "&"
        if qs.length == 0 then ""
        else prefixIfNonEmpty + qs

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
        # TODO aggregate UI/presentation settings: tagShortcutKey, hidden states, export options
        # set default export options
        for attrName,attrSchema of @schema.items when attrName in @schema.itemKeys
            attrSchema.shouldExport ?= yes
        for tagName,tagSchema of @schema.tags
            tagSchema.shouldExport ?= yes
        do @assignDefaultShortcutKeys

    assignDefaultShortcutKeys: =>
        @tagShortcutKey ?= {}
        # first, import shortcut keys from schema
        for tagName,tagSchema of @schema.tags
            @tagShortcutKey[tagName] ?= tagSchema.shortcutKey
        # reset any conflicting shortcut keys
        # TODO resolve conflicts by skipping the longest common prefix
        shortcutKeysAssigned = {}
        for tagName,key of @tagShortcutKey
            if shortcutKeysAssigned[key]?
                @tagShortcutKey[tagName] = null
        # make sure all known tags have a shortcutKey derived from its name
        for tagName,tagSchema of @schema.tags when not @tagShortcutKey[tagName]?
            i = 0
            keyCandidates = tagName + "1234567890qwertyuiopasdfghjklzxcvbnm"
            while i < keyCandidates.length
                key = keyCandidates[i++].toLowerCase()
                break unless shortcutKeysAssigned[key]?
                key = null
            if key?
                @tagShortcutKey[tagName] = key
                shortcutKeysAssigned[key] = tagName
            else
                console.error "No key available for tag #{tagName}"

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
    moveCursorTo: (index = 0, mayNeedScroll = yes) =>
        if index?
            @cursor.index = index
            @cursor.item  = @items?[index]
            @cursor.tag   = @tags?[index]
            @cursor.mayNeedScroll = mayNeedScroll
        else
            @cursor.index =
            @cursor.item =
            @cursor.tag =
            @cursor.mayNeedScroll =
                null
    moveCursorBy: (increment = 0) =>
        return if increment == 0
        newIndex = @cursor.index + increment
        if newIndex < 0
            # page underflow
            if not @cursorInitIndex? and @currentPage > 1
                @currentPage--
                @cursorInitIndex = @itemsPerPage - 1
        else if newIndex >= @itemsPerPage
            # page overflow
            if not @cursorInitIndex? and @currentPage * @itemsPerPage < @itemsCount
                @currentPage++
                @cursorInitIndex = 0
        else
            @moveCursorTo newIndex

    # create/add tag
    addTagTo: (item, name, value, type = 'binary') =>
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
        $http.post "api/mindtagger/#{@name}/items#{@encodeParamsAsQueryString "?"}", updates
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
    # shorthands for manipulating tag of cursor item
    addTagToCursor: (args...) => @addTagTo @cursor.index, args...
    addTagToCursorAction: (name, value) =>
        (event) => @addTagToCursor name, value

    export: (format, tableName = "") =>
        $window.location.href = "api/mindtagger/#{@name}/tags.#{format
        }?tags=#{
            encodeURIComponent ((tagName for tagName,tagSchema of @schema.tags when tagSchema.shouldExport).join ",")
        }&attrs=#{
            encodeURIComponent ((attrName for attrName,attrSchema of @schema.items when attrSchema.shouldExport).join ",")
        }&table=#{
            tableName
        }#{
            @encodeParamsAsQueryString "&"
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


.service "localStorageState", ->
    (key, $scope, exprs, autoWatch = yes) ->
        console.log "localStorageState loading #{key}", localStorage[key]
        lastState = (try JSON.parse localStorage[key]) ? {}
        lastState.startWatching = ->
            $scope.$watchGroup exprs, (values) ->
                try localStorage[key] = JSON.stringify (_.object exprs, values)
        do lastState.startWatching if autoWatch
        lastState

.service 'overrideDefaultEventWith', ->
    (fn) -> (event, args...) -> do event.preventDefault; fn event, args...

.directive 'mindtaggerTaskKeepsCursorVisible', ($timeout) ->
    restrict: 'A'
    controller: ($scope, $element) ->
        $scope.$watch 'MindtaggerTask.cursor.index', (newIndex) ->
            return unless newIndex?
            $timeout ->
                if $scope.MindtaggerTask?.cursor?.mayNeedScroll
                    cursorItem = $element.find(".mindtagger-item").eq(newIndex)
                    cursorItem.offsetParent()?.scrollTo cursorItem.offset()?.top - 100
                delete $scope.MindtaggerTask?.cursor?.mayNeedScroll

# A factory for directive controllers that routes registered hotkey events to the item under cursor
.service 'MindtaggerTaskHotkeysDemuxCtrl', (hotkeys, overrideDefaultEventWith) ->
    class MindtaggerTaskHotkeysDemuxCtrl
        constructor: (@hotkeys) ->
            @numConnected = 0
            @$scope = null
        routeTo: (@$scope) =>
            # setter
        attach: ($scope) =>
            return unless $scope?
            $scope.$on "$destroy", => @detach $scope
            # route to the item while the cursor points to it
            if $scope.MindtaggerTask? and $scope.item?
                $scope.$watch =>
                        $scope.MindtaggerTask.cursor.item is $scope.item
                    , (isCursorOnTheItem) =>
                        @routeTo $scope if isCursorOnTheItem
            if @numConnected++ == 0
                for {combo,description,action, forEvent} in @hotkeys
                    hotkeys.add {
                        combo
                        description
                        callback: do (action) => (overrideDefaultEventWith => @$scope?.$eval action)
                        action: forEvent
                    }
        detach: ($scope) =>
            if --@numConnected == 0
                hotkeys.del combo for {combo} in @hotkeys

.directive "mindtaggerHotkey", (MindtaggerTaskHotkeysDemuxCtrl, $timeout) ->
    hotkeysDemux = {}

    restrict: 'A'
    scope: true
    link: ($scope, $element, $attrs) ->
        oldCombo = null
        initializeHotkeysDemux = ->
            combo = $attrs.mindtaggerHotkey
            action = "mindtaggerHotkeyPressed()"
            description = $attrs.mindtaggerHotkeyDescription ? $attrs.title
            $scope.mindtaggerHotkeyPressed = _.debounce ->
                    $timeout -> do $element.click
                , +($attrs.mindtaggerHotkeyRepeatEvery ? 200)
                , true # trigger on leading edge
            hotkeysDemux[combo] ?= new MindtaggerTaskHotkeysDemuxCtrl [
                { combo, action, description }
            ]
            hotkeysDemux[combo].attach $scope
            oldCombo = combo
        do initializeHotkeysDemux
        # watch to reflect any changes to combo
        $scope.$watch (-> $attrs.mindtaggerHotkey), (combo) ->
            return if combo is oldCombo
            hotkeysDemux[oldCombo].detach $scope
            do initializeHotkeysDemux

# A controller that sets item and tag to those of the cursor
.controller 'MindtaggerTaskCursorFollowCtrl', ($scope) ->
    $scope.$watch 'MindtaggerTask.cursor.index', (cursorIndex) ->
        cursor =
            if cursorIndex?
                $scope.MindtaggerTask.cursor
            else
                # XXX phantom item/tag for undefined cursors
                item: {}
                tag: {}
                # This can prevent other directives from breaking the $scope,
                # e.g., mindtaggerValueSetTag directive configured to work with
                # cursor item/tag attributes can create a bogus item/tag in its
                # scope shadowing this directive's item/tag if no phantom
                # objects are provided here.
        $scope.item = cursor.item
        $scope.tag = cursor.tag

.directive 'mindtagger', ($compile) ->
    restrict: 'E', transclude: true
    templateUrl: ($element, $attrs) -> "mindtagger/mode-#{$attrs.mode}.html"

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

.directive 'mindtaggerNoteTags', ->
    restrict: 'EA', transclude: true, templateUrl: "mindtagger/tags-note.html"

