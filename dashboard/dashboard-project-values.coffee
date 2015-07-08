#!/usr/bin/env coffee
# dashboard-project-values -- Aggregates data for a value of a particular report
#                             collected via report-values across all snapshots 
#
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2015-07-08
fs = require "fs"

[fullValueIndexPath, reportId, valueName] = process.argv[2..]

# parse the full index
{snapshots, reportValues} = try JSON.parse (fs.readFileSync fullValueIndexPath)

# obtain the value array and join with snapshots
values = reportValues?[reportId]?[valueName]
projectedArray =
    for snapshot,i in snapshots
        {snapshot, value: values[i]}

# output the projected result
console.log JSON.stringify projectedArray
