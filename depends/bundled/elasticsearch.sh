#!/usr/bin/env bash
# install elasticsearch
set -eu

version=${DEPENDS_ON_ELASTICSEARCH_VERSION:-1.7.1}

self=$0
name=`basename "$0" .sh`

fullname=elasticsearch-${version}
tarball=${fullname}.tar.gz

fetch-verify $tarball \
    https://download.elastic.co/elasticsearch/elasticsearch/${tarball} \
    sha1sum=https://download.elastic.co/elasticsearch/elasticsearch/${tarball}.sha1.txt

mkdir -p prefix
tar xf "$tarball" -C prefix

# place symlinks for commands under $DEPENDS_PREFIX/bin/
symlink-under-depends-prefix bin -x prefix/"$fullname"/bin/*
