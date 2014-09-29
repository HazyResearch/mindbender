# Declare app level module which depends on views, and components
angular.module('mindbenderApp', [
  'ngRoute'
  'myApp.view1'
  'myApp.view2'
  'myApp.version'
])
.config ['$routeProvider', ($routeProvider) ->
    $routeProvider.otherwise redirectTo: '/view1'
]
