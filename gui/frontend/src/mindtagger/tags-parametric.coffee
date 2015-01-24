angular.module 'mindbenderApp.mindtagger.tags.parametric', [
]

.directive 'mindtaggerParametricTags', ($parse, $interpolate, MindtaggerTaskHotkeysDemuxCtrl, localStorageState) ->
    hotkeysDemux = new MindtaggerTaskHotkeysDemuxCtrl [
        { combo: "enter", description: "Toggle current tag with the selection", action: "MindtaggerParametricTags.nextNullParamOrToggle(tag)" }
    ]
    restrict: 'A', transclude: true, templateUrl: "mindtagger/tags-parametric.html"
    controller: ($scope, $element, $attrs) ->
        $scope.MindtaggerParametricTags = @
        @withValue = null
        @paramIndex = 0
        @paramValues = []
        @name = null
        @current = null
        @isComplete = =>
            # TODO
            yes
        @willRemove = (tag, paramValues = @paramValues) =>
            @current.contains tag, paramValues
        @nextNullParamOrToggle = (tag, paramValues = @paramValues) =>
            if @isComplete
                @current.toggle tag, paramValues
            else
                # TODO move @paramIndex to next null
        # find all parametric tags from schema and prepare an object for each
        @all = {}
        for tagName,tagSchema of $scope.MindtaggerTask.schema.tags when tagSchema.type is "parametric"
            params =
                if tagSchema.params instanceof Array
                    hasParamNames = yes
                    # parameter names
                    tagSchema.params
                else if "object" is typeof tagSchema.params
                    hasParamNames = yes
                    _.keys tagSchema.params
                else if "number" is typeof tagSchema.params
                    hasParamNames = no
                    [0..tagSchema.params]
                else # unary type name
                    hasParamNames = no
                    [0]
            tagClass = if tagSchema.multiple then MultipleTag else SingletonTag
            @all[tagName] = new tagClass tagName, params, hasParamNames
        # initialize some fields from last state
        savedState = localStorageState "MindtaggerTask_#{$scope.MindtaggerTask.name}_ParametricTags", $scope, [
            "MindtaggerParametricTags.name"
        ]
        @name = savedState["MindtaggerParametricTags.name"]
        unless @name?
            for tagName of @all
                @name = tagName
                break
        # sync current tag name and value
        $scope.$watch "MindtaggerParametricTags.name", (newName) =>
            @current = @all[newName]
            if @paramIndex >= @current.paramNames.length
                @paramIndex = 0
                @paramValues.splice 0, @current.paramNames.length
        $scope.$watch "tag[MindtaggerParametricTags.name]", (newValue) =>
            $scope.$eval "commit(item,tag)"
        # watcher and setter for withValue
        $scope.$watch $attrs.withValue, (newValue) =>
            @withValue = newValue
            @paramValues[@paramIndex] = @withValue
        withValueModel = $parse $attrs.withValue
        $scope.$watch "MindtaggerParametricTags.withValue", (newValue) =>
            withValueModel.assign $scope, newValue
        # value renderer
        $scope.renderValue = (value) => ($scope.$eval $attrs.renderEachValue, {value}) ? value ? 'N/A'
        # equality check for complex values
        $scope.equals = angular.equals

    require: [
        '^mindtaggerTask'
    ]
    link: ($scope, $element, $attrs, [
        MindtaggerTask
    ]) ->
        hotkeysDemux.attach $scope
        $scope.MindtaggerTask = MindtaggerTask.task

class ParametricTag
    constructor: (@name, @paramNames, @hasParamNames) ->
        if @hasParamNames
            @pack = (paramValues) => _.object @paramNames, paramValues
            @unpack = (value) => value[name] for name in @paramNames
        else if @paramNames.length > 1
            @pack = (paramValues) -> paramValues
            @unpack = (value) -> value
        else
            @pack = (paramValues) -> paramValues[0]
            @unpack = (value) -> [value]
    contains: null
    toggle: null
    enumerateValues: null

class MultipleTag extends ParametricTag
    contains: (tag, paramValues) =>
        if paramValues? and tag[@name]?
            aValue = @pack paramValues
            for v in tag[@name] when angular.equals(aValue, v)
                return yes
        no
    toggle: (tag, paramValues) =>
        return unless paramValues?
        aValue = @pack paramValues
        set = tag[@name] ? []
        newSet = (v for v in set when not angular.equals(aValue, v))
        newSet.push aValue if newSet.length == set.length
        tag[@name] = newSet
    enumerateValues: (tag) => tag[@name]

class SingletonTag extends ParametricTag
    contains: (tag, paramValues) =>
        aValue = @pack paramValues
        angular.equals(aValue, tag[@name])
    toggle: (tag, paramValues) =>
        aValue = @pack paramValues
        tag[@name] =
            if angular.equals(aValue, tag[@name])
                null
            else
                aValue
    enumerateValues: (tag) => [tag[@name]] if tag[@name]?

