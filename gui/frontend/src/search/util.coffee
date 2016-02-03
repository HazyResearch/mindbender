#

angular.module "mindbender.search.util", [
    'json-tree'
]

.directive 'typeaheadClickOpen', ($parse, $timeout)->
    dir =
        restrict: 'A'
        require: 'ngModel'
        link: ($scope, elem, attrs)->

            triggerFunc = (evt)->
                ctrl = elem.controller 'ngModel'
                prev = ctrl.$modelValue || ''
                ctrl.$setViewValue if prev then '' else ' '
                if prev then $timeout -> ctrl.$setViewValue "#{prev}"

            elem.bind 'click', triggerFunc
            elem.bind 'focus', triggerFunc
