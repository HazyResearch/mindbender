angular.module "mindbender.dashboard", [
    "ui.ace"
    'ui.bootstrap'
    'ui.sortable'
]

.service "Dashboard", ($rootScope, $location, $http) ->
    NUM_MOST_RECENT_SNAPSHOTS_TO_SHOW = 10

    class Dashboard
        constructor: ->
            console.log "Dashboard initializing"

            # prepare array of links for navbar
            $rootScope.navLinks = [
                { url: '#/dashboard', name: 'Dashboard' }
                { url: '#/snapshot-run', name: 'Run Snapshot' }
                { url: '#/snapshot-template/edit', name: 'Configure Templates' }
                { url: '#/snapshot/', name: 'View Snapshots' }
                { url: '#/trends', name: 'Trends' }
            ]
            do @updateNavLinkForSnapshots
            $rootScope.isNavLinkActive = (navLink) ->
                matchesLocation = ({url}) -> url is "##{$location.$$url}"
                (matchesLocation navLink) or
                    not (_.isEmpty navLink.links) and
                        (_.any navLink.links, matchesLocation)
            $rootScope.location = $location

        updateNavLinkForSnapshots: (snapshotParams) =>
            # query string to append
            qs =
                if _.isEmpty snapshotParams then ""
                else "?#{"#{encodeURIComponent k}=#{encodeURIComponent v}" for k,v of snapshotParams}"
            # how to populate snapshot links for navbar
            updateLinks = =>
                navLinkForSnapshots = _.find $rootScope.navLinks, name: "View Snapshots"
                navLinkForSnapshots.links =
                    for snapshotId in $rootScope.mostRecentSnapshots
                        # TODO use different style to indicate whether snapshotParams is applicable to this snapshot or not
                        { url: "#/snapshot/#{snapshotId}/#{qs}", name: snapshotId }
                if $rootScope.numSnapshotsTotal > NUM_MOST_RECENT_SNAPSHOTS_TO_SHOW
                    navLinkForSnapshots.links = [
                        navLinkForSnapshots.links...
                        { isDivider: yes }
                        { url: navLinkForSnapshots.url, name: "View All" }
                    ]
            # after getting the snapshots from backend
            if $rootScope.mostRecentSnapshots?
                do updateLinks
            else
                $rootScope.mostRecentSnapshots = []
                @getSnapshotList()
                    .success (snapshots) =>
                        $rootScope.mostRecentSnapshots = _.first snapshots, NUM_MOST_RECENT_SNAPSHOTS_TO_SHOW
                        $rootScope.numSnapshotsTotal = snapshots.length
                        do updateLinks

        getSnapshotList: =>
            $http.get "/api/snapshot"

        getReportValueList: (callback) =>
            if @reportValues
                callback @reportValues
            else
                $http.get "/api/report-value/"
                    .success (data) =>
                        @reportValues = data # caching
                        callback @reportValues

        isNumeric: (array) =>
            for a in array
                if isNaN(a)
                    return false
            return true

        # TODO move some common parts to the Dashboard class

    # the singleton instance registered as an Angular service
    new Dashboard

.config ($routeProvider) ->
    $routeProvider.when "/dashboard",
        brand: "DeepDive", brandIcon: "dashboard"
        title: "Dashboard - DeepDive"
        templateUrl: "dashboard/index.html"
        controller: "IndexCtrl"

    $routeProvider.when "/snapshot-run",
        brand: "DeepDive", brandIcon: "dashboard"
        title: "Run Snapshot - Dashboard - DeepDive"
        templateUrl: "dashboard/snapshot-run.html"
        controller: "SnapshotRunCtrl"

    $routeProvider.when "/snapshot/",
        brand: "DeepDive", brandIcon: "dashboard"
        title: "All Snapshots - Dashboard - DeepDive"
        templateUrl: "dashboard/snapshot-list.html"
        controller: "SnapshotListCtrl"

    $routeProvider.when "/snapshot/:snapshotId/",
        brand: "DeepDive", brandIcon: "dashboard"
        title: "Snapshot {{snapshotId}} - Dashboard - DeepDive"
        templateUrl: "dashboard/snapshot-view-reports.html"
        controller: "SnapshotReportsCtrl",
        reloadOnSearch: false

    $routeProvider.when "/snapshot-template/edit",
        brand: "DeepDive", brandIcon: "dashboard"
        title: "Edit Template ({{template}}) - Dashboard - DeepDive"
        templateUrl: "dashboard/snapshot-template-editor.html"
        controller: "EditTemplatesCtrl",
        reloadOnSearch: false

    $routeProvider.when "/trends",
        brand: "DeepDive", brandIcon: "dashboard"
        title: "Trends - Dashboard - DeepDive"
        templateUrl: "dashboard/trends.html"
        controller: "ReportValueListCtrl"

    $routeProvider.when "/trend/:reportId*/:valueName",
        brand: "DeepDive", brandIcon: "dashboard"
        title: "Trend for {{reportId}}/{{valueName}} - Dashboard - DeepDive"
        templateUrl: "dashboard/trend.html"
        controller: "ReportValueCtrl"

.controller "IndexCtrl", ($scope, $http, Dashboard) ->
    $scope.charts = []

    renderDashboard = (reportValueSet) ->
        $http.get "/api/dashboard/values/"
            .success (data, status, headers, config) ->
                $scope.chartSnapshotsConfig = {
                    reportValues: reportValueSet.reportValues
                    snapshots: reportValueSet.snapshots
                    start: 0
                    end: reportValueSet.snapshots.length - 1
                    type: "values"
                    hideNulls: false
                    dashboardValues: data
                    chartsPerRow: 3
                    minimalDisplay: true
                }

                i = 0
                for reportValue in data
                    $scope.charts[i] = [] if !$scope.charts[i]
                    $scope.charts[i].push({ report: reportValue.report, value: reportValue.value, isNumeric: Dashboard.isNumeric($scope.chartSnapshotsConfig.reportValues[reportValue.report][reportValue.value]) })

                    i++ if $scope.charts[i].length == $scope.chartSnapshotsConfig.chartsPerRow

    Dashboard.getReportValueList(renderDashboard)


