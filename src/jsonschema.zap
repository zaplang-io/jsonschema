# Pure-Zap JSON Schema 2020-12 assertion foundation. See README for coverage.
import math
import jsonschema.metaschemas
import jsonschema.pattern

struct ValidationError:
    str instance_path
    str schema_path
    str keyword
    str message

def _ptr(str base, str token) -> str:
    return base + "/" + token.replace("~", "~0").replace("/", "~1")

def _obj(JsonValue v) -> dict[str, JsonValue]:
    match v:
        case JsonValue.Object(fields):
            return fields
        case _:
            return {}

def _array(JsonValue v) -> list[JsonValue]:
    match v:
        case JsonValue.Array(items):
            return items
        case _:
            return []

def _string(JsonValue v) -> str:
    match v:
        case JsonValue.Str(s):
            return s
        case _:
            return ""

def _number(JsonValue v) -> bool:
    match v:
        case JsonValue.Int(i):
            return True
        case JsonValue.Float(f):
            return True
        case _:
            return False

def _num(JsonValue v) -> float64:
    match v:
        case JsonValue.Int(i):
            return float64(i)
        case JsonValue.Float(f):
            return f
        case _:
            return 0.0

def _kind(JsonValue v) -> str:
    match v:
        case JsonValue.Null:
            return "null"
        case JsonValue.Bool(b):
            return "boolean"
        case JsonValue.Int(i):
            return "integer"
        case JsonValue.Float(f):
            return "number"
        case JsonValue.Str(s):
            return "string"
        case JsonValue.Array(xs):
            return "array"
        case JsonValue.Object(fields):
            return "object"

def _is_type(JsonValue v, str t) -> bool:
    if t == "number":
        return _number(v)
    if t == "integer":
        if _number(v):
            return math.floor(_num(v)) == _num(v)
    return _kind(v) == t

# Deep equality: objects are unordered; booleans are distinct from numbers.
def _equal(JsonValue a, JsonValue b) -> bool:
    match a:
        case JsonValue.Int(i):
            match b:
                case JsonValue.Int(j):
                    return i == j
                case _:
                    if _number(b):
                        # Avoid rounding an i64 into an equal-but-different f64.
                        auto f = _num(b)
                        if f >= -9223372036854775808.0:
                            if f < 9223372036854775808.0:
                                if math.floor(f) == f:
                                    return i == int64(f)
                    return False
        case JsonValue.Float(f):
            match b:
                case JsonValue.Int(i):
                    return _equal(b, a)
                case JsonValue.Float(g):
                    return f == g
                case _:
                    return False
        case JsonValue.Null:
            return _kind(b) == "null"
        case JsonValue.Bool(x):
            match b:
                case JsonValue.Bool(y):
                    return x == y
                case _:
                    return False
        case JsonValue.Str(x):
            return _kind(b) == "string" and x == _string(b)
        case JsonValue.Array(xs):
            if _kind(b) != "array":
                return False
            auto ys = _array(b)
            if len(xs) != len(ys):
                return False
            for i in range(len(xs)):
                if not _equal(xs[i], ys[i]):
                    return False
            return True
        case JsonValue.Object(xs):
            if _kind(b) != "object":
                return False
            auto ys = _obj(b)
            if len(xs) != len(ys):
                return False
            for k in xs:
                if not k in ys:
                    return False
                if not _equal(xs[k], ys[k]):
                    return False
            return True

def _bad(str p, str msg):
    raise "SchemaError at " + p + ": " + msg

def _type_name(str t) -> bool:
    return t in ["null", "boolean", "integer", "number", "string", "array", "object"]

