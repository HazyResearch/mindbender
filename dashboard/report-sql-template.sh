#!/usr/bin/env bash
# Common report.sh for report.sql.in-based report templates
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2015-04-29
set -eu
inputName=report
outputName=report
compile-xdocs "$inputName".sql.in
run-sql "$(cat "$inputName".sql)" CSV HEADER >"$outputName".csv
json-for "$outputName".csv >"$outputName".json
