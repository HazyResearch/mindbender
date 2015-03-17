#!/usr/bin/env bash
# A script for preparing a list of images from Flickr
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2015-03-11
set -eu

tag=${1:-cat}
curl 'http://api.flickr.com/services/feeds/photos_public.gne?format=json&nojsoncallback=1&tags='"$tag"'' >flickr-"${tag}".json
mindbender hack coffee -e '
fs = require "fs"
stdin = fs.readFileSync "/dev/stdin"
try feed = JSON.parse stdin
catch err then eval "feed = #{stdin}"
console.log JSON.stringify feed?.items, null, 1
' <flickr-"${tag}".json >images-"${tag}".json
ln -sfnv images-"${tag}".json images.json
