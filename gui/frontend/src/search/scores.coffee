#

angular.module "mindbender.search.scores", [
    'elasticsearch'
    'json-tree'
    'ngSanitize'
    'mindbender.auth'
    'ngHandsontable'
    'ui.bootstrap'
]

.directive "scoresTable", ($q, $timeout, $http, hotRegisterer, $compile) ->
    template: """
        <hot-table
          hot-id="myTable"
          settings="db.settings"
          datarows="db.items">
        </hot-table>
        """
    controller: ($scope) ->

        $scope.phoneRenderer = (hotInstance, td, row, col, prop, value, cellProperties) =>
            Handsontable.renderers.TextRenderer.apply(this, arguments)
            td.innerHTML = "<a style='cursor:pointer; margin-right: 4px;'
                        data-toggle='tooltip' title='New search with this filter'
                        ng-click=\"search.doNavigate($event, 'phones', '" +value+"', true)\">" +
                        value + "</a>"
            $compile(angular.element(td))($scope)

        $scope.locRenderer = (hotInstance, td, row, col, prop, value, cellProperties) =>
            Handsontable.renderers.TextRenderer.apply(this, arguments)
            if value == 'Unknown'
                value = ''
            if value.length > 50
                value = value.substring(0,50)
            td.innerHTML = value

        $scope.scoreRenderer = (hotInstance, td, row, col, prop, value, cellProperties) =>
            Handsontable.renderers.TextRenderer.apply(this, arguments)
            td.innerHTML = '<div style="height:15px;width:' + Math.round(parseFloat(value) * 50.0) + 'px;background-color:#f0ad4e"></div>'

        $scope.columns = [
          {
           data:'phone_number'
           title:'Phone Number'
           renderer:$scope.phoneRenderer
           readOnly:true
          },
          { data:'ads_count', title:'#Ads', readOnly:true, type:'numeric' },
          { data:'reviews_count', title:'#Reviews', readOnly:true, type:'numeric' },
          { data:'overall_score', title:'Overall', readOnly:true, renderer:$scope.scoreRenderer },
          { data:'badass_score', title:'Organized', readOnly:true, renderer:$scope.scoreRenderer },
          { data:'dumbass_score', title:'Suspicious', readOnly:true, renderer:$scope.scoreRenderer },
          { data:'city', title:'City', readOnly:true, renderer:$scope.locRenderer }
        ]

        $scope.db = {
           settings : {
               colHeaders: true
               rowHeaders: true
               contextMenu: true
               columns: $scope.columns
               afterGetColHeader: (col, TH) =>
                   if col > 0 && col < 8
                      TH.innerHTML = '<span ng-click="sortByColumn(' + col +
                          ')" style="cursor:pointer;padding-left:5px;padding-right:5px">' +
                          $scope.columns[col].title + '</span>'
                      $compile(angular.element(TH.firstChild))($scope)
           }
           items : []
        }

        $scope.sortByColumn = (col) =>
            field = $scope.columns[col].data
            if field.endsWith('_score') || field.endsWith('_count')
                field = field + ' DESC'
            $scope.fetchScores(field)

    link: ($scope, $element) ->

        $scope.fetchScores = (sort_order) =>
            $http.get "/api/scores", { params: {sort_order:sort_order} }
                  .success (data) =>
                      $scope.db.items = data
                  .error (err) =>
                      console.error err.message

        $scope.fetchScores('overall_score DESC')
