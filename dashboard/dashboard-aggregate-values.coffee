#!/usr/bin/env coffee
# dashboard-aggregate-values -- Aggregates data collected via report-values for all snapshots 
#
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2015-07-07
fs = require "fs"
_ = require "underscore"
[snapshotNames...] = process.argv[2..]

# find all snapshots and their reports.json contents
reportValuesBySnapshot = {}
snapshotsUnordered =
    for snapshot,snapshotIndex in snapshotNames
        # read reports.json files and augment to reportValues
        reportValuesBySnapshot[snapshot] =
            (try JSON.parse (fs.readFileSync "snapshot/#{snapshot}/reports.json")) ? {}
        # get last modified time
        {mtime} = fs.statSync "snapshot/#{snapshot}/reports.ids"
        {name: snapshot, time: mtime}

# order snapshots by timestamp
snapshots = _.sortBy snapshotsUnordered, ({time}) -> time

# reorganize the reportValues
reportValues = {}
for {name:snapshot},snapshotIndex in snapshots
    for report,{values:valueByName} of reportValuesBySnapshot[snapshot]
        continue unless (_.size valueByName) > 0
        valueArrayByName = (reportValues[report] ?= {})
        for name,value of valueByName
            valueArray = (valueArrayByName[name] ?= [])
            valueArray[snapshotIndex] = value

# make sure all value arrays have the same length
lastSnapshotIndex = (_.size snapshots) - 1
for report,valueArrayByName of reportValues
    for name,valueArray of valueArrayByName
        valueArray[lastSnapshotIndex] ?= null

# output the JSON object
console.log JSON.stringify {snapshots, reportValues}
