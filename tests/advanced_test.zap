import jsonschema

def expect(str instance, str schema, bool wanted):
    assert jsonschema.is_valid(json.loads(instance), json.loads(schema)) == wanted

def bad(str schema):
    auto caught = False
    try:
        jsonschema.check_schema(json.loads(schema))
    except Exception:
        caught = True
    assert caught

def main():
    expect("\"éabé\"", "{\"pattern\":\"^(ab|é)+$\"}", True)
    expect("\"😀\"", "{\"pattern\":\"^.$\"}", True)
    expect("\"xabcx\"", "{\"pattern\":\"abc\"}", True)
    expect("\"abc\\n\"", "{\"pattern\":\"^abc$\"}", False)
    expect("\"aaab\"", "{\"pattern\":\"^a{2,3}b$\"}", True)
    expect("\"ab\"", "{\"pattern\":\"^a{2,3}b$\"}", False)
    expect("\"é\"", "{\"pattern\":\"^[^a-z]+$\"}", True)
    expect("\"é\"", "{\"pattern\":\"^[a-z]+$\"}", False)
    expect("\"abc123\"", "{\"pattern\":\"^\\\\w+\\\\d{3}$\"}", True)
    expect(
        "{\"a\":1}",
        "{\"anyOf\":[{\"properties\":{\"a\":true}},{\"properties\":{\"z\":true},\"required\":[\"z\"]}],\"unevaluatedProperties\":false}",
        True,
    )
    expect(
        "{\"a\":1,\"z\":2}",
        "{\"oneOf\":[{\"properties\":{\"a\":true}},{\"properties\":{\"z\":true}}],\"unevaluatedProperties\":false}",
        False,
    )
    expect(
        "{\"a\":1}",
        "{\"allOf\":[{\"properties\":{\"a\":true}},{\"unevaluatedProperties\":false}]}",
        False,
    )
    expect(
        "{\"a\":1}",
        "{\"not\":{\"properties\":{\"a\":false}},\"unevaluatedProperties\":false}",
        False,
    )
    expect(
        "[1,\"x\"]",
        "{\"contains\":{\"type\":\"integer\"},\"unevaluatedItems\":{\"type\":\"string\"}}",
        True,
    )
    expect(
        "[1,2]",
        "{\"contains\":{\"type\":\"integer\"},\"unevaluatedItems\":false}",
        True,
    )
    expect(
        "{\"abc\":1}",
        "{\"patternProperties\":{\"^a\":{\"type\":\"integer\"}},\"additionalProperties\":false}",
        True,
    )
    expect("{\"abc\":1}", "{\"patternProperties\":{\"^a\":true,\"c$\":false}}", False)
    expect("0.0000000001", "{\"multipleOf\":1}", False)
    expect("-15", "{\"multipleOf\":3}", True)
    expect("9007199254740993", "{\"maximum\":9007199254740992}", False)
    expect("9007199254740993", "{\"exclusiveMinimum\":9007199254740992}", True)
    expect("9007199254740993", "{\"multipleOf\":2}", False)
    bad("{\"pattern\":\"[z-a]\"}")
    bad("{\"pattern\":\"(abc\"}")
    bad("{\"pattern\":\"a{3,2}\"}")
    bad("{\"pattern\":\"(?=abc)\"}")
    bad("{\"pattern\":\"(a)\\\\1\"}")
    bad("{\"patternProperties\":{\"[\":true}}")
    auto no_validation = json.loads(
        "{\"$schema\": \"https://json-schema.org/draft/2020-12/schema\", \"$id\": \"https://example.com/no-validation\", \"$vocabulary\": {\"https://json-schema.org/draft/2020-12/vocab/core\": true, \"https://json-schema.org/draft/2020-12/vocab/applicator\": true, \"https://other.example/vocab/validation\": false}}",
    )
    auto custom = jsonschema.compile(
        json.loads(
            "{\"$schema\": \"https://example.com/no-validation\", \"properties\": {\"x\": {\"pattern\": \"[\", \"minimum\": \"ignored\"}}}",
        ),
        {"https://example.com/no-validation": no_validation},
    )
    assert jsonschema.is_valid_compiled(json.loads("{\"x\":1}"), custom)
    auto long_pattern = ""
    for i in range(4097):
        long_pattern = long_pattern + "a"
    auto source_limited = False
    try:
        jsonschema.check_schema(
            JsonValue.Object({"pattern": JsonValue.Str(long_pattern)}),
        )
    except Exception as e:
        source_limited = e.startswith("SchemaError:")
    assert source_limited
    auto nested = JsonValue.Bool(True)
    for i in range(130):
        nested = JsonValue.Object({"not": nested})
    auto schema_limited = False
    try:
        jsonschema.check_schema(nested)
    except Exception as e:
        schema_limited = e.startswith("SchemaError")
    assert schema_limited
    auto expensive = ""
    for i in range(600):
        expensive = expensive + "a"
    auto match_limited = False
    try:
        auto ignored = jsonschema.is_valid(
            JsonValue.Str(expensive),
            json.loads("{\"pattern\":\"(a|aa)+b\"}"),
        )
    except Exception as e:
        match_limited = e.startswith("EvaluationError: regex resource limit")
    assert match_limited
    auto schema = json.loads(
        "{\"type\":\"object\",\"properties\":{\"name\":{\"pattern\":\"^(ab|é)+$\"},\"child\":{\"$ref\":\"#\"}},\"required\":[\"name\"],\"unevaluatedProperties\":false}",
    )
    dict[str, JsonValue] registry = {}
    auto compiled = jsonschema.compile(schema, registry)
    for i in range(300):
        auto good = json.loads("{\"name\":\"éabé\",\"child\":{\"name\":\"ab\"}}")
        auto wrong = json.loads("{\"name\":\"éabé\",\"child\":{\"name\":\"wrong\"}}")
        assert jsonschema.is_valid_compiled(good, compiled)
        assert not jsonschema.is_valid_compiled(wrong, compiled)
        if i % 20 == 0:
            gc.collect()
    print(
        "advanced: PASS (annotations, regex, 600 recursive validations with forced GC)",
    )