def _check(JsonValue schema, str p, int64 depth, str draft):
    if depth > 128:
        _bad(p, "schema nesting exceeds 128")
    if _kind(schema) == "boolean":
        return
    if _kind(schema) != "object":
        _bad(p, "schema must be an object or boolean")
    auto s = _obj(schema)
    draft = _dialect(s, draft)
    if draft == "draft-07" and "$ref" in s:
        if _kind(s["$ref"]) != "string":
            _bad(p, "$ref must be a string")
        return
    for k in s:
        if not _enabled(k, draft):
            continue
        auto v = s[k]
        auto q = _ptr(p, k)
        if k == "pattern":
            if _kind(v) != "string":
                _bad(q, "pattern must be a string")
            auto checked = pattern.compile(_string(v))
        elif k in ["$ref", "$id", "$anchor", "$dynamicRef", "$dynamicAnchor", "$recursiveRef"]:
            if _kind(v) != "string":
                _bad(q, "expected string")
        elif k == "$recursiveAnchor":
            if draft == "2019-09":
                if _kind(v) != "boolean":
                    _bad(q, "expected boolean")
        elif k == "$vocabulary":
            _vocabulary(v, draft, q)
        elif k == "$schema":
            auto selected = _draft(_string(v))
        elif k == "type":
            if _kind(v) == "string":
                if not _type_name(_string(v)):
                    _bad(q, "unknown type")
            elif _kind(v) == "array":
                auto types = _array(v)
                if len(types) == 0:
                    _bad(q, "type union must not be empty")
                for i in range(len(types)):
                    if not _type_name(_string(types[i])):
                        _bad(q, "invalid type union member")
                    for j in range(i):
                        if _equal(types[i], types[j]):
                            _bad(q, "duplicate type")
            else:
                _bad(q, "type must be a string or array")
        elif k in ["minimum", "maximum", "exclusiveMinimum", "exclusiveMaximum", "multipleOf"]:
            if not _number(v):
                _bad(q, "expected number")
            if k == "multipleOf":
                if _num(v) <= 0.0:
                    _bad(q, "multipleOf must be positive")
        elif k in ["minLength", "maxLength", "minItems", "maxItems", "minProperties", "maxProperties", "minContains", "maxContains"]:
            if not _is_type(v, "integer"):
                _bad(q, "expected nonnegative integer")
            if _num(v) < 0.0:
                _bad(q, "expected nonnegative integer")
        elif k == "uniqueItems":
            if _kind(v) != "boolean":
                _bad(q, "expected boolean")
        elif k in ["required", "enum"]:
            if _kind(v) != "array":
                _bad(q, "expected array")
            auto vs = _array(v)
            for i in range(len(vs)):
                if k == "required":
                    if _kind(vs[i]) != "string":
                        _bad(q, "required entries must be strings")
                if k == "required":
                    for j in range(i):
                        if _equal(vs[i], vs[j]):
                            _bad(q, "duplicate entry")
        elif k in ["properties", "patternProperties", "$defs", "definitions", "dependentSchemas"]:
            if _kind(v) != "object":
                _bad(q, "expected schema map")
            auto fields = _obj(v)
            for name in fields:
                if k == "patternProperties":
                    auto checked = pattern.compile(name)
                _check(fields[name], _ptr(q, name), depth + 1, draft)
        elif k == "dependentRequired":
            if _kind(v) != "object":
                _bad(q, "expected object")
            auto deps = _obj(v)
            for name in deps:
                # Reuse required-array validation, including uniqueness.
                auto required = {"required": deps[name]}
                _check(JsonValue.Object(required), _ptr(q, name), depth + 1, draft)
        elif k in ["allOf", "anyOf", "oneOf", "prefixItems"]:
            if _kind(v) != "array":
                _bad(q, "expected schema array")
            auto schemas = _array(v)
            if len(schemas) == 0:
                _bad(q, "schema array must not be empty")
            for i in range(len(schemas)):
                _check(schemas[i], _ptr(q, str(i)), depth + 1, draft)
        elif k == "dependencies":
            if draft != "2020-12":
                if _kind(v) != "object":
                    _bad(q, "expected dependency map")
                auto deps = _obj(v)
                for name in deps:
                    if _kind(deps[name]) == "array":
                        auto required = {"required": deps[name]}
                        _check(
                            JsonValue.Object(required),
                            _ptr(q, name),
                            depth + 1,
                            draft,
                        )
                    else:
                        _check(deps[name], _ptr(q, name), depth + 1, draft)
        elif k == "items":
            if draft != "2020-12" and _kind(v) == "array":
                auto schemas = _array(v)
                if len(schemas) == 0:
                    _bad(q, "tuple schema must not be empty")
                for i in range(len(schemas)):
                    _check(schemas[i], _ptr(q, str(i)), depth + 1, draft)
            else:
                _check(v, q, depth + 1, draft)
        elif k in ["not", "if", "then", "else", "contains", "additionalProperties", "propertyNames", "additionalItems", "contentSchema", "unevaluatedItems", "unevaluatedProperties"]:
            _check(v, q, depth + 1, draft)

def _err(list[ValidationError] errors, str ip, str sp, str k):
    errors.append(
        ValidationError(
            instance_path=ip,
            schema_path=_ptr(sp, k),
            keyword=k,
            message="failed " + k,
        ),
    )

def _matches(
    JsonValue v,
    JsonValue s,
    str ip,
    str sp,
    int64 depth,
    Validator state,
) -> bool:
    list[ValidationError] errors = []
    _eval(v, s, ip, sp, errors, depth + 1, state)
    return len(errors) == 0