.controller "SnapshotRunCtrl", ($scope, $http, Dashboard) ->
    $scope.title = "Run Snapshot"

    loadConfigs = (switchToConfig) ->
        $http.get "/api/snapshot-config/"
            .success (data, status, headers, config) -> 
                $scope.configs = data
                if switchToConfig
                    $scope.currentSnapshotConfig = switchToConfig
                else
                    $scope.currentSnapshotConfig = data[0]

    loadConfigs(localStorage.lastSnapshotConfig)

    $http.get "/api/snapshot-template/"
        .success (data, status, headers, config) -> 
            $scope.templates = data 

    $scope.$watch "currentSnapshotConfig", (snapshotConfig) ->
        if snapshotConfig
            localStorage.lastSnapshotConfig = snapshotConfig
            $http.get "/api/snapshot-config/" + snapshotConfig
                .success (data, status, headers, config) -> 
                    $scope.configTemplates = data

    $scope.addTemplate = () ->
        $scope.configTemplates.push({"reportTemplate":"", "params": {}})

    $scope.updateParams = (configTemplate) ->
        $http.get "/api/snapshot-template/" + configTemplate.reportTemplate
            .success (data, status, headers, config) -> 
                for param in Object.keys(data.params)
                    data.params[param] = data.params[param]['defaultValue']

                configTemplate.params = data.params


    $scope.removeTemplate = (template_key) ->
        $scope.configTemplates.splice(template_key, 1)

    $scope.updateConfig = () ->
        $http.put("/api/snapshot-config/" + $scope.currentSnapshotConfig, $scope.configTemplates)
    
    $scope.deleteConfig = () ->
        $http.delete("/api/snapshot-config/" + $scope.currentSnapshotConfig)
        delete $scope.configs[$scope.currentSnapshotConfig]
        $scope.currentSnapshotConfig = ""

    $scope.copyConfig = () ->
        $http.put("/api/snapshot-config/" + $scope.copySnapshotName, $scope.configTemplates)
            .success (data, status, headers, config) ->
                $scope.loadConfigs($scope.copySnapshotName)

    $scope.createConfig = () ->
        $http.put("/api/snapshot-config/" + $scope.newSnapshotName, "[]")
            .success (data, status, headers, config) ->
                $scope.loadConfigs($scope.newSnapshotName)
                $scope.newSnapshotName = ""

    $scope.runConfig = () ->
        $http.post("/api/snapshot", { snapshotConfig: $scope.currentSnapshotConfig })

.controller "SnapshotListCtrl", ($scope, $http, Dashboard) ->
    $scope.title = "View Snapshots"

    $http.get "/api/snapshot"
        .success (data, status, headers, config) -> 
            $scope.snapshots = data


.controller "SnapshotReportsCtrl", ($scope, $http, $routeParams, $location, $sce, Dashboard, DashboardDataUtils) ->
    $scope.snapshotId = $routeParams.snapshotId
    $scope.title = "Snapshot " + $routeParams.snapshotId
    $scope.loading = false
    $scope.tabs = {
        table: { }
        bar: { show: false }
        scatter: { show: false }
    }
    $scope.report = { formattedReport: { name: "" } }

    reportNotFound = (report_key) ->
        $scope.reportLoadError = "#{report_key} does not exist in snapshot #{$routeParams.snapshotId}"

    $scope.loadReport = (report_key) ->
        $scope.loading = true
        $scope.reportLoadError = null
        $location.search('report', report_key)
        reportIdFull = "#{$routeParams.snapshotId}/#{report_key}"

        # TODO check report_key from $scope.reports first

        $http.get "/api/snapshot/#{reportIdFull}"
            .success (result, status, headers, config) -> 
                $scope.loading = false
                $scope.currentReport = report_key

                if result[report_key]
                    if result[report_key].markdown?
                        result[report_key].html = $sce.trustAsHtml marked result[report_key].markdown
                else
                    return reportNotFound report_key

                $scope.report = result[report_key]

                for data_key of $scope.report.data
                    $scope.report.data[data_key].table = DashboardDataUtils.normalizeData $scope.report.data[data_key].table

                if $scope.report.html
                    $scope.report.isFormatted = false
                else
                    $scope.report.isFormatted = true
                    data_name = Object.keys($scope.report.data)[0]
                    $scope.report.formattedReport = $scope.report.data[data_name]
                    $scope.report.formattedReport.name = data_name

                    $scope.tabs.bar.show = false
                    $scope.tabs.scatter.show = false

                    chart = $scope.report.formattedReport.chart
                    if chart
                        if $scope.report.formattedReport.table.columns[chart.y]?.isNumeric
                            $scope.tabs.bar.show = true
                            $scope.tabs.scatter.show = $scope.report.formattedReport.table.columns[chart.x]?.isNumeric

                    $scope.tabs.bar.active = $scope.tabs.bar.show
                    $scope.tabs.table.active = !$scope.tabs.bar.active

                Dashboard.updateNavLinkForSnapshots $location.search()

            .error (data, status, headers, config) ->
                $scope.loading = false
                $scope.currentReport = report_key
                $scope.reportLoadError = status
                console.error "#{reportIdFull}: #{status} error while loading"

    loadReportAndUpdateSideNav = ->
        return unless $scope.reports?
        return if $scope.loading
        search_report = $location.search().report
        return unless search_report?
        if $scope.reports[search_report]?
            $scope.loadReport(search_report)
            traverse_nav = $scope.nav
            for s in search_report.split "/"
                traverse_nav[s]['$show'] = true
                traverse_nav = traverse_nav[s]
        else
            reportNotFound search_report

    do $scope.reloadSnapshot = ->
        $http.get "/api/snapshot/#{$routeParams.snapshotId}"
            .success (data, status, headers, config) -> 
                $scope.snapshot = data
                $scope.reports = data.reports
                $scope.sortReports(Object.keys(data.reports))
                loadReportAndUpdateSideNav()
                Dashboard.updateNavLinkForSnapshots()

    $scope.$watch (-> $location.search().report), (newValue, oldValue) ->
        loadReportAndUpdateSideNav()

    $scope.abortSnapshot = ->
        $http.delete "/api/snapshot/#{$routeParams.snapshotId}"
            .success -> $scope.reloadSnapshot()
            .error   -> $scope.reloadSnapshot()

    $scope.buildTree = (report_keys) ->
        root = {
            $leaf: yes
            $show: yes
        }
        for path in report_keys
            # create objects along each path in the tree
            node = root
            # FIXME put children in a separate key: if childName happens to be $leaf or $show, the tree can break
            for childName in path.split "/"
                node[childName] ?= {
                    $leaf: yes
                    $show: yes
                }
                # mark the previous node as non-leaf and traverse a step down
                node.$leaf = no
                node = node[childName]
            # record the $report_key at the end of each path
            node.$report_key = path
        root

    $scope.sortReports = (report_keys) ->
        $scope.nav = $scope.buildTree report_keys


