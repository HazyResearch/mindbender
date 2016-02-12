#!/usr/bin/env bash
# install node modules
set -eu

self=$0
name=`basename "$0" .sh`

rm -rf node_modules
date >README.md
npm install

relsymlink node_modules "$DEPENDS_PREFIX"/lib/

mkdir -p "$DEPENDS_PREFIX"/bin
cd "$DEPENDS_PREFIX"
for x in lib/node_modules/.bin/*; do
    relsymlink "$x" bin/
done
