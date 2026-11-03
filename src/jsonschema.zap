# Pure-Zap JSON Schema 2020-12 assertion foundation. See README for coverage.
import math

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

def _check(JsonValue schema, str p, int64 depth):
    if depth > 128:
        _bad(p, "schema nesting exceeds 128")
    if _kind(schema) == "boolean":
        return
    if _kind(schema) != "object":
        _bad(p, "schema must be an object or boolean")
    auto s = _obj(schema)
    for k in s:
        auto v = s[k]
        auto q = _ptr(p, k)
        if k in ["$ref", "$dynamicRef", "$recursiveRef", "$id", "$anchor", "$dynamicAnchor", "$recursiveAnchor", "$vocabulary", "pattern", "patternProperties", "unevaluatedProperties", "unevaluatedItems", "definitions", "dependencies", "additionalItems"]:
            _bad(q, "keyword is not supported by the foundation validator")
        elif k == "$schema":
            if _string(v) != "https://json-schema.org/draft/2020-12/schema":
                _bad(q, "only draft 2020-12 is supported")
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
            if k == "enum":
                if len(vs) == 0:
                    _bad(q, "enum must not be empty")
            for i in range(len(vs)):
                if k == "required":
                    if _kind(vs[i]) != "string":
                        _bad(q, "required entries must be strings")
                for j in range(i):
                    if _equal(vs[i], vs[j]):
                        _bad(q, "duplicate entry")
        elif k in ["properties", "$defs", "dependentSchemas"]:
            if _kind(v) != "object":
                _bad(q, "expected schema map")
            auto fields = _obj(v)
            for name in fields:
                _check(fields[name], _ptr(q, name), depth + 1)
        elif k == "dependentRequired":
            if _kind(v) != "object":
                _bad(q, "expected object")
            auto deps = _obj(v)
            for name in deps:
                # Reuse required-array validation, including uniqueness.
                auto required = {"required": deps[name]}
                _check(JsonValue.Object(required), _ptr(q, name), depth + 1)
        elif k in ["allOf", "anyOf", "oneOf", "prefixItems"]:
            if _kind(v) != "array":
                _bad(q, "expected schema array")
            auto schemas = _array(v)
            if len(schemas) == 0:
                _bad(q, "schema array must not be empty")
            for i in range(len(schemas)):
                _check(schemas[i], _ptr(q, str(i)), depth + 1)
        elif k in ["not", "if", "then", "else", "items", "contains", "additionalProperties", "propertyNames"]:
            _check(v, q, depth + 1)

def check_schema(JsonValue schema):
    _check(schema, "", 0)

def _err(list[ValidationError] errors, str ip, str sp, str k):
    errors.append(
        ValidationError(
            instance_path=ip,
            schema_path=_ptr(sp, k),
            keyword=k,
            message="failed " + k,
        ),
    )

def _matches(JsonValue v, JsonValue s, int64 depth) -> bool:
    list[ValidationError] errors = []
    _eval(v, s, "", "", errors, depth + 1)
    return len(errors) == 0

def _eval(
    JsonValue v,
    JsonValue schema,
    str ip,
    str sp,
    list[ValidationError] errors,
    int64 depth,
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
    auto s = _obj(schema)
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
                    )
                elif _matches(v, schemas[i], depth):
                    count = count + 1
            if k == "anyOf" and count == 0:
                _err(errors, ip, sp, k)
            if k == "oneOf" and count != 1:
                _err(errors, ip, sp, k)
    if "not" in s:
        if _matches(v, s["not"], depth):
            _err(errors, ip, sp, "not")
    if "if" in s:
        auto branch = "else"
        if _matches(v, s["if"], depth):
            branch = "then"
        if branch in s:
            _eval(v, s[branch], ip, _ptr(sp, branch), errors, depth + 1)
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
            if "prefixItems" in s:
                prefix = _array(s["prefixItems"])
            for i in range(len(items)):
                if i < len(prefix):
                    _eval(
                        items[i],
                        prefix[i],
                        _ptr(ip, str(i)),
                        _ptr(_ptr(sp, "prefixItems"), str(i)),
                        errors,
                        depth + 1,
                    )
                elif "items" in s:
                    _eval(
                        items[i],
                        s["items"],
                        _ptr(ip, str(i)),
                        _ptr(sp, "items"),
                        errors,
                        depth + 1,
                    )
            if "contains" in s:
                auto count = 0
                for item in items:
                    if _matches(item, s["contains"], depth):
                        count = count + 1
                auto minimum = 1.0
                if "minContains" in s:
                    minimum = _num(s["minContains"])
                if float64(count) < minimum:
                    _err(errors, ip, sp, "contains")
                if "maxContains" in s:
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
                    _eval(
                        JsonValue.Str(name),
                        s["propertyNames"],
                        ip,
                        _ptr(sp, "propertyNames"),
                        errors,
                        depth + 1,
                    )
                if name in props:
                    _eval(
                        fields[name],
                        props[name],
                        _ptr(ip, name),
                        _ptr(_ptr(sp, "properties"), name),
                        errors,
                        depth + 1,
                    )
                elif "additionalProperties" in s:
                    _eval(
                        fields[name],
                        s["additionalProperties"],
                        _ptr(ip, name),
                        _ptr(sp, "additionalProperties"),
                        errors,
                        depth + 1,
                    )
            if "dependentRequired" in s:
                auto deps = _obj(s["dependentRequired"])
                for name in deps:
                    if name in fields:
                        for dep in _array(deps[name]):
                            if not _string(dep) in fields:
                                _err(errors, ip, _ptr(sp, "dependentRequired"), name)
            if "dependentSchemas" in s:
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
                        )
        case _:
            auto ignored = 0

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

def validate(JsonValue instance, JsonValue schema) -> list[ValidationError]:
    check_schema(schema)
    list[ValidationError] errors = []
    _eval(instance, schema, "", "", errors, 0)
    return errors

def is_valid(JsonValue instance, JsonValue schema) -> bool:
    return len(validate(instance, schema)) == 0
