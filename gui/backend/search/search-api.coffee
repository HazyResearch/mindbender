###
# Search
###

fs = require "fs"
util = require "util"
_ = require "underscore"
express = require "express"
Sequelize = require "sequelize"

sequelize = new Sequelize('evidently', process.env.EVIDENTLY_PG_USER || '', '', {
    dialect: 'postgres'
    host: process.env.EVIDENTLY_PG_HOST || 'localhost'
    port: process.env.EVIDENTLY_PG_PORT || 5432
    # storage: process.env.ELASTICSEARCH_HOME + '/dossier.db'  # sqlite fails on concurrent writes
})

Elasticsearch = require('elasticsearch')
elasticsearch = new Elasticsearch.Client {
  host: process.env.ELASTICSEARCH_BASEURL
  log: 'error'
}

# Install Search API handlers to the given ExpressJS app
exports.configureApp = (app, args) ->
    # A handy way to create API reverse proxy middlewares
    # See: https://github.com/nodejitsu/node-http-proxy/issues/180#issuecomment-3677221
    # See: http://stackoverflow.com/a/21663820/390044
    url = require "url"
    httpProxy = require 'http-proxy'
    bodyParser = require('body-parser')
    morgan = require('morgan')
    proxy = httpProxy.createProxyServer {}
    app.enable('trust proxy')

    morgan.token 'json', getJson = (req, res) ->
        esq = null
        if Object.prototype.toString.call(req.body) == "[object Object]"
            esq = _.clone(req.body)
            if esq.aggs and esq.highlight
                delete esq.aggs
                delete esq.highlight

        user = null
        if req.user?
            user = {
                id: req.user.id,
                display_name: req.user.displayName,
                name: req.user.name,
                emails: req.user.emails,
                photos: req.user.photos,
                gender: req.user.gender
            }
        fields = {
            ts: Date.now() / 1000.0,
            millis: Date.now() - req._start,
            time: new Date().toISOString(),
            ip: req.headers['x-forwarded-for'] || req.connection.remoteAddress || req.ip || req.ips,
            url: req._original_url || req.url,
            params: req.params,
            query: req.query,
            method: req.method,
            referer: req.headers.referer,
            user_agent: req.headers['user-agent'],
            content_type: req.headers['content-type'],
            accept_languages: req.headers['accept-language'],
            es: esq,
            user: user
        }
        return JSON.stringify(fields)

    apiProxyMiddlewareFor = (path, target, rewrites) -> (req, res, next) ->
        if req.url.match path
            # rewrite pathname if any rules were specified
            if rewrites?
                newUrl = url.parse req.url
                # Empty query can be particularly slow.
                # We cache it: https://www.elastic.co/guide/en/elasticsearch/reference/1.7/index-modules-shard-query-cache.html
                if req.body and req.body.aggs and not req.body.query
                    if not newUrl.query?
                        newUrl.query = {}
                    newUrl.query.search_type = 'count'
                    newUrl.query.query_cache = 'true'
                for [pathnameRegex, replacement] in rewrites
                    newUrl.pathname = newUrl.pathname.replace pathnameRegex, replacement
                req._original_url = req.url
                req.url = url.format newUrl
            # proxy request to the target
            # restreaming hack from https://github.com/nodejitsu/node-http-proxy/issues/180#issuecomment-97702206
            body = JSON.stringify(req.body)
            req.headers['content-length'] = Buffer.byteLength(body, 'utf8')
            buffer = {}
            buffer.pipe = (dest)->
                process.nextTick ->
                    dest.write(body)
            proxy.web req, res,
                    target: target
                    buffer: buffer
                , (err, req, res) ->
                    res
                        .status 503
                        .send "Elasticsearch service unavailable\n(#{err})"
        else
            next()

    # Reverse proxy for Elasticsearch
    elasticsearchApiPath = /// ^/api/elasticsearch(|/.*)$ ///
    if process.env.ELASTICSEARCH_BASEURL?
        app.use (req, res, next) ->
            req._start = Date.now()
            next()
        app.use(bodyParser.json())

        if process.env.MBSEARCH_LOG_FILE?
            console.log 'INFO: Logging requests at MBSEARCH_LOG_FILE = ' + process.env.MBSEARCH_LOG_FILE
            morgan_opt = {}
            fs = require('fs')
            morgan_opt.stream = fs.createWriteStream(process.env.MBSEARCH_LOG_FILE, {flags: 'a'})
            app.use(morgan(':json', morgan_opt))
        else
            console.log 'WARNING: MBSEARCH_LOG_FILE undefined; not logging.'

        app.use apiProxyMiddlewareFor elasticsearchApiPath, process.env.ELASTICSEARCH_BASEURL, [
            # pathname /api/elasticsearch must be stripped for Elasticsearch
            [/// ^/api/elasticsearch ///, "/"]
        ]

        Dossier = sequelize.define('dossier', {
            dossier_name:
                type: Sequelize.TEXT
                allowNull: false

            user_id:
                type: Sequelize.TEXT
                allowNull: false

            user_name:
                type: Sequelize.TEXT
                allowNull: false

            query_string:
                type: Sequelize.TEXT
                allowNull: false

            query_title:
                type: Sequelize.TEXT

            query_is_doc:
                type: Sequelize.BOOLEAN
                allowNull: false
                defaultValue: false

        }, {
            indexes: [
                {
                    fields: ['dossier_name']
                },
                {
                    fields: ['query_string']
                },
                {
                    unique: true
                    fields: ['dossier_name', 'query_string']
                }
            ]
        })
        Dossier.sync()

        app.get '/api/dossier/', (req, res, next) ->
            if not req.user or not req.user.id
                res
                    .status 400
                    .send 'You must log in to use the dossier service.'
            else
                Dossier.aggregate 'dossier_name', 'DISTINCT', {plain: false}
                    .then (dnames) ->
                        names = _.pluck dnames, 'DISTINCT'
                        res.send JSON.stringify(names)

        app.get '/api/dossier/by_dossier/', (req, res, next) ->
            if not req.user or not req.user.id
                res
                    .status 400
                    .send 'You must log in to use the dossier service.'
            else
                Dossier.findAll
                    where:
                        dossier_name: req.query.dossier_name
                    order: 'query_string'
                .then (matches) ->
                    results = _.map matches, (item) ->
                        query_string: item.query_string
                        query_title: item.query_title
                        query_is_doc: item.query_is_doc
                        user_name: item.user_name
                        ts_created: item.createdAt
                    res.send JSON.stringify(results)

        app.all '/api/dossier/by_query/', (req, res, next) ->
            if not req.user or not req.user.id
                res
                    .status 400
                    .send 'You must log in to use the dossier service.'
            else
                if req.method == 'POST'

                    query = req.body.query_string
                    selected = req.body.selected_dossier_names
                    unselected = req.body.unselected_dossier_names

                    _.each selected, (nm) ->
                        Dossier.findOrCreate
                            where:
                                dossier_name: nm
                                query_string: query
                            defaults:
                                user_id: req.user.id
                                user_name: req.user.displayName || ''
                                query_title: req.body.query_title || null
                                query_is_doc: req.body.query_is_doc || false

                    if unselected and unselected.length
                        Dossier.destroy
                            where:
                                dossier_name: unselected
                                query_string: query

                    res.send 'Dossier API works!'
                else
                    queries = JSON.parse(req.query.queries || '[]') || []
                    Dossier.findAll
                        where:
                            query_string: queries
                        order: 'dossier_name'
                    .then (matches) ->
                        query_to_dossiers = {}
                        _.each matches, (m) ->
                            if m.query_string of query_to_dossiers
                                query_to_dossiers[m.query_string].push m.dossier_name
                            else
                                query_to_dossiers[m.query_string] = [m.dossier_name]

                        Dossier.aggregate 'dossier_name', 'DISTINCT', {plain: false}
                            .then (dnames) ->
                                all_dossiers = _.pluck dnames, 'DISTINCT'
                                result =
                                    all_dossiers: all_dossiers
                                    query_to_dossiers: query_to_dossiers

                                res.send JSON.stringify(result)


        Scores = sequelize.define('scores', {
            phone_number:
                type: Sequelize.TEXT
                allowNull: false

            ads_count:
                type: Sequelize.BIGINT
                allowNull: false

            reviews_count:
                type: Sequelize.BIGINT
                allowNull: false

            organization_score:
                type: Sequelize.DOUBLE
                allowNull: false

            control_score:
                type: Sequelize.DOUBLE
                allowNull: false

            underage_score:
                type: Sequelize.DOUBLE
                allowNull: false

            movement_score:
                type: Sequelize.DOUBLE
                allowNull: false

            overall_score:
                type: Sequelize.DOUBLE
                allowNull: false

            state:
                type: Sequelize.TEXT

            city:
                type: Sequelize.TEXT
        }, {
            indexes: [
                {
                    unique: true
                    fields: ['phone_number']
                },
                {
                    fields: ['overall_score']
                },
                {
                    fields: ['movement_score']
                },
                {
                    fields: ['underage_score']
                },
                {
                    fields: ['control_score']
                },
                {
                    fields: ['organization_score']
                }
            ]
        })
        Scores.sync()

        app.get '/api/scores', (req, res, next) ->
            Scores.findAll
                order: req.query.sort_order 
                limit: 200
            .then (matches) ->
                    #results = _.map matches, (item) ->
                    #    phone_number: item.phone_number
                    #    overall_score: item.overall_score                    
                    results = matches
                    res.send JSON.stringify(results)

        Feedback = sequelize.define('feedback', {
            doc_id:
                type: Sequelize.TEXT
                allowNull: false
            mention_id:
                type: Sequelize.TEXT
            user_name:
                type: Sequelize.TEXT
            value:
                type: Sequelize.TEXT
        }, {
            indexes: [
                {
                    unique: true
                    fields: ['doc_id', 'mention_id']
                }
            ]
        })

        Feedback.sync()

        app.get '/api/feedback/:doc_id', (req, res, next) ->
            Feedback.findAll
                where:
                    doc_id: req.params.doc_id
            .then (matches) ->
                res.send JSON.stringify(matches)

        app.post '/api/feedback', (req, res, next) ->
            #if not req.user or not req.user.id
            #    res
            #        .status 400
            #        .send 'You must log in to use the feedback service.'
            #else
                user_name = ''
                if req.user && req.user.id
                    user_name = req.user.displayName
                obj = {
                    doc_id: req.body.doc_id
                    mention_id: req.body.mention_id
                    user_name: user_name
                    value: req.body.value
                } 
                Feedback.upsert obj 
                .then () ->
                    res.send JSON.stringify(obj)

        Annotation = sequelize.define('annotation', {
            doc_id:
                type: Sequelize.TEXT
                allowNull: false
            mention_id:
                type: Sequelize.TEXT
            user_name:
                type: Sequelize.TEXT
            value:
                type: Sequelize.TEXT
        }, {
            indexes: [
                {
                    unique: true
                    fields: ['doc_id', 'mention_id']
                }
            ]
        })

        Annotation.sync()

        app.get '/api/annotation/:doc_id', (req, res, next) ->
            console.log 'getting annotations ' + req.params.doc_id
            Annotation.findAll
                where:
                    doc_id: req.params.doc_id
            .then (matches) ->
                _.each matches, (m) ->
                    m.value = JSON.parse(m.value)
                    #console.log m.mention_id
                    #console.log m.value
                    #console.log JSON.parse(m.value)
                #nm = _.each matches, (m) ->
                #    m[value] = JSON.parse(m[value])
                #console.log nm
                res.send JSON.stringify(matches)

        app.delete '/api/annotation/:doc_id/:mention_id', (req, res, next) ->
            Annotation.destroy
                where:
                    doc_id: req.params.doc_id
                    mention_id: req.params.mention_id
            .then () ->
                res.send 'Ok' 

        app.post '/api/annotation', (req, res, next) ->
            #if not req.user or not req.user.id
            #    res
            #        .status 400
            #        .send 'You must log in to use the feedback service.'
            #else
                user_name = ''
                if req.user && req.user.id
                    user_name = req.user.displayName

                # we store the user_name in the value object
                value = req.body.value
                value.user_name = user_name
                obj = {
                    doc_id: req.body.doc_id
                    mention_id: req.body.mention_id
                    user_name: user_name
                    value: JSON.stringify(value)
                }

                # update database
                Annotation.upsert obj
                .then () ->
                    res.send JSON.stringify(obj)

                # update ES index
                elasticsearch.update {
                  index: req.body._index
                  type: req.body._type
                  id: req.body.doc_id
                  body: {
                    doc: {
                      annotated_flags: req.body.annotated_flags
                    }
                  }
                }, (err, response) ->
                  if err
                    console.error err

        Tags = sequelize.define('tags', {
            value:
                type: Sequelize.TEXT
                allowNull: false

            is_flag:
                type: Sequelize.BOOLEAN
                allowNull: false
        }, {
            indexes: []
        })

        Tags.sync()

        app.get '/api/tags', (req, res, next) ->
            Tags.findAll
                order: 'value'
            .then (matches) ->
                res.send JSON.stringify(matches)

        app.post '/api/tags', (req, res, next) ->
            obj = {
                value: req.body.value
                is_flag: false
            }
            Tags.upsert obj
            .then () ->
                res.send JSON.stringify(obj)

        app.delete '/api/tags/:value', (req, res, next) ->
            Tags.destroy
                where:
                    value: req.params.value
                    is_flag: false
            .then () ->
                res.send 'OK'
        app.get '/api/tags/maybeRemove/:value', (req, res, next) ->
            value = req.params.value

            # check if tag is still used by an annotation; delete if it is not used
            sequelize.query("select count(*) from annotations where exists(select * from json_array_elements(json_extract_path(value::json, 'tags')) where value::text = '\"" + value + "\"')", { type: sequelize.QueryTypes.SELECT})
                .then (data) =>
                    if data[0].count == '0'
                        # this tag is not being used anymore, if it's not a flag remove it       
                        Tags.destroy
                            where:
                                value: value
                                is_flag: false
                        .then (data) -> 
                            res.status(200).send(String(data))
                    else
                        return res.status(200).send('0')


    else
        app.all elasticsearchApiPath, (req, res) ->
            res
                .status 503
                .send "Elasticsearch service not configured\n($ELASTICSEARCH_BASEURL environment not set)"

exports.configureRoutes = (app, args) ->
    app.use "/api/search/schema.json", express.static process.env.DDLOG_SEARCH_SCHEMA if process.env.DDLOG_SEARCH_SCHEMA?
    app.get "/api/search/schema.json", (req, res) -> res.json {}

    # expose custom search result templates to frontend
    app.use "/search/template", express.static "#{process.env.DEEPDIVE_APP}/mindbender/search-template"
    # fallback to default template
    app.get "/search/template/*.html", (req, res) ->
        res.redirect "/search/result-template-default.html"