def _eval_body(
    JsonValue v,
    JsonValue schema,
    str ip,
    str sp,
    list[ValidationError] errors,
    int64 depth,
    Validator state,
):
    if depth > 128:
        raise "EvaluationError: nesting exceeds 128"
    match schema:
        case JsonValue.Bool(b):
            if not b:
                errors.append(
                    ValidationError(
                        instance_path=ip,
                        schema_path=sp,
                        keyword="false",
                        message="false schema",
                    ),
                )
            return
        case _:
            auto ignored = 0
    auto node = state.nodes[sp]
    auto draft = node.draft
    auto s = _obj(schema)
    for refkey in ["$ref", "$dynamicRef", "$recursiveRef"]:
        auto enabled = refkey == "$ref"
        if refkey == "$dynamicRef" and draft == "2020-12":
            enabled = True
        if refkey == "$recursiveRef" and draft == "2019-09":
            enabled = True
        if enabled and refkey in s:
            auto target = _resolve(state, node.base, _string(s[refkey]))
            if refkey != "$ref":
                target = _dynamic(state, target, refkey, _string(s[refkey]))
            _eval(v, state.nodes[target].schema, ip, target, errors, depth + 1, state)
            if draft == "draft-07":
                return
    if "pattern" in s:
        if _kind(v) == "string":
            if not _search(state, _string(s["pattern"]), _string(v)):
                _err(errors, ip, sp, "pattern")
    if "type" in s:
        auto ok = False
        if _kind(s["type"]) == "string":
            ok = _is_type(v, _string(s["type"]))
        else:
            for t in _array(s["type"]):
                if _is_type(v, _string(t)):
                    ok = True
        if not ok:
            _err(errors, ip, sp, "type")
    if "const" in s:
        if not _equal(v, s["const"]):
            _err(errors, ip, sp, "const")
    if "enum" in s:
        auto found = False
        for item in _array(s["enum"]):
            if _equal(v, item):
                found = True
        if not found:
            _err(errors, ip, sp, "enum")
    for k in ["allOf", "anyOf", "oneOf"]:
        if k in s:
            auto schemas = _array(s[k])
            auto count = 0
            for i in range(len(schemas)):
                if k == "allOf":
                    _eval(
                        v,
                        schemas[i],
                        ip,
                        _ptr(_ptr(sp, k), str(i)),
                        errors,
                        depth + 1,
                        state,
                    )
                elif _matches(v, schemas[i], ip, _ptr(_ptr(sp, k), str(i)), depth, state):
                    count = count + 1
            if k == "anyOf" and count == 0:
                _err(errors, ip, sp, k)
            if k == "oneOf" and count != 1:
                _err(errors, ip, sp, k)
    if "not" in s:
        auto saved_marks = state.mark_count
        if _matches(v, s["not"], ip, _ptr(sp, "not"), depth, state):
            _err(errors, ip, sp, "not")
        state.mark_count = saved_marks
    if "if" in s:
        auto branch = "else"
        if _matches(v, s["if"], ip, _ptr(sp, "if"), depth, state):
            branch = "then"
        if branch in s:
            _eval(v, s[branch], ip, _ptr(sp, branch), errors, depth + 1, state)
    if _number(v):
        auto n = _num(v)
        for k in ["minimum", "maximum", "exclusiveMinimum", "exclusiveMaximum", "multipleOf"]:
            if k in s:
                auto b = _num(s[k])
                auto fail = False
                if k == "minimum":
                    fail = n < b
                elif k == "maximum":
                    fail = n > b
                elif k == "exclusiveMinimum":
                    fail = n <= b
                elif k == "exclusiveMaximum":
                    fail = n >= b
                else:
                    auto quotient = n / b
                    # Floating decimal arithmetic is approximate; documented policy.
                    fail = math.fabs(quotient - math.round(quotient)) > 0.000000001
                if fail:
                    _err(errors, ip, sp, k)
    match v:
        case JsonValue.Str(text):
            auto length = 0
            for c in text:
                length = length + 1
            _size(length, s, "minLength", "maxLength", ip, sp, errors)
        case JsonValue.Array(items):
            _size(len(items), s, "minItems", "maxItems", ip, sp, errors)
            if "uniqueItems" in s:
                if _equal(s["uniqueItems"], JsonValue.Bool(True)):
                    for i in range(len(items)):
                        for j in range(i):
                            if _equal(items[i], items[j]):
                                _err(errors, ip, sp, "uniqueItems")
            list[JsonValue] prefix = []
            auto prefix_key = "prefixItems"
            auto rest_key = "items"
            if draft != "2020-12":
                prefix_key = "items"
                if "items" in s:
                    if _kind(s["items"]) == "array":
                        rest_key = "additionalItems"
            if prefix_key in s:
                if _kind(s[prefix_key]) == "array":
                    prefix = _array(s[prefix_key])
            if draft != "2020-12":
                if rest_key == "additionalItems":
                    if not "items" in s:
                        rest_key = ""
            for i in range(len(items)):
                if i < len(prefix):
                    _mark(state, ip, str(i))
                    _eval(
                        items[i],
                        prefix[i],
                        _ptr(ip, str(i)),
                        _ptr(_ptr(sp, prefix_key), str(i)),
                        errors,
                        depth + 1,
                        state,
                    )
                elif rest_key in s:
                    _mark(state, ip, str(i))
                    _eval(
                        items[i],
                        s[rest_key],
                        _ptr(ip, str(i)),
                        _ptr(sp, rest_key),
                        errors,
                        depth + 1,
                        state,
                    )
            if "contains" in s:
                auto count = 0
                for i in range(len(items)):
                    if _matches(items[i], s["contains"], _ptr(ip, str(i)), _ptr(sp, "contains"), depth, state):
                        count = count + 1
                        if draft == "2020-12":
                            _mark(state, ip, str(i))
                auto minimum = 1.0
                if draft != "draft-07" and "minContains" in s:
                    minimum = _num(s["minContains"])
                if float64(count) < minimum:
                    _err(errors, ip, sp, "contains")
                if draft != "draft-07" and "maxContains" in s:
                    if float64(count) > _num(s["maxContains"]):
                        _err(errors, ip, sp, "maxContains")
        case JsonValue.Object(fields):
            _size(len(fields), s, "minProperties", "maxProperties", ip, sp, errors)
            if "required" in s:
                for name in _array(s["required"]):
                    if not _string(name) in fields:
                        _err(errors, ip, sp, "required")
            dict[str, JsonValue] props = {}
            if "properties" in s:
                props = _obj(s["properties"])
            for name in fields:
                if "propertyNames" in s:
                    auto saved_marks = state.mark_count
                    _eval(
                        JsonValue.Str(name),
                        s["propertyNames"],
                        ip,
                        _ptr(sp, "propertyNames"),
                        errors,
                        depth + 1,
                        state,
                    )
                    state.mark_count = saved_marks
                auto matched = False
                if name in props:
                    matched = True
                    _mark(state, ip, name)
                    _eval(
                        fields[name],
                        props[name],
                        _ptr(ip, name),
                        _ptr(_ptr(sp, "properties"), name),
                        errors,
                        depth + 1,
                        state,
                    )
                if "patternProperties" in s:
                    auto patterns = _obj(s["patternProperties"])
                    for expression in patterns:
                        if _search(state, expression, name):
                            matched = True
                            _mark(state, ip, name)
                            _eval(
                                fields[name],
                                patterns[expression],
                                _ptr(ip, name),
                                _ptr(_ptr(sp, "patternProperties"), expression),
                                errors,
                                depth + 1,
                                state,
                            )
                if not matched and "additionalProperties" in s:
                    _mark(state, ip, name)
                    _eval(
                        fields[name],
                        s["additionalProperties"],
                        _ptr(ip, name),
                        _ptr(sp, "additionalProperties"),
                        errors,
                        depth + 1,
                        state,
                    )
            if draft != "draft-07" and "dependentRequired" in s:
                auto deps = _obj(s["dependentRequired"])
                for name in deps:
                    if name in fields:
                        for dep in _array(deps[name]):
                            if not _string(dep) in fields:
                                errors.append(
                                    ValidationError(
                                        instance_path=ip,
                                        schema_path=_ptr(
                                            _ptr(sp, "dependentRequired"),
                                            name,
                                        ),
                                        keyword="dependentRequired",
                                        message="missing dependent property " + _string(dep),
                                    ),
                                )
            if draft != "draft-07" and "dependentSchemas" in s:
                auto deps = _obj(s["dependentSchemas"])
                for name in deps:
                    if name in fields:
                        _eval(
                            v,
                            deps[name],
                            ip,
                            _ptr(_ptr(sp, "dependentSchemas"), name),
                            errors,
                            depth + 1,
                            state,
                        )
            if draft != "2020-12" and "dependencies" in s:
                auto deps = _obj(s["dependencies"])
                for name in deps:
                    if name in fields:
                        if _kind(deps[name]) == "array":
                            for dep in _array(deps[name]):
                                if not _string(dep) in fields:
                                    _err(errors, ip, sp, "dependencies")
                        else:
                            _eval(
                                v,
                                deps[name],
                                ip,
                                _ptr(_ptr(sp, "dependencies"), name),
                                errors,
                                depth + 1,
                                state,
                            )
        case _:
            auto ignored = 0
    if draft != "draft-07":
        if _kind(v) == "object" and "unevaluatedProperties" in s:
            auto fields = _obj(v)
            for name in fields:
                if not _evaluated(state, ip, name):
                    _eval(
                        fields[name],
                        s["unevaluatedProperties"],
                        _ptr(ip, name),
                        _ptr(sp, "unevaluatedProperties"),
                        errors,
                        depth + 1,
                        state,
                    )
                    _mark(state, ip, name)
        if _kind(v) == "array" and "unevaluatedItems" in s:
            auto items = _array(v)
            for i in range(len(items)):
                if not _evaluated(state, ip, str(i)):
                    _eval(
                        items[i],
                        s["unevaluatedItems"],
                        _ptr(ip, str(i)),
                        _ptr(sp, "unevaluatedItems"),
                        errors,
                        depth + 1,
                        state,
                    )
                    _mark(state, ip, str(i))

