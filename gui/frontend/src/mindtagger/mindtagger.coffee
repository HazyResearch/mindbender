angular.module 'mindbender.mindtagger', [
    'ui.bootstrap'
    'cfp.hotkeys'
    'mindbender.mindtagger.wordArray'
    'mindbender.mindtagger.arrayParsers'
    'mindbender.mindtagger.tags.parametric'
]

.config ($routeProvider) ->
    $routeProvider.when '/mindtagger',
        brand: "Mindtagger", brandIcon: "tags"
        title: "Mindtagger - DeepDive"
        templateUrl: 'mindtagger/tasklist.html'
        controller: 'MindtaggerTaskListCtrl'
    $routeProvider.when '/mindtagger/:task',
        brand: "Mindtagger", brandIcon: "tags"
        title: "Mindtagger {{task}} - DeepDive"
        template: ({task}) -> """<div mindtagger-task="#{task}" mindtagger-task-keeps-cursor-visible></div>"""
        # TODO reloadOnSearch: no

.controller 'MindtaggerTaskListCtrl', ($scope, $rootScope, $http, $location, localStorageState) ->
    $rootScope.mindtaggerTasks ?= []
    $http.get "api/mindtagger/"
        .success (tasks) ->
            $rootScope.mindtaggerTasks = tasks
            if $location.path() is "/mindtagger" and tasks?.length > 0
                index = $location.search().index
                if index?
                    $location.path "/mindtagger/#{tasks[+index].name}"
                else
                    savedState = localStorageState "MindtaggerTask", $scope, [ "MindtaggerTask.name" ], no
                    $location.path "/mindtagger/#{savedState["MindtaggerTask.name"] ? tasks[0].name}"


.directive 'mindtaggerTask', () ->
    templateUrl: "mindtagger/task.html"
    controller: ($scope, $element, $attrs, MindtaggerTask, MindtaggerUtils
            $modal, $location, $timeout, $window,
            hotkeys, overrideDefaultEventWith, localStorageState) ->
        $scope._ = _  # See: http://underscorejs.org
        $scope.MindtaggerUtils = MindtaggerUtils
        $scope.taskName =
        @name = $attrs.mindtaggerTask
        # load current page and cursor position saved in localStorage
        savedState = localStorageState "MindtaggerTask_#{@name}", $scope, [
            "MindtaggerTask.groupFilter"
            "MindtaggerTask.currentPage"
            "MindtaggerTask.itemsPerPage"
            "MindtaggerTask.cursor.index"
            "MindtaggerTask.params"
            "MindtaggerTask.tagOptions"
        ], no
        # make sure the search part of $location includes the required parameters
        search = $location.search()
        needsReload = no
        unless search.g?
            $location.search "g", savedState["MindtaggerTask.groupFilter"] ? ""
            needsReload = yes
        unless search.p? and search.s?
            $location.search "p", savedState["MindtaggerTask.currentPage"]  ? 1
            $location.search "s", savedState["MindtaggerTask.itemsPerPage"] ? 10
            needsReload = yes
        for name,value of savedState["MindtaggerTask.params"] ? {} when not search[name]?
            $location.search name, value
            needsReload = yes
        return if needsReload
        # passthru task parameters
        @params = {}
        for name,value of search when /^task_/.test name
            @params[name] = value
        # initialize or load task
        $scope.MindtaggerTask =
        @task =
        task = MindtaggerTask.forName @name, @params,
            tagOptions: savedState["MindtaggerTask.tagOptions"]
            groupFilter:  $location.search().g
            currentPage:  +$location.search().p
            itemsPerPage: +$location.search().s
            $scope: $scope
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
        $scope.$watch ->
                $scope.MindtaggerTask.groupFilter
            , (newGroupFilter) ->
                $location.search "g", newGroupFilter
                task.moveCursorTo 0 unless task.cursorInitIndex?

        $scope.keys = (obj) -> key for key of obj

        # map keyboard events
        hotkeys.bindTo $scope
            .add combo: "up",   description: "Move cursor to previous item", callback: (overrideDefaultEventWith -> $scope.MindtaggerTask.moveCursorBy -1)
            .add combo: "down", description: "Move cursor to next item",     callback: (overrideDefaultEventWith -> $scope.MindtaggerTask.moveCursorBy +1)

