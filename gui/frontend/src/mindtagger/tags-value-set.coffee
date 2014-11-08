angular.module 'mindbenderApp.mindtagger.tags.valueSet', [
]

.directive 'mindtaggerValueSetTag', ($parse, $interpolate, MindtaggerTaskHotkeysDemuxCtrl) ->
    hotkeysDemux = new MindtaggerTaskHotkeysDemuxCtrl [
        { combo: "enter", description: "Toggle selection in the current tag's value set", action: "MindtaggerValueSetTag.toggle(); commit(item,tag)" }
    ]
    restrict: 'A', transclude: true, templateUrl: "mindtagger/tags-value-set.html"
    controller: ($scope, $element, $attrs) ->
        hotkeysDemux.attach $scope
        model =
        $scope.MindtaggerValueSetTag =
            withValue: null
            name: null
            values: null
            contains: (value = model.withValue, set = model.values) ->
                if value? and set?
                    for v in set when angular.equals(value, v)
                        return yes
                no
            toggle: (value = model.withValue) ->
                return unless value?
                set = model.values ? []
                newSet = (v for v in set when not angular.equals(value, v))
                newSet.push value if newSet.length == set.length
                model.values = newSet
                $scope.$eval "tag[MindtaggerValueSetTag.name] = MindtaggerValueSetTag.values"
        # current tag name and values
        $scope.$watch $attrs.mindtaggerValueSetTag,      (newName)   -> model.name = newName
        $scope.$watch "tag[MindtaggerValueSetTag.name]", (newValues) -> model.values = newValues
        $scope.$watch "MindtaggerValueSetTag.values",    (newValues) ->
            $scope.$eval "tag[MindtaggerValueSetTag.name] = MindtaggerValueSetTag.values"
        # watcher and setter for currentValue
        $scope.$watch $attrs.withValue, (newValue) -> model.withValue = newValue
        currentValueModel = $parse $attrs.withValue
        $scope.$watch "MindtaggerValueSetTag.withValue", (newValue) -> currentValueModel.assign $scope, newValue
        # value renderer
        $scope.renderValue = (value) -> ($scope.$eval $attrs.renderEachValue, {value}) ? value
        # equality check for complex values
        $scope.equals = angular.equals

