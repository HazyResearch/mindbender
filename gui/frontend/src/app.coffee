# Declare app level module which depends on views, and components
angular.module 'mindbenderApp', [
    'ngRoute'
    'mindbenderApp.tagr'
]
.config ['$routeProvider', ($routeProvider) ->
    $routeProvider.otherwise redirectTo: '/tagr'
]
