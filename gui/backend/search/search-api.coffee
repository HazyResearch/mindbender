###
# Search
###

fs = require "fs"
util = require "util"
_ = require "underscore"
express = require "express"

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

    morgan.token 'json', getJson = (req) ->
        esq = null
        if Object.prototype.toString.call(req.body) == "[object Object]"
            esq = _.clone(req.body)
            if esq.aggs and esq.query
                delete esq.aggs
                delete esq.highlight
        fields = {
            ts: Date.now() / 1000.0,
            time: new Date().toISOString(),
            ip: req.headers['x-forwarded-for'] || req.connection.remoteAddress || req.ip || req.ips,
            url: req.url,
            params: req.params,
            query: req.query,
            method: req.method,
            referer: req.headers.referer,
            user_agent: req.headers['user-agent'],
            content_type: req.headers['content-type'],
            accept_languages: req.headers['accept-language'],
            es: esq
        }
        return JSON.stringify(fields)

    apiProxyMiddlewareFor = (path, target, rewrites) -> (req, res, next) ->
        if req.url.match path
            # rewrite pathname if any rules were specified
            if rewrites?
                newUrl = url.parse req.url
                for [pathnameRegex, replacement] in rewrites
                    newUrl.pathname = newUrl.pathname.replace pathnameRegex, replacement
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