.service "DashboardDataUtils", () ->
    class DashboardDataUtils

        normalizeData: (data) ->
            # try to recognize data format and normalize to a row-major format
            normalized =
                if data instanceof Array
                    # most likely a row-major format
                    if data.length == 0
                        # empty data, no schema
                        { names: [], rows: [] }
                    else if data[0] instanceof Array
                        # array of row arrays, with column names in the first row
                        { names: data[0], rows: data[1..] }
                    else if "object" is typeof data[0]
                        # array of objects
                        columnIdx = {}
                        rows = []
                        for rowObj in data
                            row = []
                            for column,value of rowObj
                                i = (columnIdx[column] ?= _.size columnIdx)
                                row[i] = value
                            rows.push row
                        names = []
                        for name,i of columnIdx
                            names[i] = name
                        { names, rows }
                else if "object" is typeof data
                    if data?.names instanceof Array and data?.rows instanceof Array
                        # data already in normalized form with column names and row arrays
                        { names: data.names, rows: data.rows }
                    else if _.every (_.values data), ((vs) -> vs instanceof Array)
                        # column-major format: object of column value arrays
                        names = _.keys data
                        rows =
                            for v,i in data[names[0]]
                                data[column][i] for column in names
                        { names, rows }
            unless normalized?
                console.error "Unrecognized data format", data
                throw new Error "Cannot normalize data"
            
            # add some metadata & transformation for rendering charts and tables
            columns = {}
            columnsByIndex = {}
            for name,j in normalized.names
                columns[name] = columnsByIndex[j] = {
                    name: name
                    index: j
                    isNumeric: true
                }

            rows = normalized.rows
            # recognize numeric columns
            for name,column of columns
                j = column.index
                valuesAsNum = (+row[j] for row in rows)
                column.isNumeric = not _.some valuesAsNum, _.isNaN
            # force values of numeric columns to be numbers
            for name,column of columns when column.isNumeric
                j = column.index
                for row,i in rows
                    v = row[j]
                    row[j] =
                        if v? and v isnt "" then +v
                        else null # replacing empty strings to null
            
            { columns, columnsByIndex, data: rows }

    new DashboardDataUtils


