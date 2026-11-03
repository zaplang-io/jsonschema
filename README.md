# jsonschema

Pure-Zap JSON Schema validation over the standard library `JsonValue` DOM.
Implements [zaplang-io/zap#316](https://github.com/zaplang-io/zap/issues/316).
Supports draft-aware assertion subsets for **2020-12, 2019-09, and draft-07**.
Full draft conformance remains gated on issue #3 (regex and unevaluated tracking).

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
`is_valid(instance, schema)` returns a boolean. `check_schema(schema, dialect="2020-12")`
checks supported keyword shapes and evaluates the schema against the bundled
official meta-schema. All APIs raise a `SchemaError` message for malformed or
unsupported schemas, separately from instance validation failures. No input
coercion, default insertion, or mutation. Errors follow schema/object iteration
order; do not depend on their ordering. Composition failures report their keyword;
allOf and nested properties retain child paths. Alternative-branch failures do
not leak into successful results.

For resources and repeated validation, compile once with an explicit offline
registry. Resource retrieval never uses the network:

```zap
import jsonschema

def main():
    auto schema = json.loads("{\"$ref\":\"types#positive\"}")
    auto types = json.loads("{\"$defs\":{\"n\":{\"$anchor\":\"positive\",\"type\":\"integer\",\"minimum\":1}}}")
    auto registry = {"https://example.com/types": types}
    auto compiled = jsonschema.compile(schema, registry, "https://example.com/root")
    assert jsonschema.is_valid_compiled(json.loads("42"), compiled)
    for error in jsonschema.validate_compiled(json.loads("0"), compiled):
        print(error.schema_path)
```

`compile(schema, registry, base_uri="", dialect="2020-12")` returns a reusable
`Validator`. Registry keys are retrieval URIs; `$id` establishes canonical IDs
and nested resource boundaries. `$schema` overrides the selected draft. Supported
selectors are `2020-12`, `2019-09`, `draft-07`, and their standard meta-schema URIs.
Mixed-draft external and embedded resources retain their own draft semantics.
`validate_compiled(instance, validator)` returns errors;
`is_valid_compiled(instance, validator)` returns a boolean. A compiled validator
contains evaluation scratch storage; use separate validators for concurrent calls.
Compilation checks supplied resources and resolves references even in inactive
branches. Duplicate identifiers, missing resources/anchors, malformed fragments,
and non-progressing evaluation cycles raise errors. Cycles are checked during
validation; recursive schemas over finite trees work. An evaluation error does
not prevent reusing the compiled validator for another instance.

Supported assertions:

- Boolean schemas; `type` including unions, `enum`, `const`.
- `minimum`, `maximum`, exclusive bounds, `multipleOf`.
- `minLength`/`maxLength` count Unicode codepoints, not bytes or graphemes.
- `properties`, `required`, `additionalProperties`, `propertyNames`,
  `dependentRequired`, `dependentSchemas`, property count bounds.
- `prefixItems`, `items`, `contains`, `minContains`/`maxContains`,
  `uniqueItems`, item count bounds.
- `allOf`, `anyOf`, `oneOf`, `not`, `if`/`then`/`else`.
- `$ref`, `$id`, `$anchor`, `$dynamicAnchor`/`$dynamicRef` (2020-12),
  `$recursiveAnchor`/`$recursiveRef` (2019-09); `$defs`/`definitions` indexing.
- Draft-07 and 2019-09 tuple `items`, `additionalItems`, and `dependencies`.
  Draft-07 ignores `$ref` siblings; modern drafts evaluate them. Keywords
  introduced in later drafts are ignored when an earlier draft is selected.

Regex (`pattern`/`patternProperties`) and unevaluated assertions currently raise
`SchemaError`. Unknown extension keywords are ignored. `format`, content keywords,
and annotations such as `default` are not assertions. The three fixed regexes
used by the official meta-schemas for `$id` and anchor syntax are checked by
private dedicated matchers; this does not enable general regex assertions.
Unsupported required vocabularies (including format-assertion and unevaluated)
raise errors. Full custom dialect/meta-schema registration is not supported.
Schema and evaluation nesting are each limited to 128 levels. Error schema paths
for external resources include the retrieval URI plus fragment, while paths for
the primary document remain JSON Pointers. References currently target indexed
subschemas in known schema locations (applicators, definitions, and `$defs`).

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
