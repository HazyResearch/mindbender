angular.module 'mindbender.mindtagger.wordArray', [
    'mindbender.mindtagger.arrayParsers'
]

.directive 'mindtaggerWordArray', ->
    restrict: 'EAC', transclude: true
    priority: 1
    scope:
        mindtaggerWordArray: '='
        arrayFormat: '@'
    template: """
        <span class="mindtagger-words">
            <span class="mindtagger-word-container"
                ng-repeat="word in wordArray track by $index">
                <span class="mindtagger-word">{{word}}</span>
            </span>
            <span ng-transclude></span>
        </span>
    """
    controller: ($scope, $element, $attrs, $filter) ->
        @$element = $element
        $element.tooltip selector: ".has-tooltip"
        @getWordElements = =>
            @$element.find(".mindtagger-word")
        $scope.$watchGroup [
                -> $scope.mindtaggerWordArray
                -> $scope.arrayFormat
            ], ([
                newArray
                newFormat
            ]) =>
                $scope.wordArray =
                @wordArray =
                    if newFormat
                        ($filter "parsedArray") newArray, newFormat
                    else
                        newArray

.service 'mindtaggerCreateStylesheet', ->
    stylesheetSeq = 0
    (css) ->
        $("""
        <style id="mindtagger-dynamic-style-#{stylesheetSeq++}">
        #{css}
        </style>
        """)

.directive 'mindtaggerHighlightWords', (mindtaggerCreateStylesheet, parsedArrayFilter, watchGroupDeep) ->
    classNameSeq = 0
    restrict: 'EAC'
    require: [
        '^mindtaggerWordArray'
    ]
    compile: (tElement, tAttrs) ->
        arrayFormat = tAttrs.arrayFormat
        asArray =
            if arrayFormat?
                (v) -> parsedArrayFilter v, arrayFormat
            else
                (v) -> v
        style = tAttrs.withStyle
        className = "mindtagger-highlight-words-#{classNameSeq++}"
        ($scope, $element, $attrs, [
            mindtaggerWordArray
        ]) ->
            getWordSpanFrom =
                # several ways to specify a set of word spans
                if $attrs.from? and $attrs.to?
                    # from-to
                    watchExprs = [
                        "from"
                        "to"
                    ]
                    (words, $scope) ->
                        from = $scope.$eval $attrs.from
                        to   = $scope.$eval $attrs.to
                        if from? and to? and 0 <= +from <= +to < words.length
                            [{from: +from, to: +to + 1}]
                else if $attrs.from? and $attrs.length?
                    # from-length
                    watchExprs = [
                        $attrs.from
                        $attrs.length
                    ]
                    (words, $scope) ->
                        from   = $scope.$eval $attrs.from
                        length = $scope.$eval $attrs.length
                        if from? and length? and 0 <= +from < words.length and +length >= 0
                            [{from: +from, to: +from + +length}]
                else if $attrs.indexArray?
                    # an indexArray
                    watchExprs = [
                        "#{$attrs.indexArray} | json"
                    ]
                    (words, $scope) ->
                        indexes = asArray $scope.$eval $attrs.indexArray
                        [+i for i in indexes] if indexes?
                else if $attrs.indexArrays?
                    # multiple indexArrays
                    watchExprs = [
                        "#{$attrs.indexArrays} | json"
                    ]
                    (words, $scope) ->
                        asArray $scope.$eval $attrs.indexArrays
                else if $attrs.froms? and $attrs.tos?
                    # multiple from-to pairs
                    watchExprs = [
                        "#{$attrs.froms} | json"
                        "#{$attrs.tos} | json"
                    ]
                    (words, $scope) ->
                        froms = asArray $scope.$eval $attrs.froms
                        tos   = asArray $scope.$eval $attrs.tos
                        if froms? and tos? and froms.length == tos.length
                            for from,i in froms
                                from = +from
                                to = +tos[i] + 1
                                continue unless 0 <= from <= to <= words.length
                                {from, to}
                else if $attrs.froms? and $attrs.lengths?
                    # multiple from-length pairs
                    watchExprs = [
                        "#{$attrs.froms} | json"
                        "#{$attrs.lengths} | json"
                    ]
                    (words, $scope) ->
                        froms   = asArray $scope.$eval $attrs.froms
                        lengths = asArray $scope.$eval $attrs.lengths
                        if froms? and lengths? and froms.length == lengths.length
                            for from,i in froms
                                from = +from
                                length = +lengths[i]
                                continue unless 0 <= from < words.length and length >= 0
                                to = from + length
                                {from, to}
                else
                    console.warn "mindtagger-highlight-words has incomplete attributes", $attrs
                    watchExprs = []
                    (words, $scope) -> null
            # add a new stylesheet
            mindtaggerCreateStylesheet("""
                    .mindtagger-word-container .#{className} { #{style} }

                    /* box-shadow and bottom margin for making overlapping highlights more obvious */
                    .mindtagger-word-container .mindtagger-highlight-words {
                        display: inline-block;
                        box-shadow: 0 0 0.2em;
                        cursor: default;
                    }
                    .mindtagger-word-container
                    .mindtagger-highlight-words .mindtagger-highlight-words {
                        margin-bottom: 0.2em;
                    }
                    .mindtagger-word-container:hover
                    .mindtagger-highlight-words .mindtagger-highlight-words {
                        margin-bottom: 2em;
                    }
                    .mindtagger-words .tooltip-inner {
                        white-space: nowrap;
                        overflow: hidden;
                        text-overflow: ellipsis;
                    }
                """)
                .appendTo($element.closest("body"))
            $scope.$watchGroup [
                watchExprs...
                -> mindtaggerWordArray.wordArray
            ], ->
                words = mindtaggerWordArray.getWordElements()
                wordSpans = (getWordSpanFrom words, $scope) ? []
                # apply style to wordSpans by wrapping highlight elements
                words.parents(".#{className}")
                    .tooltip("destroy")
                    .contents().unwrap()
                for wordSpan in wordSpans
                    wordsToHighlight =
                        if wordSpan instanceof Array
                            indexes = wordSpan
                            words.filter((i) -> i in wordSpan) if wordSpan?.length > 0
                        else
                            {from, to} = wordSpan
                            indexes = [from...to]
                            words.slice from, to
                    wordSpanText = wordsToHighlight.map(-> $(@).text()).toArray().join(" ")
                    wordsToHighlight.wrap(
                        $("<span>")
                            .addClass("#{className} mindtagger-highlight-words has-tooltip")
                            .attr(
                                title: wordSpanText
                                "data-placement": "bottom"
                                "data-word-indexes": JSON.stringify indexes
                            )
                    )
            

