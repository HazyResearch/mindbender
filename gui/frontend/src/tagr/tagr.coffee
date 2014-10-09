findAllKeys = (rows) ->
    merged = {}
    angular.extend merged, rows...
    key for key of merged

deriveSchema = (tags, baseSchema) ->
    schema = {}
    # examine all tags  # TODO sample if large?
    for tag in tags
        for name,value of tag
            ((schema[name] ?= {}).values ?= []).push value
    # infer type by induction on observed values
    for tagName,tagSchema of schema
        tagSchema.type =
            if tagSchema.values.length == 2 and
                    not tagSchema.values[0] is not not tagSchema.values[1]
                'binary'
            else
                # TODO 'categorical'
                'freetext'
    if baseSchema?
        angular.extend schema, baseSchema
    else
        schema

directiveForIncludingPresetTemplate = (templateName) ->
    restrict: 'EA'
    scope: true
    controller: ($scope) ->
        # pop the preset stack to resolve the current preset
        [preset, $scope.presets...] =
            if $scope.$parent.presets?.length > 0
                $scope.$parent.presets
            else
                # fallback to _default preset if the stack is empty but a render is forced
                ['_default']
        $scope.presetPath = "/tagr/preset/#{preset}"
    template: """
        <span ng-include="presetPath + '/#{templateName}-template.html'"></span>
        """

angular.module 'mindbenderApp.tagr', [
    'ui.bootstrap'
]

.config ($routeProvider) ->
    $routeProvider.when '/tagr',
        templateUrl: 'tagr/tagr.html',
        controller: 'TagrItemsCtrl'

.controller 'TagrItemsCtrl', ($scope, $http, $window) ->
    $scope.presets = ['_default']

    $scope.tagsSchema = {}

    $http.get '/api/tagr/schema'
        .success ({presets, tags:schema}) ->
            $scope.presets = presets
            $scope.tagsSchemaBase = schema
            $http.get '/api/tagr/tags'
                .success (tags) ->
                    $scope.tags = tags
                    $scope.tagsSchema = deriveSchema $scope.tags, $scope.tagsSchemaBase
                    $http.get '/api/tagr/items'
                        .success (items) ->
                            $scope.items = items
                            $scope.itemSchema = deriveSchema items
                            $scope.exportFormat = "sql"
                            $scope.export = (format) ->
                                $window.location.href = "/api/tagr/tags.#{format ? $scope.exportFormat}?keys=#{
                                    encodeURIComponent ((attrName for attrName,attrSchema of $scope.itemSchema when attrSchema.export).join ",")
                                }"
                                # TODO table=

    $scope.$on "tagChanged", ->
        # update schema
        console.log "some tags changed"
        $scope.tagsSchema = deriveSchema $scope.tags, $scope.tagsSchemaBase

.controller 'TagrTagsCtrl', ($scope, $http, $timeout) ->
    $scope.tag = ($scope.$parent.tags[$scope.$parent.$index] ?= {})
    $scope.commit = (tag) -> $timeout ->
        $scope.$emit "tagChanged"
        index = $scope.$parent.$index
        $http.post '/api/tagr/tags', {index, tag}
            .success (result) ->
                console.log "committed tags for item #{index}", tag
            .error (result) ->
                # FIXME revert tag to previous value
                console.error "commit failed for item #{index}", tag

.directive 'mbRenderItem', ->
    directiveForIncludingPresetTemplate 'item'
.directive 'mbRenderTags', ->
    directiveForIncludingPresetTemplate 'tags'

# a handy filter for parsing Postgres ARRAYs serialized in CSV outputs
.filter 'parsedPostgresArray', ->
    (text, index) ->
        # extract the csv-like piece in the text
        return null unless (m = /^{(.*)}$/.exec text?.trim())?
        csvLikeText = m[1]
        # convert backslash escapes to standard CSV escapes
        csvText = csvLikeText
            .replace /\\(.)/g, (m, c) ->
                switch c
                    when '"'
                        '""'
                    else
                        c
        array = $.csv.toArray csvText
        if index?
            array[index]
        else
            array