def _size(
    int64 n,
    dict[str, JsonValue] s,
    str low,
    str high,
    str ip,
    str sp,
    list[ValidationError] errors,
):
    if low in s:
        if float64(n) < _num(s[low]):
            _err(errors, ip, sp, low)
    if high in s:
        if float64(n) > _num(s[high]):
            _err(errors, ip, sp, high)
# Resource index and evaluation context. Resource and anchor aliases point to
# physical schema locations, preserving base URI and dialect at each subschema.
struct SchemaNode:
    JsonValue schema
    str base
    str draft
    str resource

struct Validator:
    dict[str, SchemaNode] nodes
    dict[str, str] aliases
    list[str] active
    list[str] resource_stack
    bool meta
    int64 active_count
    int64 scope_count
    list[EvaluationMark] marks
    int64 mark_count
    list[int64] mark_starts
    dict[str, pattern.Regex] regexes


def _length(str s) -> int64:
    auto n = 0
    for c in s:
        n = n + 1
    return n

def _draft(str name) -> str:
    if name in ["2020-12", "https://json-schema.org/draft/2020-12/schema", "https://json-schema.org/draft/2020-12/schema#"]:
        return "2020-12"
    if name in ["2019-09", "https://json-schema.org/draft/2019-09/schema", "https://json-schema.org/draft/2019-09/schema#"]:
        return "2019-09"
    if name in ["draft-07", "http://json-schema.org/draft-07/schema#", "http://json-schema.org/draft-07/schema", "https://json-schema.org/draft-07/schema#", "https://json-schema.org/draft-07/schema"]:
        return "draft-07"
    _bad("$schema", "unsupported dialect " + name)
    return ""

