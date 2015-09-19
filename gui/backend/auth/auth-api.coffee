###
# Auth 
###

fs = require "fs"
util = require "util"
express = require "express"
mongoose = require "mongoose/"

mongoose.connect "mongodb://localhost/MyDatabase"

Schema = mongoose.Schema
UserDetail = new Schema {
      username: String
      password: String
    }, {
      collection: 'userInfo'
    }
UserDetails = mongoose.model 'userInfo', UserDetail



