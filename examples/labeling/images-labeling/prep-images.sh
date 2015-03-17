#!/usr/bin/env bash
# A script for preparing a list of images from Flickr
# Author: Jaeho Shin <netj@cs.stanford.edu>
# Created: 2015-03-11
set -eu

: ${FLICKR_API_KEY:=8a5a5d54b60845668b6b14c898c185ed}

tag=${1:-cat}
url='https://api.flickr.com/services/rest/?api_key='"$FLICKR_API_KEY"
url+='&method=flickr.photos.search'
url+='&format=json'
url+='&nojsoncallback=1'
url+='&extras=url_m,owner_name,tags'
url+='&sort=interestingness-desc'
url+='&tag_mode=all'
url+="&tags=$tag"
curl "$url" >flickr-"${tag}".json
mindbender hack coffee -e '
fs = require "fs"
stdin = fs.readFileSync "/dev/stdin"
try search_result = JSON.parse stdin
catch err then eval "feed = #{stdin}"
photos = search_result?.photos?.photo
for photo in photos
    photo.link = "http://www.flickr.com/photos/#{photo.ownername}/#{photo.id}/"
    (photo.media ?= {}).m = photo.url_m
console.log JSON.stringify photos, null, 1
' <flickr-"${tag}".json >images-"${tag}".json
ln -sfnv images-"${tag}".json images.json
