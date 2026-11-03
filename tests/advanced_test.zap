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
