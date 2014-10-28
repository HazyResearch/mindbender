angular.module 'mindbenderApp.mindtagger.wordArray', [
    'mindbenderApp.mindtagger.arrayParsers'
]

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
                    wordsToHighlight.attr("style", (i, css = "") -> css + style)

