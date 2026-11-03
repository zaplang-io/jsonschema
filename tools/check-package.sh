#!/bin/sh
set -eu
root=$(cd "$(dirname "$0")/.." && pwd)
zap=${ZAP:-zap}
case "$zap" in
    /*) ;;
    */*) zap=$(cd "$(dirname "$zap")" && pwd)/$(basename "$zap") ;;
esac
build=$(mktemp -d "${TMPDIR:-/tmp}/jsonschema-package.XXXXXX")
trap 'rm -rf "$build"' EXIT HUP INT TERM
(cd "$root" && "$zap" publish --dry-run)
mkdir -p "$build/src"
cat > "$build/zap.toml" <<MANIFEST
[package]
name = "schema_consumer"
version = "0.1.0"
[dependencies]
jsonschema = { path = "$root" }
MANIFEST
cat > "$build/src/main.zap" <<'ZAP'
import jsonschema

def main():
    auto schema = json.loads("{\"type\":\"integer\"}")
    assert jsonschema.is_valid(json.loads("42"), schema)
    assert not jsonschema.is_valid(json.loads("true"), schema)
    auto schema2 = json.loads("{\"patternProperties\":{\"^item_[0-9]+$\":{\"type\":\"integer\"}},\"unevaluatedProperties\":false}")
    dict[str, JsonValue] registry = {}
    auto compiled = jsonschema.compile(schema2, registry)
    assert jsonschema.is_valid_compiled(json.loads("{\"item_42\":1}"), compiled)
    assert not jsonschema.is_valid_compiled(json.loads("{\"extra\":1}"), compiled)
    print("package consumer: PASS")
ZAP
(cd "$build" && "$zap" zenv create --no-venv && ZAP_ZENV="$build/zenv" "$zap" run src/main.zap)