.directive 'mindtaggerSelectableWords', ($parse, $timeout, hotkeys, MindtaggerTaskHotkeysDemuxCtrl) ->
    hotkeysDemux = new MindtaggerTaskHotkeysDemuxCtrl [
        { combo: "left"       , description: "Select previous word"             , action: "  moveIndexArrayBy(-1)" }
        { combo: "right"      , description: "Select next word"                 , action: "  moveIndexArrayBy(+1)" }
        { combo: "shift+left" , description: "Extend selection to previous word", action: "extendIndexArrayBy(-1)" }
        { combo: "shift+right", description: "Extend selection to next word"    , action: "extendIndexArrayBy(+1)" }
    ]

    restrict: 'A'
    require: [
        '^mindtaggerWordArray'
    ]
    link: ($scope, $element, $attrs, [
        mindtaggerWordArray
    ]) ->
        hotkeysDemux.attach $scope
        indexArrayModel = $parse $attrs.indexArray
        updateIndexArray = (indexArray) ->
            if indexArray?.length > 0
                compareNumbers = (a, b) -> a - b # For sorting in numerical order, see: http://stackoverflow.com/questions/1063007/arr-sort-does-not-sort-integers-correctly
                indexArray = (_.uniq indexArray).sort compareNumbers
            else
                indexArray = null
            indexArrayModel.assign $scope, indexArray
            $timeout -> $scope.$digest()
        isModifyingSelection = (event) -> event.metaKey or event.ctrlKey
        findWordFor = (el) ->
            $(el).closest(".mindtagger-word-container").find(".mindtagger-word")
        mindtaggerWordArray.$element.on "mouseup", (event) ->
            words = mindtaggerWordArray.getWordElements()
            sel = getSelection()
            if sel.baseNode is sel.extentNode and sel.baseOffset == sel.extentOffset
                # if selection is empty, this must be a normal click
                el = event.srcElement ? event.target
                $hl = $(el).closest ".mindtagger-highlight-words, .mindtagger-word-container"
                if $hl.hasClass "mindtagger-highlight-words"
                    # if a highlighted span was clicked, select it
                    selectedWordIndexes = JSON.parse $hl.attr("data-word-indexes")
                else
                    # otherwise, select the word
                    word = findWordFor el
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
        # keyboard shortcuts handlers
        $scope.moveIndexArrayBy = (incr = 0) ->
            return if incr == 0
            numWords = mindtaggerWordArray.wordArray.length
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
            numWords = mindtaggerWordArray.wordArray.length
            leftmostIndex = Math.min indexArray...
            rightmostIndex = Math.max indexArray...
            indexArray =
                if dir > 0 then indexArray.concat [(rightmostIndex+1)..(Math.min rightmostIndex+dir, numWords-1)]
                else _.difference indexArray, [(Math.max 0, rightmostIndex+dir+1)..rightmostIndex]
            indexArray = [leftmostIndex] if indexArray.length == 0
            updateIndexArray indexArray


.service 'watchGroupDeep', () ->
    ($scope, exprOrFns, action) ->
        for exprOrFn in exprOrFns
            $scope.$watch exprOrFn, (-> $scope.$emit "watchGroupDeepFoundSomethingChanged"), yes
        $scope.$on 'watchGroupDeepFoundSomethingChanged', _.debounce action, 100