.controller "EditTemplatesCtrl", ($scope, $http, $location, Dashboard) ->
    $scope.title = "Configure Templates"
    $scope.template = {}

    $scope.loadTemplates = (switchToTemplate) ->
        $http.get "/api/snapshot-template/"
            .success (data, status, headers, config) -> 
                $scope.templateList = data
                if switchToTemplate
                    $location.search('template', switchToTemplate)
                else
                    $location.search('template', data[0])

    $scope.loadTemplates($location.search()['template'])

    $scope.$watch (-> $location.search()['template']), (newValue) ->
        if newValue
            $scope.currentTemplateName = newValue
            localStorage.lastTemplate = $scope.currentTemplateName

            $http.get "/api/snapshot-template/" + $scope.currentTemplateName
                .success (data, status, headers, config) ->
                    $scope.template = $.extend({}, data)
                    
                    $scope.template.params = []
                    for param in Object.keys(data.params)
                        $scope.template.params.push($.extend({ name: param }, data.params[param]))

                    if data.markdownTemplate
                        $scope.formatted = false
                    else
                        $scope.formatted = true

                    if data.chart
                        $scope.template.hasChart = true
                    else
                        $scope.template.hasChart = false

    if $location.search()['template']
        $scope.loadTemplates($location.search()['template'])
    else
        $scope.loadTemplates(localStorage.lastTemplate)


    removeInheritedTaskParams = () ->
        params = []
        for param in $scope.template.params
            if !param.fromTask
                params.push(param)

        $scope.template.params = params

    $scope.$watch (-> $scope.template.type), (newValue, oldValue) ->
        return if newValue == oldValue

        if newValue == 'report'
            removeInheritedTaskParams()
        else if $scope.template.scope
            $scope.addInheritedParams()

    $scope.changeCurrentTemplate = () ->
        $location.search('template', $scope.currentTemplateName)

    $scope.addVariable = () ->
        $scope.template.params.push({})

    $scope.formatTemplateForUpdate = () ->
        params = {}
        
        for param in $scope.template.params
            if !param.fromTask
                params[param.name] = $.extend({}, param)
                delete params[param.name]['name']

        template = { type: $scope.template.type, scope: $scope.template.scope, params: params }
        if $scope.formatted
            template.sqlTemplate = $scope.template.sqlTemplate
        else
            template.markdownTemplate = $scope.template.markdownTemplate

        if $scope.template.hasChart
            template.chart = $scope.template.chart

        return template

    $scope.updateTemplate = () ->
        $scope.updateTemplateName($scope.currentTemplateName)

    $scope.updateTemplateName = (name, callback) ->
        template = $scope.formatTemplateForUpdate()
        $http.put("/api/snapshot-template/" + name, template)
            .success (data, status, headers, config) ->
                if callback
                    callback()

    $scope.deleteTemplate = () ->
        $http.delete("/api/snapshot-template/" + $scope.currentTemplateName)

    $scope.copyTemplate = () ->
        $scope.updateTemplateName($scope.copyTemplateName, ->
            $scope.loadTemplates($scope.copyTemplateName)
        )

    $scope.createTemplate = () ->
        $http.put("/api/snapshot-template/" + $scope.newTemplateName, { params: {}, sqlTemplate: "" })
            .success (data, status, headers, config) ->
                $scope.loadTemplates($scope.newTemplateName)

    $scope.addInheritedParams = () ->
        $scope.template.inheritedParamsLoading = true

        $http.get "/api/snapshot-template/" + $scope.template.scope.report[0]
            .success (data, status, headers, config) ->
                $scope.template.inheritedParamsLoading = false

                removeInheritedTaskParams()

                i = 0
                for name, details of data.params
                    details.name = name
                    details.fromTask = true

                    if !details.inheritedFrom
                        details.inheritedFrom = $scope.template.scope.report[0]

                    $scope.template.params.splice(i, 0, details)

                    i++

.controller "ReportValueListCtrl", ($scope, $http, $timeout, Dashboard) ->
    $scope.title = "Trends"

    $scope.isNumeric = Dashboard.isNumeric

    renderValues = (reportValueSet) ->
        $scope.chartSnapshotsConfig = {
            reportValues: reportValueSet.reportValues
            snapshots: reportValueSet.snapshots
        }

        $timeout ->
            $(".sparkline").each(() ->
                $(this).highcharts({
                    chart: {
                        margin: [0, 0, 3, -6]
                        backgroundColor: null
                    }
                    title: {
                        text: ''
                    }
                    credits: {
                        enabled: false
                    }
                    legend: {
                        enabled: false
                    }
                    tooltip: {
                        formatter: () -> 
                            return "<b>" + this.y + "</b><br>" + $scope.chartSnapshotsConfig.snapshots[this.x].time
                        style: {
                            padding: 4
                        }
                        hideDelay: 50
                    }
                    plotOptions: {
                        series: {
                            lineWidth: 1
                            states: {
                                hover: {
                                    lineWidth: 1
                                }
                            }
                            marker: {
                               radius: 2
                            }
                        }
                    }
                    series: [{
                        data: $scope.chartSnapshotsConfig.reportValues[$(this).data("report")][$(this).data("valueName")]
                    }]
                })
            )

    Dashboard.getReportValueList(renderValues)


.controller "ReportValueCtrl", ($scope, $http, $routeParams, Dashboard) ->
    $scope.report = $routeParams.reportId
    $scope.valueName = $routeParams.valueName
    $scope.title = "Trend: " + $scope.report + " - " + $scope.valueName

    renderValues = (reportValueSet) ->
        $http.get "/api/dashboard/values/"
            .success (data, status, headers, config) ->
                $scope.onDashboard = false
                for reportValue in data
                    if reportValue.report == $scope.report && reportValue.value == $scope.valueName
                        $scope.onDashboard = true

                 $scope.chartSnapshotsConfig = {
                    reportValues: reportValueSet.reportValues
                    snapshots: reportValueSet.snapshots
                    start: 0
                    end: reportValueSet.snapshots.length - 1
                    type: "values"
                    hideNulls: false
                    isNumeric: Dashboard.isNumeric(reportValueSet.reportValues[$scope.report][$scope.valueName])
                    dashboardValues: data
                }

                $scope.$watch (-> $scope.onDashboard), (onDashboard, oldValue) ->
                    return if onDashboard == oldValue
    
                    reportValue = { report: $scope.report, value: $scope.valueName }

                    if onDashboard
                        $http.post "/api/dashboard/values/", reportValue
                    else
                        dashboardValues = []
                        for dashboardValue in $scope.chartSnapshotsConfig.dashboardValues
                            if !_.isEqual(reportValue, dashboardValue)
                                dashboardValues.push(dashboardValue)

                        $http.put "/api/dashboard/values/", dashboardValues

    Dashboard.getReportValueList(renderValues)


.filter 'capitalize', () ->
    (input) ->
        input[0].toUpperCase() + input.substring(1)


.directive 'flash', ['$document', ($document) ->
    link: (scope, element, attr) ->
        element.on("click", (event) ->
            $('.flash').css('background-color', attr['flash'])
            setTimeout((-> $('.flash').css('background-color', '#FFF')), 1000)
        )
]

