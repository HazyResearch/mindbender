#!/usr/bin/env bash
# Common report.sh for data.sql.in-based report templates
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2015-04-29
set -eu
inputName=data
outputName=data
EXPAND_PARAMETERS=true \
compile-xdocs "$inputName".sql.in
run-sql "$(cat "$inputName".sql)" format=csv header=1 >"$outputName".csv
json-for "$outputName".csv | transpose-json >"$outputName".json
