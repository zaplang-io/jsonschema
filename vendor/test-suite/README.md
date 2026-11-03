# Pinned JSON Schema Test Suite

Unmodified fixtures from [JSON-Schema-Test-Suite](https://github.com/json-schema-org/JSON-Schema-Test-Suite)
at commit `ed0ebd31d0a83fd79e99a32aa0c884b966ada057`.
The snapshot includes required and optional tests for draft7, draft2019-09, and
draft2020-12, plus upstream remote resources. See `LICENSE` (MIT).

`tools/generate-conformance.py` generates the offline corpora under
`tests/conformance/`, preserving schemas, data and expected results. It selects
remote resource closures and gives canonical IDs their original retrieval URI;
no fixture's schema or expectation is patched to accommodate the implementation.
Python is a maintainer generation tool, not a validator/runtime dependency.
The native runner is pure Zap (`tools/conformance.zap`).

Required cases are never skipped. Optional groups and their case counts are
listed individually in `tests/conformance/manifest.json`; skipped optional
behavior is not part of the package's conformance claim.
