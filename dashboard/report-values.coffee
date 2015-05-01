#!/usr/bin/env coffee
# report-values -- Writes given key-value pairs to the report.json file (or $JSON_FILE)
# report-values KEY=VALUE...
#
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2015-02-11

fs = require "fs"
jsonFile = process.env.JSON_FILE ? "report.json"
keyValuePairs = process.argv[2..]

obj =
    if jsonFile is "-" then {}
    else (try JSON.parse (fs.readFileSync jsonFile)) ? {}

for kv in keyValuePairs
    [key] = kv.split "=", 1
    value = kv.substring (key.length + 1)
    obj[key] =
        try JSON.parse value # see if the value looks like JSON
        catch err then value # or treat it simply as string

if jsonFile is "-"
    console.log JSON.stringify obj
else
    fs.writeFileSync jsonFile, JSON.stringify obj
