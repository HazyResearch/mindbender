#!/usr/bin/env bash
# install jq
# See: http://stedolan.github.io/jq/download/
set -eu

version=1.4

self=$0
name=`basename "$0" .sh`

fullname=jq-${version}

# download prebuilt executable
case $(uname) in
    Linux)
        fetch-verify jq \
            http://stedolan.github.io/jq/download/linux64/jq \
            sha1sum=e820e9e91c9cce6154f52949a3b2a451c4de8af4
        ;;

    Darwin)
        fetch-verify jq \
            http://stedolan.github.io/jq/download/osx64/jq \
            sha1sum=e585d145d56e9f091ca338e72527b50c85290707
        ;;

    *)
        echo >&2 "$(uname): prebuilt jq executable not available"
        false
esac

# install it to the usual place
chmod +x jq
mkdir -p prefix/"$fullname"/bin
ln -f jq prefix/"$fullname"/bin/

# place symlinks for commands under $DEPENDS_PREFIX/bin/
symlink-under-depends-prefix bin -x prefix/"$fullname"/bin/*
