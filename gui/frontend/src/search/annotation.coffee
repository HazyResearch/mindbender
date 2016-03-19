#

angular.module "mindbender.search.annotation", [
    'elasticsearch'
    'json-tree'
    'ngSanitize'
    'mindbender.auth'
    'ui.bootstrap'
]

.directive "labelPopover", ($timeout, $document, $uibPosition) ->
    transclude:true
    scope:
        k: "="
    template: """<span uib-popover-template="'labelPopoverTemplate.html'" 
           popover-trigger="manual" ng-class="{'highlight':true,
            'highlight-correct': tag.is_correct == 'correct',
            'highlight-incorrect': tag.is_correct == 'incorrect',
            'highlight-unknown': tag.is_correct == 'unknown' }"
           popover-placement="bottom"
           popover-is-open="isOpen"
           ng-click="isOpen = true"
           ng-transclude></span>"""

    controller: ($scope) ->
        $scope.isOpen = false
        # the popover creates it's own scope which protoypically inherits from this scope;
        # we thus wrap is_correct into an object, so that we don't need to synchronize state
        $scope.tag = { is_correct : '' }
        $scope.last_user_name = ''

        $scope.commit = (val) =>
            # if user clicks on active button, we reset the value
            cur = $scope.curFeedback()
            if cur && cur.value == val
                $scope.tag.is_correct = val = ''
            $timeout () =>
                $scope.$parent.writeFeedback $scope.extraction.doc_id, $scope.extraction.mention_id, val 

        $scope.curFeedback = (f) =>
            if !f
                f = $scope.$parent.feedback
            if !f || !$scope.extraction
                return false
            cur = f[$scope.extraction.doc_id + ',' + $scope.extraction.mention_id]
            if !cur
               return false
            return cur

        $scope.tagHandler = (f) =>
            cur = $scope.curFeedback(f)
            if cur && cur.value != $scope.tag.is_correct
               $scope.tag.is_correct = cur.value
            if cur.user_name != $scope.last_user_name
               if cur.value == ''
                   $scope.last_user_name = ''
               else
                   $scope.last_user_name = cur.user_name

        # we set initial state by listening to broadcast from parent
        $scope.$on 'update_feedback', (event, feedback) =>
            $scope.tagHandler feedback

    link: ($scope, $element, attrs) ->
        k = parseInt(attrs.k)
        $scope.extraction = JSON.parse($scope.$parent.searchResult._source.extractions[k])
        $scope.extractor = $scope.extraction.extractor

        # hide popover on click away
        handler = (e) ->
            if $scope.isOpen && !$element[0].contains(e.target)
                $scope.$apply () ->
                    $scope.isOpen = false

        $document.on 'click', handler

        $scope.$on '$destroy', () =>
            $document.off('click', handler)