.directive 'colorBand', ($compile, $timeout) ->
    template: '<div class="color-band"></div>'
    restrict: 'E'
    scope: {
        chartSnapshotsConfig: '='
    }
    link: (scope, element, attrs) ->
        getColorMap = (values) ->
            uniqueValues = _.uniq(values)

            null_index = uniqueValues.indexOf(null)
            if null_index != -1
                uniqueValues.splice(null_index, 1);

            increment = 360 / uniqueValues.length

            colorMap = {}
            for value, index in uniqueValues
                colorMap[value] = 'hsl(' + (increment * index) + ', 100%, 50%)'

            return colorMap

        scope.$watchCollection (-> scope.chartSnapshotsConfig), (config) ->
            return if !config

            height = 40
            if attrs.height
                height = attrs.height

            increment = 100 / config.snapshots.length
            values = config.reportValues[attrs.report][attrs.valuename]
            colorMap = getColorMap(values)

            for value, index in values
                if value == null
                    element.find('.color-band').append("""
                        <div style="float:left;width:#{increment}%;">&nbsp;</div>
                    """)
                else
                    element.find('.color-band').append("""
                        <a data-toggle="tooltip" title="#{value}" style="float:left;width:#{increment}%;" href="#/snapshot/#{config.snapshots[index].name}/?report=#{attrs.report}"><div style="border:0px solid transparent; border-right-width: 1px"><div style="background-color:#{colorMap[value]};height:#{height}px;"></div></div></a>
                    """)

            element.find('[data-toggle=tooltip]').tooltip()


.directive 'dashboardChart', () ->
    template: '<div class="dashboard-chart"></div>'
    restrict: 'E'
    scope: {
        chartSnapshotsConfig: '='
    }
    link: (scope, element, attrs) ->
        scope.$watchCollection (-> scope.chartSnapshotsConfig), (config) ->
            return if !config

            if config.type == "values"
                renderLineChart(config)
            else
                renderFrequencyChart(config)

        renderLineChart = (config) ->
            values = []
            categories = []
            snapshotValues = []
            for snapshot, index in config.snapshots
                value = config.reportValues[attrs.report][attrs.valuename][index]
                if !config.hideNulls || value != null
                    snapshotValues.push({ value: value, snapshot: snapshot})

            for snapshotValue, index in snapshotValues
                if index >= config.start && index <= config.end
                    values.push(snapshotValue.value)
                    categories.push(snapshotValue.snapshot)

            options = {
                chart: {}
                title: {
                    text: ''
                }
                legend: {
                    enabled: false
                }
                xAxis: {
                    title: {
                        text: 'Snapshot'
                    }
                    categories: categories.map((snapshot) -> snapshot.time)
                    labels: {
                        rotation: -45
                    }
                }
                yAxis: {
                    title: {
                        text: 'Value'
                    }
                }
                plotOptions: {
                    series: {
                        cursor: 'pointer',
                        point: {
                            events: {
                                click: (e) ->
                                    point_index = this.series.data.indexOf(e.point)
                                    location.href = "#/snapshot/" + categories[point_index].name + "/?report=" + attrs.report
                            }
                        }
                    }
                },
                tooltip: {
                    formatter: () -> 
                        return "<b>" + this.y + "</b><br>" + this.x
                }
                series: [{
                    data: values
                }]
            }

            if config.minimalDisplay
                options.chart.height = 200
                options.xAxis.labels.enabled = false
                options.xAxis.title = { text: null }
                options.yAxis.title = { text: null }

            element.find(".dashboard-chart").highcharts(options)

        renderFrequencyChart = (config) ->
            categories = []
            frequencies = []
            values = []
            valueMap = {}

            for value, index in config.reportValues[attrs.report][attrs.valuename]
                if !config.hideNulls || value != null
                    values.push(value)

            for value, index in values
                if index >= config.start && index <= config.end
                    if !valueMap[value]
                        valueMap[value] = 0
                    valueMap[value]++

            if valueMap[null]
                categories.push("null")
                frequencies.push(valueMap[null])
                delete valueMap[null]

            for valueName, frequency of valueMap
                categories.push(valueName)
                frequencies.push(frequency)

            options = {
                chart: {
                    type: "column"
                }
                title: {
                    text: ''
                }
                legend: {
                    enabled: false
                }
                xAxis: {
                    title: {
                        text: 'Value'
                    }
                    categories: categories
                    labels: {
                        rotation: -45
                    }
                }
                yAxis: {
                    title: {
                        text: 'Frequency'
                    }
                }
                tooltip: {
                    formatter: () -> 
                        return "<b>" + this.x + "</b><br>Frequency: " + this.y
                }
                series: [{
                    data: frequencies
                }]
            }

            if config.minimalDisplay
                options.chart.height = 200
                options.xAxis.title = { text: null }
                options.yAxis.title = { text: null }

            element.find(".dashboard-chart").highcharts(options)


.directive 'dashboardSlider', ($timeout) ->
    template: '<div class="dashboard-slider-info"></div><div class="dashboard-slider" style="margin-top: 5px"></div>'
    restrict: 'E'
    scope: {
        chartSnapshotsConfig: '='
    }
    link: (scope, element, attrs) ->
        updateSnapshots = (config) ->
            filteredSnapshots = []
            sliderLength = 0
            if config.hideNulls && attrs.report && attrs.valuename
                for snapshot, index in config.snapshots
                    value = config.reportValues[attrs.report][attrs.valuename][index]
                    if value != null
                        if sliderLength >= config.start && sliderLength <= config.end
                            filteredSnapshots.push(snapshot)

                        sliderLength++
            else
                sliderLength = config.snapshots.length
                for snapshot, index in config.snapshots
                    if index >= config.start && index <= config.end
                        filteredSnapshots.push(snapshot)

            info = """
                #{filteredSnapshots.length} values:
                #{filteredSnapshots[0].time} - #{filteredSnapshots[filteredSnapshots.length - 1].time}
            """
            element.find(".dashboard-slider-info").html(info)

            return { min: 0, max: sliderLength - 1 }

        scope.$watchCollection (-> scope.chartSnapshotsConfig), (config, oldConfig) ->
            return if !config

            if config.hideNulls != oldConfig.hideNulls
                config.start = 0
                config.end = config.snapshots.length - 1

            range = updateSnapshots(config)

            if element.find(".dashboard-slider").slider("instance")
                if config.hideNulls != oldConfig.hideNulls
                    range.values = [0, range.max]
                element.find(".dashboard-slider").slider("option", range)
            else
                element.find(".dashboard-slider").slider({
                    range: true
                    min: 0
                    max: range.max
                    values: [0, range.max]
                    slide: (event, ui) ->
                        $timeout ->
                            config.start = ui.values[0]
                            config.end = ui.values[1]
                            updateSnapshots(config)
                })


