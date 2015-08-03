#!/usr/bin/env bash
# install jq
# See: http://stedolan.github.io/jq/download/
set -eu

version=1.5rc2

self=$0
name=`basename "$0" .sh`

fullname=jq-${version}

# download prebuilt executable
case $(uname) in
    Linux)
        fetch-verify jq \
            https://github.com/stedolan/jq/releases/download/$fullname/jq-linux-x86_64 \
            sha1sum=ec498ea174ab4e696d02016e2ad47fbdec2b3aa3
        ;;

    Darwin)
        fetch-verify jq \
            https://github.com/stedolan/jq/releases/download/$fullname/jq-osx-x86_64 \
            sha1sum=b5ac856d9f900bd65a56862685851bf86b2f4a19
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
