#!/bin/sh
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
build=$(mktemp -d "${TMPDIR:-/tmp}/jsonschema-conformance.XXXXXX")
trap 'rm -rf "$build"' EXIT HUP INT TERM
cp "$root/src/jsonschema.zap" "$build/jsonschema.zap"
mkdir -p "$build/jsonschema"
cp "$root/src/metaschemas.zap" "$root/src/pattern.zap" "$build/jsonschema/"
cp "$root/tools/conformance.zap" "$build/main.zap"
"${ZAP:-zap}" build "$build/main.zap" -o "$build/conformance"
failed=0
for pair in 'draft7 draft-07' 'draft2019-09 2019-09' 'draft2020-12 2020-12'; do
    set -- $pair
    if ! SCHEMA_CORPUS="$root/tests/conformance/$1.json" SCHEMA_DRAFT="$2" timeout 180 "$build/conformance"; then
        failed=1
    fi
done
exit "$failed"