.directive 'chart', ($timeout, $compile, $parse, DashboardDataUtils) ->
    template: '<div class="chart"></div><div class="slider"></div>',
    restrict: 'E',
    require: '?^mbTaskArea',
    link: (scope, element, attrs, taskArea) ->
        scope.hasSlider = false
        renderChart = ->
            recursiveMerge = (obj1, obj2) ->
                for k of obj2
                    if typeof obj1[k] == 'object' && typeof obj2[k] == 'object'
                        obj1[k] = recursiveMerge(obj1[k], obj2[k])
                    else
                        obj1[k] = obj2[k]

                return obj1

            binData = (data, numBins, x = "x", y = "y") ->
                bucketSize = Math.ceil(data.length/numBins)
                labels = []
                buckets = []
                i = 0
                bucket = 0
                previousLabel = data[0][x]

                if bucketSize == 1
                    for point in data
                        buckets.push(point[y])
                        labels.push(point[x])
                else
                    for point in data
                        if i >= bucketSize
                            buckets.push(bucket)
                            labels.push("[" + previousLabel.toLocaleString() + ", " + point[x].toLocaleString() + ")")
                            previousLabel = point[x]
                            bucket = 0
                            i = 0
                        bucket += point[y]
                        i++

                    if bucket > 0
                        buckets.push(bucket)
                        labels.push("[" + previousLabel.toLocaleString() + ", " + point[x].toLocaleString() + "]")

                return { buckets: buckets, labels: labels }

            options =
                title:
                    text: attrs.title
                xAxis:
                    title:
                        text: attrs.label
                yAxis:
                    title:
                        text: attrs.yLabel
                legend:
                    enabled: false

            # Get data to chart
            full_data =
                if attrs.data?
                    DashboardDataUtils.normalizeData (scope.$eval attrs.data)
                else if attrs.file?
                    scope.report.data[attrs.file]?.table
                else
                    console.error "No chart data or file attribute specified"
                    null

            return unless full_data?

            # use a column name map (mostly set by directive attrs) to construct the series data
            seriesDataToColumnName =
                name : attrs.pointName
                x    : attrs.axis
                y    : attrs.yAxis
                z    : attrs.zAxis

            seriesDataToColumnIndex = {}
            for key,columnName of seriesDataToColumnName
                i = full_data.columns[columnName]?.index
                seriesDataToColumnIndex[key] = i if i?

            seriesData = []
            for data in full_data.data
                seriesDataPoint = {}
                for key,i of seriesDataToColumnIndex
                    seriesDataPoint[key] = data[i]
                seriesData.push(seriesDataPoint)

            # Apply custom user options
            if attrs.highchartsOptions?
                # TODO move this to bottom, so user can override everything
                options = recursiveMerge options, (scope.$eval attrs.highchartsOptions)

            # Prepare a chart series by type
            chartSeries = switch attrs.type

                when "bar"
                    type: "column"
                    data: seriesData
                    name: attrs.yLabel

                when "scatter", "bubble"
                    type: attrs.type
                    data: seriesData
                    name: attrs.yLabel

                else
                    console.error "#{attrs.type}: Unsupported chart type"
                    null

            if taskArea?
                setUpDialogTable = (point_index) ->
                    columnIndexToSeriesData = _.invert(seriesDataToColumnIndex)

                    dialogTable = $("<table></table>")
                    dialogData = $("<tr></tr>").append("<th>Column</th><th>Value</th><th>Chart Label</th>")

                    for name, info of full_data.columns
                        value = full_data.data[point_index][info.index]

                        nameCell = $("<td></td>").attr("data-task-value", name).html(name)
                        valueCell = $("<td></td>").attr("data-task-value", value).html(value)
                        labelCell = $("<td></td>")

                        if columnIndexToSeriesData[info.index]
                            labelCell.attr("data-task-value", columnIndexToSeriesData[info.index]).html(columnIndexToSeriesData[info.index])

                        dialogData = dialogData.add(
                            $("<tr></tr>").append(nameCell, valueCell, labelCell)
                        )

                    dialogTable.append(dialogData)

                    return dialogTable

                chartSeries.point = { events: { click: (e) ->
                    element.find(".dialog").remove()

                    # this.series.data is equivalent to seriesData, but contains extra Highcharts properties needed to match with e.point
                    point_index = this.series.data.indexOf(e.point)

                    dialogTable = setUpDialogTable(point_index)
                    eDialog = $('<div class="dialog"></div>').append(dialogTable)

                    eDialog.on("click", "td", (e) ->
                        $timeout => taskArea.receiveValue(e, $(this).data("task-value"))
                    )
                    eDialog.dialog({
                        title: "Task inputs"
                        position: { my: "bottom", at: "center", of: event },
                        appendTo: element.find(".chart")
                    })
                } }

            (options.series ?= []).push chartSeries if chartSeries?

            # Clear slider
            if scope.hasSlider
                element.find('.slider').slider("destroy")
                scope.hasSlider = false

            # Extra work for certain chart types
            switch attrs.type
                when "bar"
                    setUpNormalDialogTable = setUpDialogTable
                    setUpBinnedDialogTable = (point_index) ->
                        dialogTable = $("<table></table>")

                        for name, value of seriesData[point_index]
                            categoryCell = $("<td></td>").attr("data-task-value", seriesDataToColumnName[name]).html(seriesDataToColumnName[name] + ":")
                            valueCell = $("<td></td>")

                            if name == "x"
                                valueCell.attr("data-task-value", options.xAxis.categories[point_index]).html(options.xAxis.categories[point_index])
                            else
                                valueCell.attr("data-task-value", value).html(value)

                            dialogTable.append($("<tr></tr>").append(categoryCell, valueCell))

                        return dialogTable

                    xHasTooManyNumbers = full_data.columns[attrs.axis]?.isNumeric and seriesData.length > 3 ** 3
                    formatChartData = (numBins) ->
                        if (numBins? and numBins < seriesData.length) and xHasTooManyNumbers
                            numBins ?= Math.floor(Math.sqrt(seriesData.length, 1/3))
                            bins = binData(seriesData, numBins)
                            chartSeries.data         = bins.buckets
                            options.xAxis.categories = bins.labels
                            setUpDialogTable         = setUpBinnedDialogTable
                        else
                            chartSeries.data         = seriesData
                            setUpDialogTable         = setUpNormalDialogTable
                            delete options.xAxis.categories

                    if full_data.columns[attrs.axis].isNumeric
                        do formatChartData

                        if xHasTooManyNumbers
                            # Configure slider if X-axis is numeric
                            element.find('.slider').slider({
                                min: 1
                                max: seriesData.length
                                value: chartSeries.data.length
                                slide: (event, ui) ->
                                    formatChartData ui.value
                                    element.find('.chart').highcharts(options)
                            })
                            scope.hasSlider = true
                    else
                        options.xAxis.categories = []
                        for data, i in seriesData
                            options.xAxis.categories.push(data.x)
                            seriesData[i].x = i

                when "bubble"
                    chartSeries.name = attrs.title ? ""

            # Render chart with Highcharts
            $timeout -> element.find('.chart').highcharts(options)

        scope.$watchCollection (-> attrs), renderChart

