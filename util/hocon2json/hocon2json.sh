#!/usr/bin/env bash
exec java -jar "$(dirname "$0")/hocon2json.jar" "$@"
