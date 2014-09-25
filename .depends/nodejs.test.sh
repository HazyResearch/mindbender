#!/usr/bin/env bash

# check nodejs version
version=${DEPENDS_ON_NODE_VERSION:-v0.10.26}

if ! type node npm &>/dev/null || [[ $(node --version) < $version ]]; then
    echo >&2 "nodejs >= $version not found"
    false
fi
