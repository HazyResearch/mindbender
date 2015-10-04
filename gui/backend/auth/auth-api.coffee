###
# Auth
###


# Set this to true if you want to require users to login
REQUIRES_LOGIN = false

# Set this to true if you only want to grant access to users which you have manually added using above commands
ONLY_AUTHORIZED = false

# Shown when access denied
REQUEST_EMAIL = "email@email"

GOOGLE_CLIENT_ID = 'YOUR_GOOGLE_CLIENT_ID'
GOOGLE_CLIENT_SECRET = 'YOUR_GOOGLE_CLIENT_SECRET'
GOOGLE_CALLBACK_ENDPOINT = 'http://localhost:8000'


fs = require "fs"
util = require "util"
express = require "express"
bodyParser = require 'body-parser'
mongoose = require "mongoose"
cookieParser = require "cookie-parser"
expressSession = require "express-session"
passport = require "passport"
GoogleStrategy = require("passport-google-oauth").OAuth2Strategy

mongoose.connect "mongodb://localhost/mindbender"

Rejected = mongoose.model 'Rejected', {
    googleID: String
    timestamp: Date
}

Authorized = mongoose.model 'Authorized', {
    googleID: String
}

exports.ensureAuthenticated = (req, res, next) ->
  if !REQUIRES_LOGIN || req.isAuthenticated()
    next()
  else
    res.redirect '/auth/google'


exports.configureRoutes = (app, args) ->

    app.use cookieParser()
    app.use expressSession({
      secret: 'keyboard cat',
      resave: true,
      saveUninitialized: true
    })
    app.use passport.initialize()
    app.use passport.session()

    app.use bodyParser.json()
    app.use (bodyParser.urlencoded extended: true)

    app.get "/api/auth/authorized", (req, res) ->
        Authorized.find {}, (err, users) ->
            res.send(users)

    app.post "/api/auth/authorized", (req, res) ->
        googleID = req.body.googleID
        na = new Authorized { googleID: googleID }
        na.save (err, na) ->
            if err
                return res.send err
            return res.send "Ok"

    app.delete "/api/auth/authorized/:googleID", (req, res) ->
        Authorized.find({ 'googleID': req.params.googleID }).remove().exec()
        return res.send "Ok"

    passport.serializeUser (user,done) ->
      done null, user

    passport.deserializeUser (obj, done) ->
      done null, obj

    passport.use new GoogleStrategy({
        clientID: GOOGLE_CLIENT_ID,
        clientSecret: GOOGLE_CLIENT_SECRET,
        callbackURL: "#{GOOGLE_CALLBACK_ENDPOINT}/auth/google/callback"
      },
      (accessToken, refreshToken, profile, done) ->
        Authorized.find { 'googleID': profile.id }, (err, user) ->
            if !user
                return done null, false
            if err
                return done err
            return done null, profile

        #process.nextTick () ->
        #  return done null, profile
      )

    app.get '/auth/google',
      passport.authenticate('google', { prompt:'select_account', scope: [
        'https://www.googleapis.com/auth/plus.login',
        'https://www.googleapis.com/auth/userinfo.email',
        'https://www.googleapis.com/auth/userinfo.profile'
      ]}),
      (req, res) -> ''
        # The request will be redirected to Google for authentication, so this
        # function will not be called.

    app.get '/auth/google/callback',
      passport.authenticate('google', { failureRedirect: '/login' }),
      (req, res) ->
        googleID = req.user.id
        if ONLY_AUTHORIZED
          Authorized.findOne { 'googleID': googleID }, (err, user) ->
            if !user || err
                req.logout()
                req.session.destroy (err) ->
                   return res.send "Access denied: Please send your GoogleID (#{googleID}) to " +
                       "#{REQUEST_EMAIL} to request access."
            else req.session.save (err) ->
                return res.redirect '/'
        else
          req.session.save (err) ->
            return res.redirect '/'

    app.get '/user', (req, res) ->
      res.send req.user

    app.get '/logout', (req, res) ->
      req.logout()
      req.session.destroy (err) ->
        res.redirect '/'





