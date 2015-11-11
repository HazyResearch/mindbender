#!/usr/bin/env bash
# install annotatorjs 
set -eu

version=${DEPENDS_ON_ANNOTATOR_VERSION:-1.2.10}

self=$0
name=`basename "$0" .sh`

download() {
    local url=$1; shift
    local file=$1; shift
    [ -s "$file" ] || curl -C- -RLO "$url"
}


fullname="annotator.${version}"
zipname="${fullname}.zip"
download "https://github.com/openannotation/annotator/archive/v${version}/${zipname}" "${zipname}"

mkdir -p prefix
unzip -u "${zipname}" -d prefix

