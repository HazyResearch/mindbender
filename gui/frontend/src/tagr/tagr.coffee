angular.module 'mindbenderApp.tagr', [
    'ui.bootstrap'
]

.config ($routeProvider) ->
    $routeProvider.when '/tagr',
        templateUrl: 'tagr/tagr.html',
        controller: 'TagrCtrl'

.controller 'TagrCtrl', ($scope, $http) ->
    $http.get '/api/tagr/basedata'
        .success (baseData) ->
            $scope.baseData = baseData
    $http.get '/api/tagr/annotation'
        .success (annotation) ->
            $scope.annotation = annotation
