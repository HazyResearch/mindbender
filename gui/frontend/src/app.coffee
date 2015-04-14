# Declare app level module which depends on views, and components
angular.module 'mindbenderApp', [
    'ngRoute'
    'mindbenderApp.mindtagger'
    'mindbenderApp.dashboard'
]
.config ($routeProvider) ->
    $routeProvider.otherwise redirectTo: '/dashboard/'

## Workaround to get source mapping for uncaught exceptions
## See: http://stackoverflow.com/a/25642699
#.config ($provide) ->
#    $provide.decorator '$exceptionHandler', ($delegate) ->
#        (exception, cause) ->
#            $delegate exception, cause
#            throw exception
#            # XXX app may restart inadvertently if we throw exceptions here
