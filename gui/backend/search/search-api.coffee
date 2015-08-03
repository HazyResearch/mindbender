###
# Search
###

httpProxy = require "http-proxy"
url = require "url"
util = require "util"
path = require "path"
_ = require "underscore"

# Install Dashboard API handlers to the given ExpressJS app
exports.init = (app) ->
    # bodyParser middleware does not play well with http-proxy, requiring following
    # piece of "restreamer" code to mitigate the hanging issue.  See:
    # https://github.com/nodejitsu/node-http-proxy/issues/180#issuecomment-62022286
    app.use (req, res, next) ->
        req.removeAllListeners "data"
        req.removeAllListeners "end"
        do next
        process.nextTick ->
            req.emit "data", JSON.stringify req.body if req.body
            req.emit "end"

    # Get ready to set up reverse proxies mapping paths to internal servers
    proxy = httpProxy.createProxyServer {}
    reverseProxy = (path, target, rewrites) ->
        app.all path, (req, res) ->
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

    # Reverse proxy for Elasticsearch
    appName = process.env.ELASTICSEARCH_INDEX_NAME ? path.basename process.env.DEEPDIVE_APP
    reverseProxy /// ^/api/elasticsearch(|.*)$ ///, "#{process.env.ELASTICSEARCH_BASEURL}/#{appName}", [
        # pathname /api/elasticsearch must be stripped for Elasticsearch
        [/// ^/api/elasticsearch ///, "/"]
    ]

