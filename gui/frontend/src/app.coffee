# Declare app level module which depends on views, and components
angular.module 'mindbenderApp', [
    'ngRoute'
    'mindbenderApp.mindtagger'
]
.config ($routeProvider) ->
    $routeProvider.otherwise redirectTo: '/mindtagger'

# Workaround to get source mapping for uncaught exceptions
# See: http://stackoverflow.com/a/25642699
.config ($provide) ->
    $provide.decorator '$exceptionHandler', ($delegate) ->
        (exception, cause) ->
            $delegate exception, cause
            throw exception
