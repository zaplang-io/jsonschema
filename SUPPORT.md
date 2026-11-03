# Support and verification

The supported dialects are JSON Schema draft-07, 2019-09, and 2020-12.
Verification uses JSON-Schema-Test-Suite commit
`ed0ebd31d0a83fd79e99a32aa0c884b966ada057`, with unmodified fixtures and
expectations. Passing this pinned suite is evidence of tested behavior, not a
claim of support for every optional extension or every possible regex/number.

| Draft | Required pass | Required fail/skip | Optional pass | Optional skipped |
| --- | ---: | ---: | ---: | ---: |
| draft-07 | 925 | 0 / 0 | 17 | 916 |
| 2019-09 | 1,257 | 0 / 0 | 67 | 986 |
| 2020-12 | 1,298 | 0 / 0 | 31 | 1,026 |

Selected optional coverage includes non-BMP regex, cross-draft references,
unknown-keyword handling, references into arbitrary keyword containers,
omitted `$schema`, 2020-12 dynamic-reference resource boundaries, and 2019-09
legacy-dependency compatibility. The exact executed groups and individual
optional skips, case counts, and reasons are in
[`tests/conformance/manifest.json`](tests/conformance/manifest.json).
No failing required group is skipped or marked as expected failure.

Run `sh tools/run-conformance.sh` with a codegen-enabled Zap and GNU `timeout`.
The runner builds once and reads offline corpora; it reports pass/fail counts
for required and optional cases separately and lists each skipped optional file.
`tools/generate-conformance.py` reproduces the corpora from vendored upstream
files. It does not change schemas, test inputs, or expected results. CI also
runs regressions, 600 compiled recursive validations with forced GC, and a
separately installed consumer that exercises regex and unevaluated properties.

Regex uses unanchored search, as JSON Schema requires. The pure-Zap parser and
matcher operate on Unicode codepoints and support literals, `.`, `^`/`$`,
character classes and ranges, negated/empty classes, grouping and `(?:...)`,
alternation, `*`/`+`/`?`/bounded quantifiers, lazy quantifier syntax, word
boundaries, digit/word/whitespace classes and their complements, control escapes,
hex and Unicode escapes (including surrogate pairs), and selected Unicode
properties (`L`/`Letter`, `N`/`Number`, `Nd`/`Decimal_Number`, `M`/`Mark`,
`Z`/`Separator`, with `\p`/`\P`). Unicode category lookup uses fixed literals
through Zap's built-in PCRE2 support; schema patterns themselves use the bounded
Zap matcher. `.` excludes LF, CR, U+2028 and U+2029. `$` requires the actual end
of the string. Capturing groups provide grouping semantics only.

Backreferences, lookaround, named captures, inline flags, and unlisted Unicode
property forms raise `SchemaError`. Full optional ECMA-262 regex conformance is
not claimed. Format assertions (including regex-format validation), content
assertions, arbitrary-precision arithmetic, permissive legacy IDs/anchors, and
2020-12 legacy `dependencies` compatibility are also outside the support claim.
`format` and content keywords remain annotations; no content is implicitly
parsed, decoded, or executed. Unsupported required vocabularies fail explicitly.

The JSON DOM stores integers in i64 and non-integers in binary64. Integer
comparisons and integer remainder constraints are exact within i64. Larger
integer literals become floats and may already have lost information before
validation. Floating `multipleOf` uses a relative tolerance of two machine
epsilons in its quotient; exact decimal divisibility is not guaranteed. The
optional bignum and float-overflow groups are explicitly skipped. Use this
package with values inside the documented numeric domain; it is not an
arbitrary-precision decimal validator.

Schema/evaluation/equality nesting is bounded at 128; meta-schema evaluation
also counts its own calls, so some deeply nested schemas reach that limit
before 128 source levels. Custom meta-schema declaration chains are limited
to 16. Regex source is limited to 4,096 codepoints, group nesting to 64,
quantifier bounds to 100,000, and matching to 250,000 position visits and
512 call levels. Limit violations raise errors. Compiled validators reuse
scratch storage and regex programs; use a separate validator per concurrent
caller. Evaluation errors do not poison a validator's next call.

The package is reviewable and CI-verified; creating a Git tag or publishing a
release is a separate action. No release is produced by the test scripts.