.directive 'compileHtml', ['$compile', ($compile) ->
    return (scope, element, attrs) ->

        scope.$watch(
            (scope) -> return scope.$eval(attrs.compileHtml),
            (value) -> 
                if value
                    element.html(value.toString())
                    $compile(element.contents())(scope)
        )
]



.directive 'mbTaskArea', () ->
    restrict: 'A',
    controller: ($scope, $http, $location, $timeout) ->
        @templates = {}
        @matcher = { show: false, event: null }
        @boundParams = {}
        @mirroredTaskValues = []
        @selectedTask = null
        @selectedValue = null

        $http.get "/api/snapshot-template/?type=task"
            .success (data, status, headers, config) =>
                @templates = data

        determineType = (string) =>
            if !isNaN(string)
                if Math.floor(string * 1) == string * 1
                    return "int"
                else
                    return "float"
            else
                return "string"

        valuesVerify = (values) =>
            if !@selectedTask
                return false

            for name, param of @templates[@selectedTask].params
                index = Object.keys(@templates[@selectedTask].params).indexOf(name)
                if !valueVerifies(param, values[index])
                    return false

            return true

        valueVerifies = (param, value) =>
            if param.type != null && value != null && param.type != determineType(value)
                return false

            return true

        @receiveValue = (event, value) =>
            @matcher.show = true
            @matcher.event = event

            valueType = determineType(value)
            if valueType != "string"
                value *= 1

            @selectedValue = value

            for name, template of @templates
                show = false
                for paramName, param of template.params
                    param.$selected = valueVerifies(param, value)
                    if param.$selected
                        show = true

                template.$show = show

        @bindParam = (task, param) => $timeout =>
            if task != @selectedTask
                @selectedTask = task
                @boundParams = {}
                for name, paramObj of @templates[task].params
                    if paramObj.defaultValue
                        @boundParams[name] = paramObj.defaultValue

            if @boundParams[param] == @selectedValue
                delete @boundParams[param]
            else
                @boundParams[param] = @selectedValue

            if !Object.keys(@boundParams).length
                @selectedTask = null

            @selectedTask = null  if _.every (_.keys @boundParams), (name) =>
                @boundParams[name] == @templates[task].params[name].defaultValue

            mirrorBoundParams()

        $scope.$watchCollection (=> @boundParams), () =>
            mirrorBoundParams()

        mirrorBoundParams = () =>
            if @selectedTask
                taskValues = []

                for name, param of @templates[@selectedTask].params
                    found = false
                    for boundParam, boundValue of @boundParams
                        if name == boundParam
                            taskValues.push(boundValue)
                            found = true

                    if !found
                        taskValues.push(null)

                @mirroredTaskValues = taskValues

        $scope.$watchCollection (=> @mirroredTaskValues), (newValue, oldValue) =>
            if valuesVerify(@mirroredTaskValues)
                boundParams = {}

                if @selectedTask
                    i = 0
                    for name of @templates[@selectedTask].params
                        if @mirroredTaskValues[i] != null
                            boundParams[name] = @mirroredTaskValues[i]
                        i++

                @boundParams = boundParams
            else
                @mirroredTaskValues = oldValue

        @editValue = (index) =>
            value = prompt("Old Value: " + @mirroredTaskValues[index] + ", new value:")

            if value
                valueType = determineType(value)
                if valueType != "string"
                    value *= 1

                param = @templates[@selectedTask].params[Object.keys(@templates[@selectedTask].params)[index]]
                if valueVerifies(param, value)
                    @mirroredTaskValues[index] = value
                else
                    alert("Invalid type. Expecting " + param.type)

        @clearTask = () =>
            @matcher.show = false
            @selectedTask = null
            @selectedValue = null
            @boundParams = {}

        @runTask = () =>
            if Object.keys(@boundParams).length == Object.keys(@templates[@selectedTask].params).length
                @matcher.show = false
                taskPostData = {
                    taskTemplate: @selectedTask
                    report: $scope.currentReport
                    params: @boundParams
                }

                $http.post("/api/snapshot/LATEST/task/", taskPostData)
                    .success (data, status, headers, config) =>
                        $location
                            .path("/snapshot/#{data.snapshot}")
                            .search("report", data.report)
                    .error (data, status, headers, config) ->
                        # TODO better error message presentation
                        alert "Error while running task #{taskPostData.taskTemplate} on #{taskPostData.report}:\n#{data}"
            else
                # TODO better error message presentation
                alert("Please fill in all task parameters.")