def _dialect(dict[str, JsonValue] s, str inherited) -> str:
    if "$schema" in s:
        return _draft(_string(s["$schema"]))
    return inherited

def _meta_uri(str draft) -> str:
    if draft == "draft-07":
        return "http://json-schema.org/draft-07/schema"
    return "https://json-schema.org/draft/" + draft + "/schema"

def _vocabulary(JsonValue v, str draft, str p):
    if _kind(v) != "object":
        _bad(p, "vocabulary must be an object")
    auto vocab = _obj(v)
    for uri in vocab:
        if _kind(vocab[uri]) != "boolean":
            _bad(p, "vocabulary requirement must be boolean")
        if _equal(vocab[uri], JsonValue.Bool(True)):
            # Unevaluated and format-assertion are not implemented yet.
            auto prefix = "https://json-schema.org/draft/" + draft + "/vocab/"
            auto known = False
            for suffix in ["core", "applicator", "validation", "meta-data", "format", "format-annotation", "content", "unevaluated"]:
                if uri == prefix + suffix:
                    known = True
            if not known:
                _bad(p, "unsupported required vocabulary " + uri)

def _enabled(str k, str draft) -> bool:
    if draft == "draft-07":
        if k in ["$anchor", "$dynamicAnchor", "$dynamicRef", "$recursiveRef", "$recursiveAnchor", "$vocabulary", "$defs", "unevaluatedProperties", "unevaluatedItems", "prefixItems", "dependentRequired", "dependentSchemas", "minContains", "maxContains"]:
            return False
    if draft == "2019-09":
        if k in ["$dynamicAnchor", "$dynamicRef", "prefixItems"]:
            return False
    if draft == "2020-12":
        if k in ["dependencies", "additionalItems"]:
            return False
    return True

struct _Uri:
    str scheme
    str authority
    str path
    str query
    bool has_query
    bool has_authority
    str fragment

def _uri(str text) -> _Uri:
    auto fragment = ""
    auto hash = text.find("#")
    if hash >= 0:
        fragment = text[hash + 1:]
        text = text[:hash]
    auto query = ""
    auto question = text.find("?")
    auto has_query = question >= 0
    if has_query:
        query = text[question + 1:]
        text = text[:question]
    auto scheme = ""
    auto colon = text.find(":")
    auto slash = text.find("/")
    if colon >= 0:
        if slash < 0 or colon < slash:
            scheme = text[:colon].lower()
            text = text[colon + 1:]
    auto authority = ""
    auto has_authority = text.startswith("//")
    if has_authority:
        text = text[2:]
        auto end = text.find("/")
        if end < 0:
            authority = text
            text = ""
        else:
            authority = text[:end]
            text = text[end:]
    return _Uri(
        scheme=scheme,
        authority=authority,
        path=text,
        query=query,
        has_query=has_query,
        has_authority=has_authority,
        fragment=fragment,
    )

def _remove_dots(str input) -> str:
    auto output = ""
    while input != "":
        if input.startswith("../"):
            input = input[3:]
        elif input.startswith("./"):
            input = input[2:]
        elif input.startswith("/./"):
            input = input[2:]
        elif input == "/.":
            input = "/"
        elif input.startswith("/../") or input == "/..":
            if input == "/..":
                input = "/"
            else:
                input = input[3:]
            auto last = -1
            auto i = 0
            for c in output:
                if ord(c) == 47:
                    last = i
                i = i + 1
            if last < 0:
                output = ""
            else:
                output = output[:last]
        elif input == "." or input == "..":
            input = ""
        else:
            auto start = 0
            if input.startswith("/"):
                start = 1
            auto next = input[start:].find("/")
            if next < 0:
                output = output + input
                input = ""
            else:
                auto end = start + next
                output = output + input[:end]
                input = input[end:]
    return output

