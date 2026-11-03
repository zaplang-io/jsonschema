# jsonschema

Pure-Zap JSON Schema validation over the standard library `JsonValue` DOM.
Implements [zaplang-io/zap#316](https://github.com/zaplang-io/zap/issues/316).
This is an initial **2020-12 subset**, not a draft-conformant release yet.

```zap
import jsonschema

def main():
    auto schema = json.loads("{\"type\":\"integer\",\"minimum\":0}")
    auto instance = json.loads("42")
    assert jsonschema.is_valid(instance, schema)
    for error in jsonschema.validate(instance, schema):
        print(error.instance_path + ": " + error.message)
```

`validate(instance, schema)` returns a `list[ValidationError]`; an empty list
means valid. Each error has `instance_path`, `schema_path`, `keyword`, and
`message`. Paths are RFC 6901 JSON Pointers (root is the empty string).
`is_valid(instance, schema)` returns a boolean. `check_schema(schema)` checks
supported keyword shapes without evaluating an instance. All three raise a
`SchemaError` message for malformed/unsupported schemas, separately from
instance validation failures. No input coercion, default insertion, or mutation.
Errors follow schema/object iteration order; do not depend on their ordering.
Composition failures report their keyword; allOf and nested properties retain
child paths. Alternative-branch failures do not leak into successful results.

Supported:

- Boolean schemas; `type` including unions, `enum`, `const`.
- `minimum`, `maximum`, exclusive bounds, `multipleOf`.
- `minLength`/`maxLength` count Unicode codepoints, not bytes or graphemes.
- `properties`, `required`, `additionalProperties`, `propertyNames`,
  `dependentRequired`, `dependentSchemas`, property count bounds.
- `prefixItems`, `items`, `contains`, `minContains`/`maxContains`,
  `uniqueItems`, item count bounds.
- `allOf`, `anyOf`, `oneOf`, `not`, `if`/`then`/`else`; `$defs` shape checking.
- `$schema` may name `https://json-schema.org/draft/2020-12/schema`.
  Omission also selects this subset.

References, resource identifiers/anchors, custom vocabularies, regex
(`pattern`/`patternProperties`), unevaluated keywords, and older-draft
`definitions`/`dependencies`/`additionalItems` currently raise `SchemaError`.
This applies even in inactive branches. Unknown extension keywords are ignored;
`format`, content keywords, and annotations such as `default` are not assertions.
The schema checker checks supported assertion shapes, not the full official
meta-schema. Schema and evaluation nesting are each limited to 128 levels.

Numbers follow Zap's JSON DOM: i64 integers and binary64 floats, with larger
JSON integer literals parsed as binary64. Deep equality preserves exact i64
comparisons and distinguishes booleans from numbers. Arithmetic bounds and
multipleOf currently use binary64; bounds above 2^53 can lose precision.
`multipleOf` accepts a quotient within 1e-9 of an integer. This policy is
approximate, especially near zero; exact decimal arithmetic is not claimed.
Do not use this subset where exact decimal or arbitrary-precision validation
is required. Object equality ignores key order; array equality preserves order.

Run `sh tools/run-tests.sh` with a codegen-enabled `zap` on PATH (or set `ZAP`).
`--check` runs frontend checks only. `sh tools/check-package.sh` checks packaging
and runs a separate path-dependency consumer. CI runs both with a pinned published
Zap image. No Python runtime or third-party native extension is required.

Build sequence (each is an agent-sized M issue):

1. [Validator foundation](https://github.com/zaplang-io/jsonschema/issues/1).
2. [Resources, references, drafts](https://github.com/zaplang-io/jsonschema/issues/2).
3. [Conformance and release](https://github.com/zaplang-io/jsonschema/issues/3).

Specification references: [2020-12 core](https://json-schema.org/draft/2020-12/json-schema-core)
and [validation](https://json-schema.org/draft/2020-12/json-schema-validation).
