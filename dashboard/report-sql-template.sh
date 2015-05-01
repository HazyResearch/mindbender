#!/usr/bin/env bash
set -eu
inputName=report
outputName=report
compile-xdocs "$inputName".sql.in
run-sql "$(cat "$inputName".sql)" CSV HEADER >"$outputName".csv
json-for "$outputName".csv >"$outputName".json
