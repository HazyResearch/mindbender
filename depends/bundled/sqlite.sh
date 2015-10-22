#!/usr/bin/env bash
# install sqllite 
set -eu

version=${DEPENDS_ON_SQLITE_VERSION:-3090100}

self=$0
name=`basename "$0" .sh`

download() {
    local url=$1; shift
    local file=$1; shift
    [ -s "$file" ] || curl -C- -RLO "$url"
}

# determine os and arch for downloading
os=$(uname -s)
case $os in
    Darwin) os=osx ;;
    Linux)  os=linux  ;;
    *)
        echo >&2 "$os: Unsupported operating system"
        os=
esac
if [ -z "$os" ]; then
    arch=
else
    arch=$(uname -m)
    case $arch in
        x86_64|amd64)
            arch=x86 ;;
        i686|i386|i86pc)
            arch=x86 ;;
        *)
            echo >&2 "$arch: Unsupported architecture"
            os= arch=
    esac
fi

if [ -n "$os" -a -n "$arch" ]; then
    # download binary distribution
    fullname="sqlite-shell-${os}-${arch}-${version}"
    zipname="${fullname}.zip"
    download "https://www.sqlite.org/2015/${zipname}" "$zipname"
    mkdir -p prefix
    unzip -u "$zipname" -d prefix
fi

# place symlinks for commands under $DEPENDS_PREFIX/bin/
symlink-under-depends-prefix bin -x prefix/"$fullname"/bin/*