def _join_uri(str base, str reference) -> str:
    auto b = _uri(base)
    auto r = _uri(reference)
    if r.scheme == "":
        r.scheme = b.scheme
        if not r.has_authority:
            r.authority = b.authority
            r.has_authority = b.has_authority
            if r.path == "":
                r.path = b.path
                if not r.has_query:
                    r.query = b.query
                    r.has_query = b.has_query
            elif not r.path.startswith("/"):
                auto last = -1
                auto i = 0
                for c in b.path:
                    if ord(c) == 47:
                        last = i
                    i = i + 1
                auto prefix = ""
                if last >= 0:
                    prefix = b.path[:last + 1]
                elif b.has_authority:
                    prefix = "/"
                r.path = prefix + r.path
    auto result = ""
    if r.scheme != "":
        result = r.scheme + ":"
    if r.has_authority:
        result = result + "//" + r.authority
    result = result + _remove_dots(r.path)
    if r.has_query:
        result = result + "?" + r.query
    if "#" in reference:
        result = result + "#" + r.fragment
    return result

def _document(str uri) -> str:
    auto at = uri.find("#")
    if at >= 0:
        return uri[:at]
    return uri

def _hex(char c) -> int64:
    auto alphabet = "0123456789abcdef"
    return alphabet.find(str(c).lower())

def _fragment(str text) -> str:
    list[int64] data = []
    auto i = 0
    auto raw = bytes(text)
    while i < len(raw):
        if raw[i] == 37:
            if i + 2 >= len(raw):
                _bad(text, "truncated percent escape")
            auto hi = _hex(chr(raw[i + 1]))
            auto lo = _hex(chr(raw[i + 2]))
            if hi < 0 or lo < 0:
                _bad(text, "invalid percent escape")
            data.append(hi * 16 + lo)
            i = i + 3
        else:
            data.append(raw[i])
            i = i + 1
    return str(bytes(data))

def _anchor(str value, str draft) -> bool:
    if value == "":
        return False
    auto first = True
    for c in value:
        auto letter = ord(c) >= 65 and ord(c) <= 90 or ord(c) >= 97 and ord(c) <= 122
        if first:
            if not letter:
                if draft != "2020-12" or ord(c) != 95:
                    return False
        else:
            if not letter:
                if not (ord(c) >= 48 and ord(c) <= 57):
                    if not str(c) in ["-", ".", "_"]:
                        if draft == "2020-12" or ord(c) != 58:
                            return False
        first = False
    return True

def _meta_pattern(str value, str pattern) -> bool:
    if pattern == "^[^#]*#?$":
        auto at = value.find("#")
        return at < 0 or at == _length(value) - 1
    if pattern == "^[A-Za-z_][-A-Za-z0-9._]*$":
        return _anchor(value, "2020-12")
    if pattern == "^[A-Za-z][-A-Za-z0-9.:_]*$":
        return _anchor(value, "2019-09")
    raise "InternalError: unexpected official meta-schema pattern"
    return False

def _alias(Validator state, str uri, str location):
    if uri in state.aliases:
        if state.aliases[uri] != location:
            _bad(uri, "duplicate resource or anchor identifier")
    state.aliases[uri] = location

def _index(
    JsonValue schema,
    str location,
    str base,
    str draft,
    str resource,
    Validator state,
    int64 depth,
):
    if depth > 128:
        _bad(location, "schema nesting exceeds 128")
    auto s = _obj(schema)
    draft = _dialect(s, draft)
    if "$id" in s:
        auto id = _join_uri(base, _string(s["$id"]))
        auto fragment = _uri(id).fragment
        if fragment != "":
            if draft != "draft-07":
                _bad(location, "$id must not contain a nonempty fragment")
            _alias(state, id, location)
        else:
            base = _document(id)
            resource = location
            _alias(state, base, location)
    state.nodes[location] = SchemaNode(
        schema=schema,
        base=base,
        draft=draft,
        resource=resource,
    )
    for k in ["$anchor", "$dynamicAnchor"]:
        if _enabled(k, draft) and k in s:
            auto name = _string(s[k])
            if not _anchor(name, draft):
                _bad(location, "invalid anchor " + name)
            _alias(state, base + "#" + name, location)
    for k in s:
        if _enabled(k, draft):
            auto v = s[k]
            auto q = _ptr(location, k)
            if k in ["properties", "patternProperties", "definitions", "$defs", "dependentSchemas"]:
                auto fields = _obj(v)
                for name in fields:
                    _index(
                        fields[name],
                        _ptr(q, name),
                        base,
                        draft,
                        resource,
                        state,
                        depth + 1,
                    )
            elif k in ["allOf", "anyOf", "oneOf", "prefixItems"] or k == "items" and _kind(v) == "array":
                auto schemas = _array(v)
                for i in range(len(schemas)):
                    _index(
                        schemas[i],
                        _ptr(q, str(i)),
                        base,
                        draft,
                        resource,
                        state,
                        depth + 1,
                    )
            elif k == "dependencies":
                auto deps = _obj(v)
                for name in deps:
                    if _kind(deps[name]) != "array":
                        _index(
                            deps[name],
                            _ptr(q, name),
                            base,
                            draft,
                            resource,
                            state,
                            depth + 1,
                        )
            elif k in ["items", "additionalItems", "additionalProperties", "propertyNames", "contains", "not", "if", "then", "else", "contentSchema", "unevaluatedProperties", "unevaluatedItems"]:
                _index(v, q, base, draft, resource, state, depth + 1)

