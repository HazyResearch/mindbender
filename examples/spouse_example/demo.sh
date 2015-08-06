#!/usr/bin/env bash
# A script to demonstrate using Mindbender with an DeepDive app written in DDlog
set -eux
cd "$(dirname "$0")"

# make sure the commands we need are installed
type deepdive
type mindbender

# run DeepDive
deepdive initdb
deepdive run

# populate search index
mindbender search update

# run a snapshot for dashboard
mindbender snapshot

# start GUI
mindbender search gui
