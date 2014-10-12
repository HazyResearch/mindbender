# Declare app level module which depends on views, and components
angular.module 'mindbenderApp', [
    'ngRoute'
    'mindbenderApp.mindtagger'
]
.config ['$routeProvider', ($routeProvider) ->
    $routeProvider.otherwise redirectTo: '/mindtagger'
]
