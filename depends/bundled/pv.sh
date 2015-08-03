#!/usr/bin/env bash
# install pv (Pipe Viewer)
# See: http://www.ivarch.com/programs/pv.shtml
set -eu

name=pv
version=1.6.0
sha1sum=748280662bdc318c876cc9e759b52050c76f81ee
md5sum=e163d8963c595b2032666724bc509bcc
ext=.tar.bz2

fetch-configure-build-install $name-$version <<END
url=http://www.ivarch.com/programs/sources/$name-$version$ext
sha1sum=$sha1sum
md5sum=$md5sum
END
