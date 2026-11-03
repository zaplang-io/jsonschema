import jsonschema

def expect(str instance, str schema, str resources, str draft, bool wanted):
    dict[str, JsonValue] registry = {}
    match json.loads(resources):
        case JsonValue.Object(fields):
            registry = fields
        case _:
            raise "bad fixture"
    auto compiled = jsonschema.compile(
        json.loads(schema),
        registry,
        "https://example.com/root",
        draft,
    )
    auto actual = jsonschema.is_valid_compiled(json.loads(instance), compiled)
    if actual != wanted:
        raise "unexpected reference validation: " + instance + " against " + schema

def bad(str schema, str resources):
    dict[str, JsonValue] registry = {}
    match json.loads(resources):
        case JsonValue.Object(fields):
            registry = fields
        case _:
            raise "bad fixture"
    auto caught = False
    try:
        auto compiled = jsonschema.compile(
            json.loads(schema),
            registry,
            "https://example.com/root",
        )
        auto result = jsonschema.validate_compiled(json.loads("null"), compiled)
    except:
        caught = True
    assert caught

def main():
    expect(
        "1",
        "{\"$defs\": {\"n\": {\"type\": \"integer\"}}, \"$ref\": \"#/$defs/n\"}",
        "{}",
        "2020-12",
        True,
    )
    expect(
        "\"x\"",
        "{\"$defs\": {\"n\": {\"type\": \"integer\"}}, \"$ref\": \"#/$defs/n\"}",
        "{}",
        "2020-12",
        False,
    )
    expect(
        "1",
        "{\"$defs\": {\"a/b~c\": {\"const\": 1}}, \"$ref\": \"#/$defs/a~1b~0c\"}",
        "{}",
        "2020-12",
        True,
    )
    expect(
        "\"yes\"",
        "{\"$defs\": {\"😀\": {\"const\": \"yes\"}}, \"$ref\": \"#/$defs/%F0%9F%98%80\"}",
        "{}",
        "2020-12",
        True,
    )
    expect(
        "1",
        "{\"$defs\": {\"\": {\"const\": 1}}, \"$ref\": \"#/$defs/\"}",
        "{}",
        "2020-12",
        True,
    )
    expect(
        "1",
        "{\"$defs\": {\"n\": {\"$anchor\": \"num\", \"type\": \"integer\"}}, \"$ref\": \"#num\"}",
        "{}",
        "2020-12",
        True,
    )
    expect(
        "1",
        "{\"$ref\": \"other\"}",
        "{\"https://example.com/other\": {\"type\": \"integer\"}}",
        "2020-12",
        True,
    )
    expect(
        "\"x\"",
        "{\"$ref\": \"other\"}",
        "{\"https://example.com/other\": {\"type\": \"integer\"}}",
        "2020-12",
        False,
    )
    expect(
        "1",
        "{\"$ref\": \"./dir/../other\"}",
        "{\"https://example.com/other\": {\"const\": 1}}",
        "2020-12",
        True,
    )
    expect(
        "1",
        "{\"$ref\": \"//other.example/n\"}",
        "{\"https://other.example/n\": {\"const\": 1}}",
        "2020-12",
        True,
    )
    expect(
        "1",
        "{\"$ref\": \"?v=2\"}",
        "{\"https://example.com/root?v=2\": {\"const\": 1}}",
        "2020-12",
        True,
    )
    expect(
        "1",
        "{\"$ref\": \"other#n\"}",
        "{\"https://example.com/other\": {\"$defs\": {\"n\": {\"$anchor\": \"n\", \"const\": 1}}}}",
        "2020-12",
        True,
    )
    expect(
        "1",
        "{\"$id\": \"https://schema.example/base/root\", \"$defs\": {\"n\": {\"$id\": \"../nested\", \"type\": \"integer\"}}, \"$ref\": \"../nested\"}",
        "{}",
        "2020-12",
        True,
    )
    expect(
        "1",
        "{\"$id\": \"https://schema.example/root\", \"$defs\": {\"n\": {\"$id\": \"nested\", \"const\": 1}}, \"$ref\": \"#/$defs/n\"}",
        "{}",
        "2020-12",
        True,
    )
    expect(
        "1",
        "{\"$defs\": {\"n\": {\"$id\": \"nested\", \"properties\": {\"x\": {\"$ref\": \"#/$defs/s\"}}, \"$defs\": {\"s\": {\"type\": \"string\"}}}}, \"$ref\": \"nested\"}",
        "{}",
        "2020-12",
        True,
    )
    expect(
        "{\"x\": 1}",
        "{\"$defs\": {\"n\": {\"$id\": \"nested\", \"properties\": {\"x\": {\"$ref\": \"#/$defs/s\"}}, \"$defs\": {\"s\": {\"type\": \"string\"}}}}, \"$ref\": \"nested\"}",
        "{}",
        "2020-12",
        False,
    )
    expect(
        "{\"value\": 1, \"children\": [{\"value\": 2}]}",
        "{\"$id\": \"https://example.com/tree\", \"type\": \"object\", \"properties\": {\"value\": {\"type\": \"integer\"}, \"children\": {\"type\": \"array\", \"items\": {\"$ref\": \"#\"}}}, \"required\": [\"value\"]}",
        "{}",
        "2020-12",
        True,
    )
    expect(
        "{\"value\": 1, \"children\": [{\"value\": \"bad\"}]}",
        "{\"$id\": \"https://example.com/tree\", \"type\": \"object\", \"properties\": {\"value\": {\"type\": \"integer\"}, \"children\": {\"type\": \"array\", \"items\": {\"$ref\": \"#\"}}}, \"required\": [\"value\"]}",
        "{}",
        "2020-12",
        False,
    )
    expect(
        "{\"tag\": 1, \"children\": [{\"tag\": 2}]}",
        "{\"$id\": \"https://example.com/strict\", \"$dynamicAnchor\": \"node\", \"$ref\": \"tree\", \"required\": [\"tag\"]}",
        "{\"https://example.com/tree\": {\"$id\": \"https://example.com/tree\", \"$dynamicAnchor\": \"node\", \"type\": \"object\", \"properties\": {\"children\": {\"type\": \"array\", \"items\": {\"$dynamicRef\": \"#node\"}}}}}",
        "2020-12",
        True,
    )
    expect(
        "{\"tag\": 1, \"children\": [{}]}",
        "{\"$id\": \"https://example.com/strict\", \"$dynamicAnchor\": \"node\", \"$ref\": \"tree\", \"required\": [\"tag\"]}",
        "{\"https://example.com/tree\": {\"$id\": \"https://example.com/tree\", \"$dynamicAnchor\": \"node\", \"type\": \"object\", \"properties\": {\"children\": {\"type\": \"array\", \"items\": {\"$dynamicRef\": \"#node\"}}}}}",
        "2020-12",
        False,
    )
    expect(
        "1",
        "{\"$defs\": {\"n\": {\"$anchor\": \"n\", \"const\": 1}}, \"$dynamicRef\": \"#n\"}",
        "{}",
        "2020-12",
        True,
    )
    expect(
        "1",
        "{\"$defs\": {\"n\": {\"const\": 1}}, \"$dynamicRef\": \"#/$defs/n\"}",
        "{}",
        "2020-12",
        True,
    )
    expect(
        "1",
        "{\"definitions\": {\"n\": true}, \"$ref\": \"#/definitions/n\", \"type\": \"string\"}",
        "{}",
        "draft-07",
        True,
    )
    expect(
        "1",
        "{\"definitions\": {\"n\": true}, \"$ref\": \"#/definitions/n\", \"type\": \"string\"}",
        "{}",
        "2019-09",
        False,
    )
    expect(
        "1",
        "{\"definitions\": {\"n\": true}, \"$ref\": \"#/definitions/n\", \"type\": \"string\"}",
        "{}",
        "2020-12",
        False,
    )
    expect(
        "[1, \"x\"]",
        "{\"items\": [{\"type\": \"integer\"}], \"additionalItems\": {\"type\": \"string\"}}",
        "{}",
        "draft-07",
        True,
    )
    expect(
        "[1, 2]",
        "{\"items\": [true], \"additionalItems\": false}",
        "{}",
        "draft-07",
        False,
    )
    expect(
        "{\"a\": 1}",
        "{\"dependencies\": {\"a\": [\"b\"]}}",
        "{}",
        "draft-07",
        False,
    )
    expect(
        "{\"a\": 1}",
        "{\"dependencies\": {\"a\": {\"required\": [\"b\"]}}}",
        "{}",
        "draft-07",
        False,
    )
    expect(
        "[1, \"x\"]",
        "{\"items\": [{\"type\": \"integer\"}], \"additionalItems\": {\"type\": \"string\"}}",
        "{}",
        "2019-09",
        True,
    )
    expect(
        "[1, 2]",
        "{\"items\": [true], \"additionalItems\": false}",
        "{}",
        "2019-09",
        False,
    )
    expect("{\"a\": 1}", "{\"dependencies\": {\"a\": [\"b\"]}}", "{}", "2019-09", False)
    expect(
        "{\"a\": 1}",
        "{\"dependencies\": {\"a\": {\"required\": [\"b\"]}}}",
        "{}",
        "2019-09",
        False,
    )
    expect(
        "1",
        "{\"$defs\": {\"n\": false}, \"prefixItems\": false, \"dependentSchemas\": false}",
        "{}",
        "draft-07",
        True,
    )
    expect("[1]", "{\"prefixItems\": [false]}", "{}", "2019-09", True)
    expect("{\"a\": 1}", "{\"dependencies\": {\"a\": [\"b\"]}}", "{}", "2020-12", True)
    expect("[1, 2]", "{\"contains\": true, \"minContains\": 3}", "{}", "draft-07", True)
    expect("[1, 2]", "{\"contains\": true, \"minContains\": 3}", "{}", "2019-09", False)
    expect(
        "{\"tag\": 1, \"child\": {\"tag\": 2}}",
        "{\"$id\": \"https://example.com/strict\", \"$recursiveAnchor\": true, \"$ref\": \"tree\", \"required\": [\"tag\"]}",
        "{\"https://example.com/tree\": {\"$id\": \"https://example.com/tree\", \"$recursiveAnchor\": true, \"type\": \"object\", \"properties\": {\"child\": {\"$recursiveRef\": \"#\"}}}}",
        "2019-09",
        True,
    )
    expect(
        "{\"tag\": 1, \"child\": {}}",
        "{\"$id\": \"https://example.com/strict\", \"$recursiveAnchor\": true, \"$ref\": \"tree\", \"required\": [\"tag\"]}",
        "{\"https://example.com/tree\": {\"$id\": \"https://example.com/tree\", \"$recursiveAnchor\": true, \"type\": \"object\", \"properties\": {\"child\": {\"$recursiveRef\": \"#\"}}}}",
        "2019-09",
        False,
    )
    expect("1", "{\"$id\": \"#n\", \"const\": 1}", "{}", "draft-07", True)
    expect(
        "1",
        "{\"definitions\": {\"n\": {\"$id\": \"#n\", \"const\": 1}}, \"$ref\": \"#n\"}",
        "{}",
        "draft-07",
        True,
    )
    expect(
        "1",
        "{\"$ref\": \"old\"}",
        "{\"https://example.com/old\": {\"$schema\": \"http://json-schema.org/draft-07/schema#\", \"definitions\": {\"n\": true}, \"$ref\": \"#/definitions/n\", \"type\": \"string\"}}",
        "2020-12",
        True,
    )
    bad("{\"$ref\": \"absent\"}", "{}")
    bad("{\"$ref\": \"#unknown\"}", "{}")
    bad("{\"$ref\": \"#/$defs/n~2\"}", "{}")
    bad("{\"$ref\": \"#/%XX\"}", "{}")
    bad("{\"$ref\": \"#/%\"}", "{}")
    bad("{\"$ref\": \"#/const\", \"const\": 1}", "{}")
    bad("{\"$ref\": \"#\"}", "{}")
    bad("{\"not\": {\"$ref\": \"#\"}}", "{}")
    bad(
        "{\"$id\": \"https://example.com/x\", \"$defs\": {\"a\": {\"$id\": \"dup\"}, \"b\": {\"$id\": \"dup\"}}}",
        "{}",
    )
    bad(
        "{\"$defs\": {\"a\": {\"$anchor\": \"same\"}, \"b\": {\"$anchor\": \"same\"}}}",
        "{}",
    )
    bad("{\"$anchor\": \"bad space\"}", "{}")
    bad("{\"$id\": \"https://example.com/root#bad\"}", "{}")
    bad("{\"$vocabulary\": {\"https://example.com/vocab\": true}}", "{}")
    bad("{\"$vocabulary\": {\"https://example.com/vocab\": \"yes\"}}", "{}")
    bad("{\"$ref\": false}", "{}")
    bad("{\"title\": false}", "{}")
    bad("{\"deprecated\": 1}", "{}")
    bad("{\"$schema\": \"https://example.com/unknown\"}", "{}")
    bad("{\"$defs\": {\"n\": {\"required\": 1}}}", "{}")
    bad("{}", "{\"https://example.com/other\": {\"type\": 1}}")
    bad("{\"anyOf\": [true, {\"$ref\": \"missing\"}]}", "{}")
    bad("{}", "{\"https://example.com/root\": true}")
    expect(
        "[1]",
        "{\"$defs\": {\"old\": {\"$id\": \"old\", \"$schema\": \"http://json-schema.org/draft-07/schema#\", \"items\": [{\"type\": \"integer\"}], \"additionalItems\": false}}, \"$ref\": \"old\"}",
        "{}",
        "2020-12",
        True,
    )
    expect(
        "[\"x\"]",
        "{\"$defs\": {\"old\": {\"$id\": \"old\", \"$schema\": \"http://json-schema.org/draft-07/schema#\", \"items\": [{\"type\": \"integer\"}], \"additionalItems\": false}}, \"$ref\": \"old\"}",
        "{}",
        "2020-12",
        False,
    )
    expect(
        "1",
        "{\"$ref\": \"#/definitions/n\", \"definitions\": {\"n\": true}, \"type\": 42}",
        "{}",
        "draft-07",
        True,
    )
    dict[str, JsonValue] empty_registry = {}
    auto invalid_target = False
    try:
        auto ignored = jsonschema.compile(
            json.loads("{\"$ref\":\"#/definitions/n\",\"definitions\":{\"n\":null}}"),
            empty_registry,
            "",
            "draft-07",
        )
    except:
        invalid_target = True
    assert invalid_target
    auto reusable = jsonschema.compile(
        json.loads(
            "{\"type\": \"object\", \"properties\": {\"loop\": {\"$ref\": \"#/$defs/cycle\"}}, \"$defs\": {\"cycle\": {\"$ref\": \"#/$defs/cycle\"}}}",
        ),
        empty_registry,
    )
    auto cycled = False
    try:
        auto ignored = jsonschema.validate_compiled(
            json.loads("{\"loop\":null}"),
            reusable,
        )
    except:
        cycled = True
    assert cycled
    assert jsonschema.is_valid_compiled(json.loads("{}"), reusable)
    bad(
        "{\"$schema\": \"http://json-schema.org/draft-07/schema#\", \"$ref\": \"#/definitions/n\", \"definitions\": {\"n\": {\"title\": false}}}",
        "{}",
    )
    print("references: PASS (46 instance cases, cycle recovery)")
