#!/usr/bin/env coffee
# report-values -- Writes given key-value pairs to the report.json file (or $JSON_FILE)
# report-values KEY=VALUE...
#
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2015-02-11

fs = require "fs"
jsonFile = process.env.JSON_FILE ? "report.json"
args = process.argv[2..]

obj =
    if jsonFile is "-" then {}
    else (try JSON.parse (fs.readFileSync jsonFile)) ? {}

keyValuePairs =
    if args[0] is "--alternating"  # TODO need better option parsing
        args.shift()
        for i in [0...args.length] by 2
            key = args[i]
            value = args[i+1]
            [key,value]
    else
        for kv in args
            [key] = kv.split "=", 1
            value = kv.substring (key.length + 1)
            [key,value]

for [key,value] in keyValuePairs
    obj[key] =
        try JSON.parse value # see if the value looks like JSON
        catch err then value # or treat it simply as string

if jsonFile is "-"
    console.log JSON.stringify obj
else
    fs.writeFileSync jsonFile, JSON.stringify obj