.directive "textWithAnnotations", ($q, $timeout, $http, $compile, tagsService) ->
    scope:
        searchResult: "="
    template: """
        <div ng-click="toggleEditMode()" ng-class="{'sq-btn': true, 'sq-btn-active':editMode}"
          data-toggle="tooltip" data-placement="left" data-original-title="Switch to annotation mode"
          ><i class="fa fa-pencil"></i></div>
        <div></div>
        """
    controller: ($scope) ->
        $scope.editMode = false

        $scope.toggleEditMode = () =>
            $scope.editMode = !$scope.editMode


        # map from doc_id,mention_id -> feedback
        $scope.feedback = {}

        $scope.fetchFeedback = () =>
            doc_id = $scope.searchResult._source.doc_id
            $http.get "/api/feedback/" + doc_id 
                  .success (data) =>
                      data.forEach (d) ->
                          $scope.feedback[d.doc_id + ',' + d.mention_id] = d
                      $scope.$broadcast('update_feedback', $scope.feedback)
                  .error (err) =>
                      console.error err.message

        $scope.writeFeedback = (doc_id, mention_id, value) =>
            $http.post "/api/feedback", { doc_id:doc_id, mention_id:mention_id, value:value }
                .success (data) =>
                    # update model
                    $scope.feedback[doc_id + ',' + mention_id] = data
                    $scope.$broadcast('update_feedback', $scope.feedback)
                .error (err) =>
                    console.error err.message

        $scope.fetchFeedback()

        $scope.annotations = {}

        $scope.fetchAnnotations = () =>
            doc_id = $scope.searchResult._source.doc_id
            $http.get "/api/annotation/" + doc_id
                .success (data) =>
                    data.forEach (d) ->
                        $scope.showAnnotation(d.value, false)
                .error (err) =>
                    console.error err.message

        $scope.writeAnnotation = (doc_id, mention_id, value, callback) =>
            # compute sets of tags used in this document, after new annotation
            annotated_flags = {}
            for k,v of $scope.annotations
              for s,t of v.tags
                annotated_flags[t] = true
            for s,t of v.tags
              annotated_flags[t] = true
            annotated_flags_arr = [k for k,v of annotated_flags]

            $http.post "/api/annotation", { 
                doc_id:doc_id
                mention_id:mention_id
                value:value,
                _index:$scope.searchResult._index
                _type:$scope.searchResult._type
                annotated_flags:annotated_flags_arr 
              }
              .success (data) =>
                    value.user_name = data.user_name
                    if callback
                        callback()
              .error (err) =>
                    console.error err.message

        $scope.removeAnnotation = (doc_id, mention_id, callback) =>
            $http.delete '/api/annotation/' + doc_id + '/' + mention_id, { }
                .success (data) =>
                    if callback
                        callback()
                .error (err) =>
                    console.error err.message

        $scope.fetchAnnotations()

        $scope.onSelection = (ranges, event) =>
            if !$scope.editMode
                return
            if ranges.length > 0
                doc_id = $scope.searchResult._source.doc_id
                mention_id = Object.keys($scope.annotations).length
                annotation = $scope.makeAnnotation(ranges)
                obj = { doc_id:doc_id, mention_id:mention_id, value:annotation, tags:[], comment:'' }
                $scope.showAnnotation(obj, true)
                document.getSelection().removeAllRanges()

        $scope.showAnnotation = (ann, openPopup = false) =>
            highlightSpans = $scope.hl.draw(ann.value)
            key = ann.doc_id + ',' + ann.mention_id
            $scope.annotations[key] = ann
            for i in highlightSpans
                el = angular.element(i)
                el.attr('annotation-popover', '')
                el.attr('doc-id', ann.doc_id)
                el.attr('mention-id', ann.mention_id)
                el.attr('annotation-open', openPopup)
            $compile(el)($scope)

        $scope.hideAnnotation = (doc_id, mention_id) =>
            key = doc_id + ',' + mention_id
            ann = $scope.annotations[key]
            $scope.hl.undraw(ann.value)
            delete $scope.annotations[key]

        $scope.getAnnotation = (doc_id, mention_id) =>
            key = doc_id + ',' + mention_id
            return $scope.annotations[key]

    link: ($scope, $element) ->
        el = TextWithAnnotations.create($scope.searchResult)
        second = $element.children().eq(1)
        second.prepend(el)

        $compile(el)($scope)

        txtEl = second[0]

        # enable annotations
        $scope.hl = new annotator.ui.highlighter.Highlighter txtEl, {}
        $scope.ts = new annotator.ui.textselector.TextSelector txtEl, { 
            onSelection: $scope.onSelection }

        # trims whitespace, usually in native code but not ie8
        trim = (s) =>
            if typeof String.prototype.trim == 'function'
                String.prototype.trim.call s
            else
                s.replace(/^[\s\xA0]+|[\s\xA0]+$/g, '')

        # construct annotation from list of ranges
        annotationFactory = (contextel, ignoreSelector) =>
            return (ranges) =>
                text = []
                serializedRanges = []
                for i in [0...ranges.length]
                    r = ranges[i]
                    text.push trim(r.text())
                    serializedRanges.push(r.serialize(contextel, ignoreSelector))
                return {
                    quote: text.join(' / ')
                    ranges: serializedRanges
                }

        $scope.makeAnnotation = annotationFactory(txtEl, '.annotator-hl')


.directive "annotationPopover", ($http, $compile, $document, $timeout, tagsService) ->
    scope: {}
    controller: ($scope) ->
        $scope.tags = tagsService
        $scope.togglePopup = () =>
            $scope.isOpen = !$scope.isOpen

        $scope.add = (st) =>
            $scope.annotation.tags.push(st)
            $scope.$parent.writeAnnotation($scope.docId, $scope.mentionId,
                $scope.annotation)
            tagsService.maybeCreate(st)

        $scope.remove = (st) =>
            index = $scope.annotation.tags.indexOf(st)
            if index > -1
                $scope.annotation.tags.splice index, 1
                $scope.$parent.writeAnnotation $scope.docId, $scope.mentionId,
                    $scope.annotation, () ->
                         tagsService.maybeRemove st

        $scope.onSelect = ($item, $model, $label) ->
            $scope.commit($item)

        $scope.onCommentBlur = () ->
            if $scope.commentChanged
                $scope.$parent.writeAnnotation($scope.docId, $scope.mentionId,
                    $scope.annotation)

        $scope.commentChanged = false

        $scope.onCommentChange = () ->
            $scope.commentChanged = true


    link: ($scope, $element, attrs) ->
        $scope.isOpen = attrs['annotationOpen'] == 'true'
        $scope.docId = attrs['docId']
        $scope.mentionId = attrs['mentionId']

        $scope.annotation = $scope.$parent.getAnnotation $scope.docId, $scope.mentionId

        # remove self to avoid infinite loop
        $element.removeAttr('annotation-popover')

        # add popover
        $element.attr('uib-popover-template', "'annotationPopoverTemplate.html'")
        $element.attr('popover-trigger', 'manual')
        $element.attr('popover-placement', 'bottom')
        $element.attr('popover-is-open', 'isOpen')

        # add tooltip
        $element.attr('data-toggle', 'tooltip')
        $element.attr('data-placement', 'top')
        $element.attr('data-original-title', '{{annotation.tags.join(", ")}}')

        $element.attr('ng-click', 'togglePopup()')

        $compile($element)($scope)

        $timeout () =>
          $element.tooltip()

        # hide popover on click away
        handler = (e) ->
            if $scope.isOpen && !$(e.target).parents('.popover').length && !$element[0].contains(e.target) && 
                document.body.contains(e.target)
                    $scope.$apply () ->
                        $scope.isOpen = false
                        if $scope.annotation.tags.length == 0
                            $scope.$parent.removeAnnotation $scope.docId, $scope.mentionId
                            $scope.$parent.hideAnnotation $scope.docId, $scope.mentionId

        $timeout () =>
            $document.on 'click', handler

        $scope.$on '$destroy', () =>
            $document.off('click', handler)

