#!/usr/bin/env bash
# A script to demonstrate using Mindbender with an DeepDive app written in DDlog
set -eux
cd "$(dirname "$0")"

# make sure the commands we need are installed
type deepdive
type mindbender

# download some udf code
mkdir -p udf
download() { curl -fsSRLo udf/$1 https://github.com/HazyResearch/deepdive/raw/master/examples/spouse_example/postgres/ddlog/udf/$1; }
download ext_has_spouse.py
download ext_has_spouse_features.py
download ext_people.py

# run DeepDive
deepdive initdb
deepdive run

# populate search index
mindbender search update

# run a snapshot for dashboard
mindbender snapshot

# start GUI
mindbender search gui
