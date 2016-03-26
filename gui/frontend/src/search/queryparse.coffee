#

angular.module "mindbender.search.queryparse", [
    'elasticsearch'
    'json-tree'
    'ngSanitize'
    'mindbender.auth'
    'ngHandsontable'
    'ui.bootstrap'
]


.service "QueryParseService", (elasticsearch, $http, $q, $timeout) ->

    class QueryParseService
        constructor: () ->
            @elastic = elasticsearch

        init: (@elasticsearchIndexName = "_all") =>
            @

        parse_query: (query_text) =>
            return $q (resolve, reject) =>
                require ['/ext/qp/lucene-query.js'], (parser) =>
                    console.log 'parsing : ' + query_text 
                    try
                      results = parser.parse(query_text)
                      console.log results
                      resolve results
                    catch error
                      console.log error
                      reject error

        escape_query_term: (t) => 
            # see https://lucene.apache.org/core/2_9_4/queryparsersyntax.html for details
            # chars = '+ - & | ! ( ) { } [ ] ^ " ~ * ? : \\'.split(' ')
            return t.replace(/[-[\]{}()*+?.,\\^$|&!"~:]/g, "\\$&");

        isSimpleQuery: (pq) =>
            visit = (node) =>
                if 'operator' of node and node['operator'] isnt 'AND' and node['operator'] isnt '<implicit>'
                    return false
                if 'left' of node and 'right' of node
                    return visit(node['left']) and visit(node['right'])
                if 'left' of node
                    return visit node['left']
                if node['boost']
                    return false
                if node['prefix']
                    return false
                if node['proximity']
                    return false
                return true
            return visit(pq)

        normalize_query: (query_text, fetch_dossier_by_name, expanded = {}) =>
            p1 = @parse_query query_text 
            p2 = p1.then (pq) =>

                # to avoid infinite recursion, we need to keep track of which dossiers
                # have been expanded.

                copyAndAdd = (obj, add) ->
                    cp = {}
                    for attr of obj
                        cp[attr] = obj[attr]
                    cp[add] = true
                    return cp

                visit = (node, expanded) =>
                  do (node, expanded) =>
                    `var deferred`
                    `var field`
                    `var p1`
                    `var p2`
                    `var p3`
                    `var op`
                    `var dossier_name`
                    deferred = $q.defer()
                    if 'left' of node and 'operator' of node and 'right' of node
                        field = if node['field']? then node['field'] + ':' else ''
                        p1 = visit node['left'], expanded
                        p2 = visit node['right'], expanded
                        op = node['operator']
                        if op == '<implicit>'
                            op = ''
                        $q.all([p1, p2]).then ((data) =>
                                deferred.resolve field + '(' + data[0] + ' ' + op + ' (' + data[1] + '))'
                            ), ((error) =>
                              deferred.reject error
                            )
                    else if 'left' of node
                        p1 = visit node['left'], expanded
                        p1.then (q) =>
                            field = if 'field' of node then node['field'] + ':' else ''
                            deferred.resolve field + '(' + q + ')'
                          , (error) =>
                            deferred.reject error
                    else if 'field' of node and node['field'] == 'folder'
                        dossier_name = node['term']
                        if expanded[dossier_name]?
                            deferred.reject {
                              'message':'Your query uses a folder that contains a query which itself contains the same folder. Such infinite recursion is not allowed. Please change the queries in your folder.'
                            }
                        else
                          p3 = fetch_dossier_by_name node['term']
                          p3.then (data) =>
                            union = ''
                            ps = []
                            for item in data.data
                                ps.push @normalize_query item.query_string, fetch_dossier_by_name, (copyAndAdd expanded, dossier_name)
                            $q.all(ps).then ((psd) =>
                                union = ''
                                for item in psd
                                    console.log item
                                    if union.length > 0
                                        union = union + ' OR '
                                    union = union + '(' + item + ')'
                                deferred.resolve('(' + union + ')')
                              ),
                              ((error) =>
                                  deferred.reject error)
                            , (error) =>
                              deferred.reject {
                                'message':'Folder "' + node['term'] + '" not found.'
                              }

                    # a condition on a field
                    else if 'field' of node and node['field'] and node['field'] != '<implicit>'
                        # term query
                        if 'term' of node and node['term']
                            deferred.resolve node['field'] + ':"' + @escape_query_term(node['term']) + '"'
                        # range query
                        else if 'term_min' of node
                            # special case: range queries on ages
                            term_min = node['term_min']
                            term_max = node['term_max']
                            if node['field'] == 'ages'
                                if term_min.length == 1
                                    term_min = '0' + term_min
                                if term_min.length > 2
                                    term_min = '99'
                                if term_max.length == 1
                                    term_max = '0' + term_max
                                if term_max.length > 2
                                    term_max = '99'

                            if node['inclusive']
                                deferred.resolve node['field'] + ':' + '[' + term_min + ' TO ' + term_max + ']'
                            else
                                deferred.resolve node['field'] + ':' + '{' + term_min + ' TO ' + term_max + '}'
                        else
                            console.log 'unknown query type'
                    # implicit field
                    else if 'field' of node and node['field'] == '<implicit>'
                        prefix = if 'prefix' of node then node['prefix'] else ''
                        deferred.resolve prefix + '"' + @escape_query_term(node['term']) + '"'

                    else if 'term' of node
                        deferred.resolve '"' + @escape_query_term(node['term']) + '"'
                    else if node.length is 0
                        deferred.resolve ''
                    else
                        console.log 'unhandled case'
                        console.log node
                        deferred.resolve ''
                    return deferred.promise 
                p3 = visit pq, expanded
                p3
            return p2 
                
        mapPositionToQueryTerm: (pq) =>
            map = []
            visit = (node) =>
                if 'left' of node and node['left']
                    visit node['left']
                if 'right' of node and node['right']
                    visit node['right']
                if 'term' of node                    
                    console.log node.location
                    for i in [node.location.start.offset...node.location.end.offset]
                        map[i] = node
            visit pq
            return map

    new QueryParseService
