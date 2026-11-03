import jsonschema

def expect(str instance, str schema, bool wanted):
    auto actual = jsonschema.is_valid(json.loads(instance), json.loads(schema))
    if actual != wanted:
        raise "unexpected validation: " + instance + " against " + schema

def bad(str schema):
    auto caught = False
    try:
        jsonschema.check_schema(json.loads(schema))
    except:
        caught = True
    assert caught

def main():
    expect("null", "true", True)
    expect("null", "false", False)
    expect("true", "{\"type\":\"number\"}", False)
    expect("1.0", "{\"type\":\"integer\"}", True)
    expect("1.2", "{\"type\":\"integer\"}", False)
    expect("null", "{\"type\":[\"null\",\"string\"]}", True)
    expect("{}", "{\"type\":[\"null\",\"string\"]}", False)
    expect("1.0", "{\"const\":1}", True)
    expect("true", "{\"const\":1}", False)
    expect("{\"b\":[1.0],\"a\":true}", "{\"const\":{\"a\":true,\"b\":[1]}}", True)
    expect("[1,2]", "{\"const\":[2,1]}", False)
    expect("1", "{\"enum\":[null,1.0]}", True)
    expect("2", "{\"enum\":[null,1]}", False)
    expect("9007199254740993", "{\"const\":9007199254740992.0}", False)
    expect("4", "{\"minimum\":4,\"maximum\":4}", True)
    expect("4", "{\"exclusiveMinimum\":4}", False)
    expect("4", "{\"exclusiveMaximum\":4}", False)
    expect("0.3", "{\"multipleOf\":0.1}", True)
    expect("0.31", "{\"multipleOf\":0.1}", False)
    expect("\"😀é\"", "{\"minLength\":2,\"maxLength\":2}", True)
    expect("\"😀é\"", "{\"maxLength\":1}", False)
    expect("42", "{\"minLength\":100,\"required\":[\"a\"]}", True)
    expect("{}", "{\"required\":[\"a\"]}", False)
    expect("{\"a\":null}", "{\"required\":[\"a\"]}", True)
    expect(
        "{\"a\":1}",
        "{\"properties\":{\"a\":{\"type\":\"integer\"}},\"additionalProperties\":false}",
        True,
    )
    expect(
        "{\"a\":1,\"b\":2}",
        "{\"properties\":{\"a\":true},\"additionalProperties\":false}",
        False,
    )
    expect("{\"a\":1}", "{\"propertyNames\":{\"minLength\":2}}", False)
    expect("{\"a\":1}", "{\"dependentRequired\":{\"a\":[\"b\"]}}", False)
    expect("{\"b\":1}", "{\"dependentRequired\":{\"a\":[\"b\"]}}", True)
    expect("{\"a\":1}", "{\"dependentSchemas\":{\"a\":{\"required\":[\"b\"]}}}", False)
    expect("{}", "{\"minProperties\":1}", False)
    expect(
        "[1,\"a\"]",
        "{\"prefixItems\":[{\"type\":\"integer\"}],\"items\":{\"type\":\"string\"}}",
        True,
    )
    expect("[1,2]", "{\"prefixItems\":[true],\"items\":false}", False)
    expect(
        "[1,2]",
        "{\"items\":{\"type\":\"integer\"},\"minItems\":2,\"maxItems\":2}",
        True,
    )
    expect("[]", "{\"minItems\":1}", False)
    expect("[1,1.0]", "{\"uniqueItems\":true}", False)
    expect("[1,true]", "{\"uniqueItems\":true}", True)
    expect(
        "[1,\"a\",2]",
        "{\"contains\":{\"type\":\"integer\"},\"minContains\":2,\"maxContains\":2}",
        True,
    )
    expect("[]", "{\"contains\":true,\"minContains\":0}", True)
    expect("[]", "{\"contains\":true}", False)
    expect("[]", "{\"minContains\":10}", True)
    expect("1", "{\"allOf\":[true,{\"type\":\"string\"}]}", False)
    expect("1", "{\"anyOf\":[{\"type\":\"string\"},{\"type\":\"integer\"}]}", True)
    expect("1", "{\"oneOf\":[true,true]}", False)
    expect("1", "{\"oneOf\":[false,true]}", True)
    expect("1", "{\"not\":{\"type\":\"string\"}}", True)
    expect(
        "1",
        "{\"if\":{\"type\":\"integer\"},\"then\":{\"minimum\":2},\"else\":true}",
        False,
    )
    expect(
        "\"a\"",
        "{\"if\":{\"type\":\"integer\"},\"then\":false,\"else\":true}",
        True,
    )
    expect(
        "1",
        "{\"then\":false,\"default\":0,\"format\":\"email\",\"custom\":42}",
        True,
    )
    bad("null")
    bad("{\"type\":\"bogus\"}")
    bad("{\"type\":[\"string\",\"string\"]}")
    bad("{\"minimum\":true}")
    bad("{\"multipleOf\":0}")
    bad("{\"minItems\":1.5}")
    bad("{\"required\":[1]}")
    bad("{\"required\":[\"a\",\"a\"]}")
    expect("1", "{\"enum\":[1,1.0]}", True)
    expect("1", "{\"enum\":[]}", False)
    bad("{\"items\":[]}")
    bad("{\"allOf\":[]}")
    bad("{\"if\":false,\"then\":{\"type\":42}}")
    bad("{\"$ref\":\"#missing\"}")
    bad("{\"pattern\":\"[\"}")
    bad("{\"$schema\":\"https://example.com/unsupported-dialect\"}")
    auto errors = jsonschema.validate(
        json.loads("{\"a/b~c\":[\"bad\"]}"),
        json.loads("{\"properties\":{\"a/b~c\":{\"items\":{\"type\":\"integer\"}}}}"),
    )
    assert len(errors) == 1
    assert errors[0].instance_path == "/a~1b~0c/0"
    assert errors[0].schema_path == "/properties/a~1b~0c/items/type"
    assert errors[0].keyword == "type"
    print("assertions: PASS")