.directive "tagsinputCustomEvents", ($parse, $timeout, tagsService) ->
    restrict: 'A'
    scope:
        add:'=add'
        remove:'=remove'
        activeTags:'=tags'
    link: ($scope, elem, attrs) ->
        elem.tagsinput({
            confirmKeys: [13]
            trimValue: true
            typeahead: {
                source: tagsService.tags
                minLength: 0
                showHintOnFocus: false
                #matcher: 'case insensitive'
                matcher: (a) ->
                   a.toUpperCase().indexOf(this.query.toUpperCase()) == 0
                autoSelect: false
            }
        })

        # add initial set of items
        elem.tagsinput('removeAll')
        for t in $scope.activeTags
            elem.tagsinput('add', t)

        elem.on 'itemAdded', (evt) ->
            $scope.add evt.item
            # fix bug where the input val does not clear
            $timeout () ->
              elem.tagsinput('input').val('')
        elem.on 'itemRemoved', (evt) ->
            $scope.remove evt.item

        triggerFunc = (evt) ->
            if !$scope.activeTags || $scope.activeTags.length == 0
                  # hack to force open drawer
                  elem.tagsinput('input').typeahead('lookup', '')

        elem.tagsinput('input').bind('focus', triggerFunc)

        $timeout () ->
            elem.tagsinput('findInputWrapper').css('min-width','200px')
            elem.tagsinput('input').parent().css('width','100%')
            elem.tagsinput('focus')

.service "tagsService", ($http) ->
    cmp = (a,b) ->
        a.toUpperCase().localeCompare(b.toUpperCase())

    tags = {
        # array of tags used shown in the annotation typeahead
        tags: []
        flags: {} # existing flag extractors
        maybeCreate: (value) ->
            # creates tag if it does not exist
            if $.inArray(value, tags.tags) == -1
                $http.post "/api/tags", { value:value }
                    .success (data) =>
                        tags.tags.push value
                        tags.tags.sort cmp
                    .error (err) =>
                        console.error err.message
        maybeRemove: (value) ->
            # checks if tag is used by any annotation and if not, removes tag
            $http.get "/api/tags/maybeRemove/" + encodeURIComponent(value), {}
                 .success (data) =>
                    if parseInt(data) > 0
                        index = tags.tags.indexOf(value)
                        if index > -1
                            tags.tags.splice index, 1
                 .error (err) =>
                    console.error err
        fetchTags: () ->
            $http.get "/api/tags", {}
                .success (data) =>
                    # sorted array for annotation typeahead
                    tags.tags = $.map data, (t) -> t.value
                    tags.tags.sort cmp
                    # set of extractor flags
                    f = {}
                    for k,t of data
                      if t.is_flag
                        f[t.value] = true
                    tags.flags = f
                .error (err) =>
                    console.error err.message
    }

    tags.fetchTags()

    return tags

.directive "helpVideo", ($timeout, $templateCache) -> 

    link: ($scope, elem, attrs) ->
       elem.tooltip({
           title:'Demo Video'
           placement:'bottom'
       })
       videoHtml = $templateCache.get('helpVideo.html')
       elem.colorbox({
           html:videoHtml
           innerWidth:'800px'
           onComplete:() ->
               colorbox = $(document.getElementById('colorbox'))
               video = colorbox.find('video')
               video[0].play()
       })

.directive "flagHelp", ($document, $templateCache, $http) ->
    template: """<div uib-popover-template="'flagHelp' + key + '.html'"
           popover-trigger="mouseenter"
           popover-placement="right"
           popover-is-open="isOpen"
           popover-append-to-body="true"
           ng-click="toggle($event)" class="flag-help-icon">?</div>"""
    controller: ($scope) ->
        $scope.close = (evt) ->
           $scope.isOpen = false
           evt.stopPropagation()
           return false
        $scope.toggle = (evt) ->
           $scope.isOpen = !$scope.isOpen
           evt.stopPropagation()
           return false
    link: ($scope, $element, attrs) ->        
        $scope.isOpen = false
        k = encodeURIComponent(attrs['key'])
        if $templateCache.get('flagHelp' + k + '.html')?
            $scope.key = k
        else
            $scope.key = 'Missing'        

        # hide popover on click away
        handler = (e) ->
            if $scope.isOpen #&& !$element[0].contains(e.target)
                $scope.$apply () ->
                    $scope.isOpen = false
                e.stopPropagation()
                return false
            return true

        $document.on 'click', handler

        $scope.$on '$destroy', () =>
            $document.off('click', handler)