def _resolve(Validator state, str base, str ref) -> str:
    auto uri = _join_uri(base, ref)
    auto document = _document(uri)
    auto fragment = _fragment(_uri(uri).fragment)
    if fragment != "" and not fragment.startswith("/"):
        auto name = document + "#" + fragment
        if name in state.aliases:
            return state.aliases[name]
        _bad(uri, "unresolved anchor")
    if not document in state.aliases:
        _bad(uri, "resource is not present in the offline registry")
    auto location = state.aliases[document]
    if fragment != "":
        # Decode and re-encode each pointer token, rejecting malformed ~ escapes.
        for token in fragment[1:].split("/"):
            auto i = 0
            auto decoded = ""
            while i < _length(token):
                if ord(token[i]) == 126:
                    if i + 1 >= _length(token):
                        _bad(uri, "invalid JSON Pointer escape")
                    auto next = token[i + 1]
                    if ord(next) == 48:
                        decoded = decoded + "~"
                    elif ord(next) == 49:
                        decoded = decoded + "/"
                    else:
                        _bad(uri, "invalid JSON Pointer escape")
                    i = i + 2
                else:
                    decoded = decoded + str(token[i])
                    i = i + 1
            location = _ptr(location, decoded)
    if not location in state.nodes:
        _bad(uri, "reference does not identify an indexed subschema")
    return location

def _dynamic(Validator state, str target, str key, str ref) -> str:
    auto node = state.nodes[target]
    auto s = _obj(node.schema)
    if key == "$dynamicRef":
        auto name = _fragment(_uri(ref).fragment)
        if name == "" or name.startswith("/"):
            return target
        if not "$dynamicAnchor" in s:
            return target
        if _string(s["$dynamicAnchor"]) != name:
            return target
        for resource_index in range(state.scope_count):
            auto resource = state.resource_stack[resource_index]
            auto candidate = state.nodes[resource].base + "#" + name
            if candidate in state.aliases:
                auto p = state.aliases[candidate]
                auto fields = _obj(state.nodes[p].schema)
                if "$dynamicAnchor" in fields:
                    return p
    else:
        if "$recursiveAnchor" in s:
            if _equal(s["$recursiveAnchor"], JsonValue.Bool(True)):
                for resource_index in range(state.scope_count):
                    auto resource = state.resource_stack[resource_index]
                    auto fields = _obj(state.nodes[resource].schema)
                    if "$recursiveAnchor" in fields:
                        if _equal(fields["$recursiveAnchor"], JsonValue.Bool(True)):
                            return resource
                    else:
                        break
    return target

def _eval(
    JsonValue v,
    JsonValue schema,
    str ip,
    str sp,
    list[ValidationError] errors,
    int64 depth,
    Validator state,
):
    if depth > 128:
        raise "EvaluationError: nesting exceeds 128"
    # Embedded schema resources may declare a different dialect. Meta-schema
    # recursion dispatches at full meta-schema roots, not vocabulary fragments.
    if state.meta:
        auto source_draft = state.nodes[sp].draft
        if sp == _meta_uri(source_draft) + "#":
            auto declared = _dialect(_obj(v), source_draft)
            if declared != source_draft:
                sp = _meta_uri(declared) + "#"
                schema = state.nodes[sp].schema
    auto frame = json.dumps(JsonValue.Array([JsonValue.Str(sp), JsonValue.Str(ip)]))
    for i in range(state.active_count):
        if frame == state.active[i]:
            _bad(sp, "non-progressing reference evaluation cycle at " + ip)
    if state.active_count == len(state.active):
        state.active.append(frame)
    else:
        state.active[state.active_count] = frame
    state.active_count = state.active_count + 1
    if state.scope_count == len(state.resource_stack):
        state.resource_stack.append(state.nodes[sp].resource)
    else:
        state.resource_stack[state.scope_count] = state.nodes[sp].resource
    state.scope_count = state.scope_count + 1
    auto start = state.mark_count
    if state.active_count > len(state.mark_starts):
        state.mark_starts.append(start)
    else:
        state.mark_starts[state.active_count - 1] = start
    auto error_count = len(errors)
    _eval_body(v, schema, ip, sp, errors, depth, state)
    if len(errors) != error_count:
        state.mark_count = start
    state.scope_count = state.scope_count - 1
    state.active_count = state.active_count - 1