.directive 'mbTable', ($timeout) ->
    template: """
        <table class="table table-striped">
            <thead>
                <tr>
                    <th style="text-align:center" ng-repeat="column in table.columnsByIndex">{{ column.name }}</th>
                </tr>
            </thead>
            <tbody>
                <tr ng-repeat="row in table.data">
                    <td ng-repeat="data in row track by $index" ng-style="table.columnsByIndex[$index].isNumeric && {'text-align':'right'}"><span style="cursor:pointer" ng-click="bindToTask($event, data)">{{ data }}</span></td>
                </tr>
            </tbody>
        </table>
    """,
    restrict: 'E',
    require: '?^mbTaskArea',
    link: (scope, element, attrs, taskArea) ->
        scope.table = scope.report.data[attrs.file].table
        scope.bindToTask = taskArea.receiveValue if taskArea?
        $timeout ->
            options = {
                order: []
            }

            if scope.table.data.length > 25
                options.pageLength = 25

            element.find("table").DataTable(options)


.directive 'mbTaskControl', ($timeout) ->
    template: """
        <div class="btn-group" style="float:right">
            <button type="button" class="btn btn-primary dropdown-toggle" data-toggle="dropdown">
                Tasks <span class="caret"></span>
            </button>
            <div class="dropdown-menu pull-right" style="padding:5px;width:300px">
                <div ng-hide="taskArea.selectedTask">
                    No task selected.
                </div>
                <div ng-show="taskArea.selectedTask">
                    <input type="text" ng-value="taskArea.selectedTask" style="width:248px">
                    <button class="btn btn-default" ng-click="taskArea.clearTask()">X</button>
                    <div style="width:60%;float:left;border:1px solid #000;padding:3px">
                        <div ng-repeat="(paramName, param) in taskArea.templates[taskArea.selectedTask].params" style="list-style-type:none">
                                {{ paramName }}:
                        </div>
                    </div>
                    <div style="width:40%;float:right;border:1px solid #000;padding:3px">
                        <div ui-sortable ng-model="taskArea.mirroredTaskValues" style="overflow:auto">
                            <div style="cursor:pointer;white-space:nowrap" ng-repeat="value in taskArea.mirroredTaskValues track by $index" ng-click="taskArea.editValue($index)">
                                <span class="ui-icon ui-icon-arrowthick-2-n-s" style="float:left;width:20px"></span>
                                <span>{{ value }}</span>
                                &nbsp;
                            </div>
                        </div>
                    </div>
                    <br style="clear:both;">
                    <button class="btn btn-primary" style="margin-top:5px;float:right;" ng-click="taskArea.runTask()">Run Task</button>
                </div>
            </div>
        </div>
        <div id="taskMatcher" style="z-index:1000;position:absolute;top:0px;left:0px;border:2px solid #000;width:300px;height:400px;background-color:#FFF;overflow:auto;padding:5px" ng-show="taskArea.matcher.show">
            <button class="btn btn-default" ng-click="taskArea.matcher.show = false" style="float:right">X</button>
            <h3>Tasks</h3>
            <div ng-repeat="(task, template) in taskArea.templates">
                <div ng-show="template.$show">
                    <span ng-class="{ 'selected-task' : taskArea.selectedTask == task }">
                        {{ task }}
                    </span>
                    (<span ng-repeat="(paramName, param) in template.params" ng-class="{ 'potentialParam': param.$selected }" ng-click="param.$selected && taskArea.bindParam(task, paramName)">{{ paramName }}<span ng-if="(taskArea.boundParams[paramName] && taskArea.selectedTask == task) || param.defaultValue">[{{ taskArea.boundParams[paramName] || param.defaultValue }}]</span>{{$last ? '' : ', '}}</span>)
                </div>
            </div>
        </div>
    """,
    require: '^mbTaskArea',
    restrict: 'E',
    link: (scope, element, attrs, taskArea) ->
        scope.taskArea = taskArea

        angular.element("body").click(($event) ->
            if $event.timeStamp != taskArea.matcher.event?.timeStamp && angular.element($event.target).closest("#taskMatcher").length == 0
                taskArea.matcher.show = false
                scope.$digest()
        )

        # Prevent clicks inside the task dropdown from closing it
        angular.element(".dropdown-menu").click(($event) ->
            $event.stopPropagation()
        )

        scope.$watch (-> taskArea.matcher.event), (event) ->
            return unless event?

            taskMatcher = element.find("#taskMatcher")

            offset = taskMatcher.parent().offsetParent().offset()
            taskMatcher.css("left", event.pageX - offset.left)
            taskMatcher.css("top", event.pageY - offset.top)

.filter "urlEncode", () ->
    (input) -> encodeURIComponent input
