#!/usr/bin/env coffee
# dashboard-aggregate-values -- Aggregates data collected via report-values for all snapshots 
#
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2015-07-07
fs = require "fs"
_ = require "underscore"
[snapshotNames...] = process.argv[2..]

# load all snapshots
reportValues = {}
snapshots =
    for snapshot,snapshotIndex in snapshotNames
        # read reports.json files and augment to reportValues
        snapshotValuesByReport = (try JSON.parse (fs.readFileSync "snapshot/#{snapshot}/reports.json")) ? {}
        for report,{values:valueByName} of snapshotValuesByReport
            continue unless (_.size valueByName) > 0
            valueArrayByName = (reportValues[report] ?= {})
            for name,value of valueByName
                valueArray = (valueArrayByName[name] ?= [])
                valueArray[snapshotIndex] = value
        # get last modified time
        {mtime} = fs.statSync "snapshot/#{snapshot}/reports.ids"
        {name: snapshot, time: mtime}

# make sure all value arrays have the same length
lastSnapshotIndex = (_.size snapshotNames) - 1
for report,valueArrayByName of reportValues
    for name,valueArray of valueArrayByName
        valueArray[lastSnapshotIndex] ?= null

# output the JSON object
console.log JSON.stringify {snapshots, reportValues}