# TODO fold this into mindtaggerTask directive's controller
.service 'MindtaggerTask', ($http, $q, $modal, $window, $timeout, hotkeys) ->
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
            data: {}
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
                        group: @groupFilter
                        offset: @itemsPerPage * (@currentPage - 1)
                        limit:  @itemsPerPage
                .success ({tags, items, itemsCount, grouping}) =>
                    @tags = tags
                    @items = items
                    @itemsCount = itemsCount
                    @grouping = grouping
                    $timeout =>
                        # XXX we need to defer this so the mindtaggerTaskKeepsCursorVisible can scroll after the items are rendered
                        @moveCursorTo @cursorInitIndex
                        @cursorInitIndex = null
            )
        ]

    loadGroupNames: (q) =>
        $http.get "api/mindtagger/#{@name}/groups",
                params: _.extend {}, @params,
                    q: q
            .then (res) =>
                res.data
    updateFilter: (q) =>
        @groupFilter = q
        @currentPage = 1

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
        # set UI/presentation settings: shortcutKey, hidden states, export options
        do @updateTagOptions
        # set default export options for item attributes
        for attrName,attrSchema of @schema.items when attrName in @schema.itemKeys
            attrSchema.shouldExport ?= yes

    updateTagOptions: (tags = @schema.tags) =>
        @tagOptions ?= {}
        # first, import from schema (shortcutKey, hidden, ...)
        optionsToImportFromSchema = [
            "shortcutKey"
            "hidden"
        ]
        for tagName,tagSchema of tags
            tagOpt = @tagOptions[tagName] ?= {}
            for opt in optionsToImportFromSchema
                tagOpt[opt] ?= tagSchema[opt]
        # set default export options
        for tagName,tagOpt of @tagOptions
            tagOpt.shouldExport ?= yes
        @assignDefaultShortcutKeys tags

    assignDefaultShortcutKeys: (tags = @schema.tags) =>
        # reset any conflicting shortcut keys
        # TODO resolve conflicts by skipping the longest common prefix
        shortcutKeysAssigned = {}
        for tagName,tagOpt of @tagOptions
            key = tagOpt.shortcutKey
            if shortcutKeysAssigned[key]? or (hotkeys.get key)?
                tagOpt.shortcutKey = null
            else
                shortcutKeysAssigned[key] = tagName
        # make sure all known tags have a shortcutKey derived from its name
        for tagName,tagOpt of @tagOptions when not tagOpt.shortcutKey
            i = 0
            keyCandidates = tagName + "qwertyuiopasdfghjklzxcvbnm1234567890"
            while i < keyCandidates.length
                key = keyCandidates[i++].toLowerCase()
                break unless shortcutKeysAssigned[key]?
                key = null
            if key?
                tagOpt.shortcutKey = key
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
        # reset cursor-specific data upon movement
        @cursor.data = {} unless index == @cursor.index
        if index? and 0 <= index < @items?.length
            @cursor.index = index
            @cursor.item  = @items?[index]
            @cursor.tag   = @tags?[index]
            @cursor.mayNeedScroll = mayNeedScroll
        else
            console.warn "resetting cursor to null", index
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
        else if 0 <= newIndex < @items?.length
            @moveCursorTo newIndex

    # create/add tag
    addTagTo: (item, name, value, type = 'simple') =>
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
            encodeURIComponent ((tagName for tagName,tagOpt of @tagOptions when tagOpt.shouldExport).join ",")
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
        lastState = _.object exprs, (try JSON.parse localStorage["#{key} #{expr}"] for expr in exprs)
        lastState.startWatching = ->
            for expr in exprs
                do (expr) ->
                    $scope.$watch expr, (value) ->
                        #console.log "localStorageState storing new #{key} #{expr}", JSON.stringify value
                        try localStorage["#{key} #{expr}"] = JSON.stringify value
                    , true # use angular.equals for deeper equality check
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
                data: {}
                # This can prevent other directives from breaking the $scope,
                # e.g., mindtaggerValueSetTag directive configured to work with
                # cursor item/tag attributes can create a bogus item/tag in its
                # scope shadowing this directive's item/tag if no phantom
                # objects are provided here.
        $scope.item = cursor.item
        $scope.tag = cursor.tag
        $scope.cursor = cursor.data

