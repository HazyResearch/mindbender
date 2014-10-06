#!/usr/bin/env bash
# install Scala
set -eu

name=scala
version=${DEPENDS_ON_SCALA_VERSION:-2.11.2}
# TODO sha1sum?
ext=.tgz

fetch-configure-build-install $name-$version <<END
url=http://downloads.typesafe.com/${name}/${version}/${name}-${version}.tgz
custom-configure() { :; }
custom-build() { :; }
custom-install() { cp -a * "\$2"/; }
END

# place symlinks for commands to $DEPENDS_PREFIX/bin/
mkdir -p "$DEPENDS_PREFIX"/bin
for x in bin/*; do
    [ -x "$x" ] || continue
    relsymlink "$x" "$DEPENDS_PREFIX"/bin/
done
