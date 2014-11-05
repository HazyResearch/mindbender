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
        <span class="mindtagger-word-container"
            ng-repeat="word in mindtaggerWordArray | parsedArray:arrayFormat track by $index">
            <span class="mindtagger-word">{{word}}</span>
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
        from: '=', to: '='
        indexArray: '='
        indexArrays: '='
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
                    $scope.from, $scope.to
                    $scope.indexArray
                    $scope.indexArrays
                    $element.find(".mindtagger-word").length
                ]
            $scope.$watch thingsToWatch, ->
                words = $element.find(".mindtagger-word")
                wordsToHighlight =
                    if $scope.from? and $scope.to? and 0 <= +$scope.from <= +$scope.to < words.length
                        words.slice +$scope.from-1, +$scope.to
                    else
                        indexes =
                            if $scope.indexArray?.length > 0
                                indexes =
                                    if arrayFormat?
                                        parsedArrayFilter $scope.indexArray, arrayFormat
                                    else
                                        $scope.indexArray
                                (+i for i in indexes)
                            else if $scope.indexArrays?.length > 0
                                _.union $scope.indexArrays...
                            else
                                []
                        words.filter((i) -> i in indexes) if indexes?.length > 0
                # apply style
                words.removeClass className
                wordsToHighlight.addClass className

.directive 'mindtaggerSelectableWords', ($parse, $timeout) ->
    restrict: 'EAC'
    compile: (tElement, tAttrs) ->
        indexArrayModel = $parse tAttrs.indexArray
        ($scope, $element, $attrs) ->
            updateIndexArray = (indexArray) ->
                if indexArray?.length == 0
                    indexArray = null
                else
                    indexArray = _.uniq indexArray?.sort()
                indexArrayModel.assign $scope, indexArray
                $timeout -> $scope.$digest()
            isModifyingSelection = (event) -> event.metaKey or event.ctrlKey
            findWordFor = (el) ->
                $(el).closest(".mindtagger-word-container").find(".mindtagger-word")
            $element.on "mouseup", (event) ->
                words = $element.find(".mindtagger-word")
                sel = getSelection()
                if sel.baseNode is sel.extentNode and sel.baseOffset == sel.extentOffset
                    # if selection is empty, this must be a normal click
                    word = findWordFor (event.srcElement ? event.target)
                    selectedWordIndexes = [words.index word]
                else
                    # from the selected range
                    r = sel.getRangeAt(0)
                    # find boundary words
                    $startWord = findWordFor r.startContainer
                    $endWord   = findWordFor r.endContainer
                    from = words.index $startWord
                    to   = words.index $endWord
                    return if from == -1 or to == -1
                    selectedWordIndexes = [from, to]
                    # and words contained in the selection
                    words.each (i, word) ->
                        selectedWordIndexes.push i if sel.containsNode word
                    sel.empty()
                if isModifyingSelection event
                    # when modifying selection,
                    prevIndexes = (indexArrayModel $scope) ? []
                    # add any newly selected words, but remove the previously selected ones
                    selectedWordIndexes =
                        _.union (_.difference selectedWordIndexes, prevIndexes),
                                (_.difference prevIndexes, selectedWordIndexes)
                # finally, reflect to the model
                updateIndexArray selectedWordIndexes
            $scope.$watch ->
                    $scope.MindtaggerTask.cursor.item is $scope.item
                , (cursorOnThisItem) ->
                    indexArrayModel.assign $scope, null unless cursorOnThisItem

