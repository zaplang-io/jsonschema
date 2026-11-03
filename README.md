# jsonschema

Pure-Zap JSON Schema validation over the standard library `JsonValue` DOM.
Implements [zaplang-io/zap#316](https://github.com/zaplang-io/zap/issues/316).
Supports **2020-12, 2019-09, and draft-07**. All 3,480 required cases in the
pinned official suite pass, plus 115 selected optional cases. See [SUPPORT.md](SUPPORT.md)
for tested coverage, optional skips, regex syntax, numeric limits, and resource bounds.

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
- `pattern`; `minLength`/`maxLength` count Unicode codepoints, not bytes or graphemes.
- `properties`, `patternProperties`, `required`, `additionalProperties`, `propertyNames`,
  `dependentRequired`, `dependentSchemas`, property count bounds.
- `prefixItems`, `items`, `contains`, `minContains`/`maxContains`,
  `uniqueItems`, item count bounds.
- `allOf`, `anyOf`, `oneOf`, `not`, `if`/`then`/`else`.
- `unevaluatedProperties`/`unevaluatedItems` with annotations from successful
  references, alternatives, conditionals, and applicable child rules.
- `$ref`, `$id`, `$anchor`, `$dynamicAnchor`/`$dynamicRef` (2020-12),
  `$recursiveAnchor`/`$recursiveRef` (2019-09); `$defs`/`definitions` indexing.
- Draft-07 and 2019-09 tuple `items`, `additionalItems`, and `dependencies`.
  Draft-07 ignores `$ref` siblings; modern drafts evaluate them. Keywords
  introduced in later drafts are ignored when an earlier draft is selected.

Unknown extension keywords are ignored. JSON Pointer references can identify
schemas inside arbitrary keyword containers; the target is checked and indexed
on demand. Custom meta-schemas can be registered by URI in the offline registry
when they declare a supported base draft and supported vocabularies. Vocabulary
omission controls which assertions/applicators are active; unknown optional
vocabularies are ignored, while unsupported required vocabularies raise errors.
`format` is annotation-only. Content keywords never decode or execute content.
Format assertions and custom vocabulary implementations are not provided.

Numbers follow Zap's JSON DOM: i64 integers and binary64 floats. Equality and
bounds retain exact i64 comparisons, including comparisons against floats.
Integer `multipleOf` uses exact remainder; floating `multipleOf` allows a relative
rounding tolerance of two binary64 machine epsilons, rejects nonzero quotients
rounded to zero, and treats quotient overflow as failure. Decimal arithmetic and
JSON integers beyond i64 remain subject to binary64 precision limits. See
[SUPPORT.md](SUPPORT.md) before using decimal or arbitrary-precision constraints.
Object equality ignores key order; array equality preserves order.

Run `sh tools/run-tests.sh` with a codegen-enabled `zap` on PATH (or set `ZAP`).
`--check` runs frontend checks only. `sh tools/check-package.sh` checks packaging
and runs a separate path-dependency consumer. CI runs both with a pinned published
Zap image. `sh tools/run-conformance.sh` compiles the pure-Zap conformance runner,
executes all required and selected optional groups, and lists optional skips with
counts and reasons. No Python runtime or third-party native extension is required.

Build sequence (each is an agent-sized M issue):

1. [Validator foundation](https://github.com/zaplang-io/jsonschema/issues/1).
2. [Resources, references, drafts](https://github.com/zaplang-io/jsonschema/issues/2).
3. [Conformance and release](https://github.com/zaplang-io/jsonschema/issues/3).

Specification references: [2020-12 core](https://json-schema.org/draft/2020-12/json-schema-core)
and [validation](https://json-schema.org/draft/2020-12/json-schema-validation).
