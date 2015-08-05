###
# Search
###

fs = require "fs"
util = require "util"
_ = require "underscore"

# Install Search API handlers to the given ExpressJS app
exports.configureApp = (app, args) ->
    # A handy way to create API reverse proxy middlewares
    # See: https://github.com/nodejitsu/node-http-proxy/issues/180#issuecomment-3677221
    # See: http://stackoverflow.com/a/21663820/390044
    url = require "url"
    httpProxy = require 'http-proxy'
    proxy = httpProxy.createProxyServer {}
    apiProxyMiddlewareFor = (path, target, rewrites) -> (req, res, next) ->
        if req.url.match path
            # rewrite pathname if any rules were specified
            if rewrites?
                newUrl = url.parse req.url
                for [pathnameRegex, replacement] in rewrites
                    newUrl.pathname = newUrl.pathname.replace pathnameRegex, replacement
                req.url = url.format newUrl
            # proxy request to the target
            proxy.web req, res,
                    target: target
                , (err) ->
                    util.log err
        else
            next()

    # Reverse proxy for Elasticsearch
    app.use apiProxyMiddlewareFor /// ^/api/elasticsearch(|.*)$ ///, process.env.ELASTICSEARCH_BASEURL, [
        # pathname /api/elasticsearch must be stripped for Elasticsearch
        [/// ^/api/elasticsearch ///, "/"]
    ]

exports.configureRoutes = (app, args) ->
    searchSchema = JSON.parse fs.readFileSync process.env.DDLOG_SEARCH_SCHEMA
    app.get "/api/search/schema.json", (req, res) ->
        res.json searchSchema