# an alternative to ngInclude for showing error messages when inclusion fails
.directive 'mindtaggerInclude', (
    $templateRequest, $document, $compile, # for mode template inclusion
) ->
    restrict: 'EA', transclude: true
    link: ($scope, $element, $attrs, controller, $transclude) ->
        url = $scope.$eval ($attrs.mindtaggerInclude ? $attrs.src)
        # load template for the mode
        $templateRequest url
            .then (template) ->
                parsedTemplate = $($.parseHTML template, $document[0])
                $element.prepend parsedTemplate  # XXX this first prepend is to make sure parents are accessible during the following template's compilation
                $element.prepend (($compile parsedTemplate) $scope)
            .catch ->
                # display an error
                $element.prepend $("""
                    <div class="alert alert-danger"></div>
                    """).append $transclude()

# top-level element in task templates (which can be nested as well)
.directive 'mindtagger', () ->
    restrict: 'E'
    compile: (tElement, tAttrs) ->
        tElement.prepend """
            <div mindtagger-include="'mindtagger/mode-#{tAttrs.mode}.html'">
                <strong>
                    <code>#{tAttrs.mode}</code>: mode unsupported by Mindtagger
                </strong>
            </div>
            """

# a shorthand for inserting a named fragment of the Mindtagger task specific template
.directive 'mindtaggerInsertTemplate', ($compile, $document) ->
    restrict: 'EA'
    link: ($scope, $element, $attrs) ->
        # find the template with the name under the closest mindtagger directive element
        templateName = $attrs.mindtaggerInsertTemplate ? $attrs.src
        template = $element.parents("mindtagger")
            .children("template[for=#{templateName}]").eq(0)
        if template.length > 0
            # clone the contents of the template
            instance = $($.parseHTML template.html(), $document[0])
            # attach it outside the current mindtagger directive element
            # to support recursive use of mindtaggerInsertTemplate inside the template with the same name
            template.closest("mindtagger").after instance
            # compile and prepend the instantiated template
            $element.contents().remove()
            $element.prepend ($compile instance) $scope
        else
            # don't leave empty tags
            numAttrs = (a for a of $attrs when not a.match /^\$/).length
            if $element.contents().length == 0 and numAttrs <= 1
                $element.remove()


.directive 'mindtaggerNavbarTop', ->
    restrict: 'EA', transclude: true, templateUrl: "mindtagger/navbar-top.html"
.directive 'mindtaggerNavbarBottom', ->
    restrict: 'EA', transclude: true, templateUrl: "mindtagger/navbar-bottom.html"

.directive 'mindtaggerItem', ($timeout) ->
    restrict: 'EA'
    link: ($scope, $element, $attrs) ->
        $scope.$watch $attrs.mindtaggerItem, (item) ->
            $scope.item = item
            $scope.itemIndex = $scope.MindtaggerTask.indexOf item
            $scope.tag = $scope.MindtaggerTask.tagOf $scope.itemIndex
        $scope.$watch "MindtaggerTask.cursor.index", (newCursorIndex) ->
            $scope.cursor =
                if newCursorIndex == $scope.itemIndex
                    $scope.MindtaggerTask.cursor.data
        $element.on "mousedown", (e) ->
            $scope.$eval "MindtaggerTask.moveCursorTo(itemIndex, false)"
            $timeout -> do $scope.$digest
        $element.addClass "mindtagger-item"

.directive 'mindtaggerItemDetails', ->
    restrict: 'EA', transclude: true, templateUrl: "mindtagger/item-details.html"

.directive 'mindtaggerAdhocTags', ->
    restrict: 'EA', transclude: true, templateUrl: "mindtagger/tags-adhoc.html"
    controller: ($scope, $element, $attrs) ->
        $scope.$watch $attrs.withValue, (newValue) ->
            $scope.tagValue = newValue

.directive 'mindtaggerNoteTags', ->
    restrict: 'EA', transclude: true, templateUrl: "mindtagger/tags-note.html"