def _state() -> Validator:
    return Validator(
        nodes={},
        aliases={},
        active=[],
        resource_stack=[],
        meta=False,
        active_count=0,
        scope_count=0,
        marks=[],
        mark_count=0,
        mark_starts=[],
        regexes={},
    )

def _load_metas(Validator state):
    auto schemas = metaschemas.resources()
    for uri in schemas:
        _alias(state, uri, uri + "#")
        _index(
            schemas[uri],
            uri + "#",
            uri,
            _draft(_string(_obj(schemas[uri])["$schema"])),
            uri + "#",
            state,
            0,
        )

def compile(
    JsonValue schema,
    dict[str, JsonValue] registry,
    str base_uri = "",
    str dialect = "2020-12",
) -> Validator:
    auto state = _state()
    auto draft = _dialect(_obj(schema), _draft(dialect))
    _check(schema, "", 0, draft)
    _alias(state, _document(base_uri), "")
    _index(schema, "", _document(base_uri), draft, "", state, 0)
    for uri in registry:
        if _uri(uri).fragment != "":
            _bad(uri, "registry keys must not contain fragments")
        _check(registry[uri], uri, 0, _draft(dialect))
        _alias(state, _document(uri), uri + "#")
        _index(registry[uri], uri + "#", uri, _draft(dialect), uri + "#", state, 0)
    # Resolve references after every resource has been indexed, including inactive
    # branches, so broken registries cannot depend on the instance being tested.
    list[str] referenced = []
    for location in state.nodes:
        auto node = state.nodes[location]
        auto fields = _obj(node.schema)
        for k in ["$ref", "$dynamicRef", "$recursiveRef"]:
            if _enabled(k, node.draft) and k in fields:
                auto target = _resolve(state, node.base, _string(fields[k]))
                _check(state.nodes[target].schema, target, 0, state.nodes[target].draft)
                if not target in referenced:
                    referenced.append(target)
    # The official meta-schemas run through the same evaluator in a separate
    # context, with only their three fixed anchor/$id patterns enabled.
    auto meta_state = _state()
    _load_metas(meta_state)
    meta_state.meta = True
    list[ValidationError] failures = []
    auto meta_location = _meta_uri(draft) + "#"
    _eval(
        schema,
        meta_state.nodes[meta_location].schema,
        "",
        meta_location,
        failures,
        0,
        meta_state,
    )
    if len(failures) != 0:
        _bad(failures[0].instance_path, "official meta-schema: " + failures[0].message)
    for target in referenced:
        auto node = state.nodes[target]
        list[ValidationError] target_failures = []
        auto loc = _meta_uri(node.draft) + "#"
        _eval(
            node.schema,
            meta_state.nodes[loc].schema,
            target,
            loc,
            target_failures,
            0,
            meta_state,
        )
        if len(target_failures) != 0:
            _bad(target, "reference target fails official meta-schema")
    for uri in registry:
        auto rd = _dialect(_obj(registry[uri]), _draft(dialect))
        list[ValidationError] resource_failures = []
        auto loc = _meta_uri(rd) + "#"
        _eval(
            registry[uri],
            meta_state.nodes[loc].schema,
            uri,
            loc,
            resource_failures,
            0,
            meta_state,
        )
        if len(resource_failures) != 0:
            _bad(uri, "resource fails official meta-schema")
    return state

def check_schema(JsonValue schema, str dialect = "2020-12"):
    dict[str, JsonValue] registry = {}
    auto checked = compile(schema, registry, "", dialect)

def validate(JsonValue instance, JsonValue schema) -> list[ValidationError]:
    dict[str, JsonValue] registry = {}
    auto compiled = compile(schema, registry)
    return validate_compiled(instance, compiled)

def is_valid(JsonValue instance, JsonValue schema) -> bool:
    return len(validate(instance, schema)) == 0


def validate_compiled(JsonValue instance, Validator state) -> list[ValidationError]:
    state.active_count = 0
    state.scope_count = 0
    state.mark_count = 0
    list[ValidationError] errors = []
    _eval(instance, state.nodes[""].schema, "", "", errors, 0, state)
    return errors

def is_valid_compiled(JsonValue instance, Validator state) -> bool:
    return len(validate_compiled(instance, state)) == 0


struct EvaluationMark:
    str instance_path
    str token

def _mark(Validator state, str ip, str token):
    auto mark = EvaluationMark(instance_path=ip, token=token)
    if state.mark_count == len(state.marks):
        state.marks.append(mark)
    else:
        state.marks[state.mark_count] = mark
    state.mark_count = state.mark_count + 1

def _evaluated(Validator state, str ip, str token) -> bool:
    auto start = state.mark_starts[state.active_count - 1]
    for i in range(start, state.mark_count):
        if state.marks[i].instance_path == ip and state.marks[i].token == token:
            return True
    return False

def _search(Validator state, str expression, str text) -> bool:
    if not expression in state.regexes:
        state.regexes[expression] = pattern.compile(expression)
    return pattern.search(state.regexes[expression], text)
