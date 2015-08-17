# Declare app level module which depends on views, and components
angular.module 'mindbender', [
    'ngRoute'
    'mindbender.mindtagger'
    'mindbender.dashboard'
    'mindbender.search'
    'mindbender.extensions'
]
.config ($routeProvider) ->
    $routeProvider.when '/',
        templateUrl: 'landing.html'
        controller: 'LandingPageCtrl'
    $routeProvider.otherwise redirectTo: '/'

.run ($rootScope, $interpolate) ->
    # update title and brand
    tmplsDefault = {
        title: "DeepDive"
        brand: "DeepDive"
        brandIcon: ""
    }
    updateRootScopeFromCurrentRoute = (event, current, previous) ->
        for attr,tmplDefault of tmplsDefault
            tmpl = $interpolate (current.$$route[attr] ? tmplsDefault)
            $rootScope[attr] = tmpl current.params
    $rootScope.$on "$routeChangeStart", updateRootScopeFromCurrentRoute
    $rootScope.$on "$routeUpdate",      updateRootScopeFromCurrentRoute

.controller 'LandingPageCtrl', ($rootScope, $http, $location) ->
    # redirect to mindtagger or dashboard at first visit
    unless $rootScope.mindtaggerTasks?
        $http.get "api/mindtagger/"
            .success (tasks) ->
                $rootScope.mindtaggerTasks = tasks
                if tasks.length > 0
                    $location.path "/mindtagger"
                else
                    $location.path "/dashboard"

## Workaround to get source mapping for uncaught exceptions
## See: http://stackoverflow.com/a/25642699
#.config ($provide) ->
#    $provide.decorator '$exceptionHandler', ($delegate) ->
#        (exception, cause) ->
#            $delegate exception, cause
#            throw exception
#            # XXX app may restart inadvertently if we throw exceptions here
