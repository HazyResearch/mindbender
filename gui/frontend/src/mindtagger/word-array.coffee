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

.service 'mindtaggerCreateStylesheet', ->
    stylesheetSeq = 0
    (css) ->
        $("""
        <style id="mindtagger-dynamic-style-#{stylesheetSeq++}">
        #{css}
        </style>
        """)

.directive 'mindtaggerHighlightWords', (mindtaggerCreateStylesheet, parsedArrayFilter) ->
    classNameSeq = 0
    restrict: 'EAC'
    scope:
        from: '='
        to: '='
        indexArray: '='
    compile: (tElement, tAttrs) ->
        arrayFormat = tAttrs.arrayFormat
        style = tElement.attr("style")
        className = "mindtagger-highlight-words-#{classNameSeq++}"
        ($scope, $element, $attrs) ->
            # add a new stylesheet
            mindtaggerCreateStylesheet(""".mindtagger-word.#{className} { #{style} }""")
                .appendTo($element.closest("body"))
            # remove style
            $element.attr("style", null)
            thingsToWatch = ->
                JSON.stringify [
                    $scope.indexArray
                    $element.find(".mindtagger-word").length
                ]
            $scope.$watch thingsToWatch, ->
                words = $element.find(".mindtagger-word")
                wordsToHighlight =
                    if $scope.from? and $scope.to? and 0 <= +$scope.from <= +$scope.to < words.length
                        words.slice +$scope.from-1, +$scope.to
                    else if $scope.indexArray?.length > 0
                        indexes =
                            if arrayFormat?
                                parsedArrayFilter $scope.indexArray, arrayFormat
                            else
                                $scope.indexArray
                        indexes = (+i for i in indexes)
                        words.filter (i) -> i in indexes
                # apply style
                words.removeClass className
                wordsToHighlight.addClass className

.directive 'mindtaggerSelectableWords', ($parse) ->
    restrict: 'EAC'
    compile: (tElement, tAttrs) ->
        ($scope, $element, $attrs) ->
            indexArrayModel = $parse $attrs.indexArray
            $element.on "click", ".mindtagger-word", (event) ->
                word = event.target
                words = $element.find(".mindtagger-word")
                wordIndex = words.index(word)
                indexArray = (indexArrayModel $scope) ? []
                if wordIndex in indexArray
                    indexArray = _.without indexArray, wordIndex
                else
                    indexArray.push wordIndex
                    indexArray.sort()
                indexArrayModel.assign $scope, indexArray
                $scope.$digest()

