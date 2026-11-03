# Official JSON Schema meta-schemas

Unmodified schema documents copied from
[python-jsonschema/jsonschema-specifications](https://github.com/python-jsonschema/jsonschema-specifications)
at commit `5f06612cb443edbe54fcbffd1a7f4b6ccb574ced`:
`jsonschema_specifications/schemas/draft202012`, `draft201909`, and `draft7`.
Original identifiers inside each document identify the specification resources.
See `LICENSE` for upstream's MIT license and JSON Schema BSD license notices.

`tools/generate-metaschemas.py` embeds these JSON files into the pure-Zap
`src/metaschemas.zap` module. After regeneration run `zap fmt src`.
Runtime schema checking uses the embedded resources and never reads files or
fetches from the network. Python is only an optional maintainer generation tool.
