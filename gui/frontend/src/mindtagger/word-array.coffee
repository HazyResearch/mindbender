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
                wordsToHighlight?.addClass className

.directive 'mindtaggerSelectableWords', ($parse, $timeout, hotkeys, MindtaggerTaskHotkeysDemuxCtrl) ->
    hotkeysDemux = new MindtaggerTaskHotkeysDemuxCtrl [
        { combo: "left"       , description: "Select previous word"             , action: "  moveIndexArrayBy(-1)" }
        { combo: "right"      , description: "Select next word"                 , action: "  moveIndexArrayBy(+1)" }
        { combo: "shift+left" , description: "Extend selection to previous word", action: "extendIndexArrayBy(-1)" }
        { combo: "shift+right", description: "Extend selection to next word"    , action: "extendIndexArrayBy(+1)" }
    ]

    restrict: 'A'
    controller: ($scope, $element, $attrs) ->
        hotkeysDemux.attach $scope
        indexArrayModel = $parse $attrs.indexArray
        updateIndexArray = (indexArray) ->
            if indexArray?.length > 0
                indexArray = _.uniq indexArray.sort()
            else
                indexArray = null
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
        # blur the selection when this item loses focus
        $scope.$watch ->
                $scope.MindtaggerTask.cursor.item is $scope.item
            , (isCursorOnThisItem) ->
                indexArrayModel.assign $scope, null unless isCursorOnThisItem
        # keyboard shortcuts handlers
        $scope.moveIndexArrayBy = (incr = 0) ->
            return if incr == 0
            numWords = $element.find(".mindtagger-word").length
            indexArray = indexArrayModel $scope
            if indexArray?.length > 0
                for i in indexArray
                    return if i + incr < 0
                    return if i + incr >= numWords
                updateIndexArray (i + incr for i in indexArray)
            else
                updateIndexArray [if incr > 0 then 0 else numWords - 1]
        $scope.extendIndexArrayBy = (dir = 0) ->
            return if dir == 0
            indexArray = indexArrayModel $scope
            return unless indexArray?.length > 0
            return if dir < 0 and indexArray?.length + dir <= 0
            numWords = $element.find(".mindtagger-word").length
            leftmostIndex = Math.min indexArray...
            rightmostIndex = Math.max indexArray...
            indexArray =
                if dir > 0 then indexArray.concat [(rightmostIndex+1)..(Math.min rightmostIndex+dir, numWords-1)]
                else _.difference indexArray, [(Math.max 0, rightmostIndex+dir+1)..rightmostIndex]
            indexArray = [leftmostIndex] if indexArray.length == 0
            updateIndexArray indexArray

