#!/usr/bin/env bash
# install mongo 
set -eu

version=${DEPENDS_ON_MONGODB_VERSION:-3.0.6}

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
            arch=x86_64 ;;
        i686|i386|i86pc)
            arch=i686 ;;
        *)
            echo >&2 "$arch: Unsupported architecture"
            os= arch=
    esac
fi

if [ -n "$os" -a -n "$arch" ]; then
    # download binary distribution
    fullname="mongodb-${os}-${arch}-${version}"
    tarball="${fullname}.tgz"
    download "https://fastdl.mongodb.org/${os}/${tarball}" "$tarball"
    mkdir -p prefix
    tar xf "$tarball" -C prefix
fi

# place symlinks for commands under $DEPENDS_PREFIX/bin/
symlink-under-depends-prefix bin -x prefix/"$fullname"/bin/*

