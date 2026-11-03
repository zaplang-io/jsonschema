import jsonschema

def get_object(JsonValue v) -> dict[str, JsonValue]:
    match v:
        case JsonValue.Object(fields):
            return fields
        case _:
            raise "invalid corpus object"
    return {}

def get_array(JsonValue v) -> list[JsonValue]:
    match v:
        case JsonValue.Array(items):
            return items
        case _:
            raise "invalid corpus array"
    return []

def text(JsonValue v) -> str:
    match v:
        case JsonValue.Str(s):
            return s
        case _:
            return ""

def main():
    auto corpus = get_array(json.loads(fs.read_file(os.getenv("SCHEMA_CORPUS"))))
    auto draft = os.getenv("SCHEMA_DRAFT")
    auto manifest = get_object(json.loads(fs.read_file(os.getenv("SCHEMA_MANIFEST"))))
    auto summary = get_object(manifest[os.getenv("SCHEMA_SUITE_KEY")])
    auto skipped = 0
    for raw_skip in get_array(summary["optional_skips"]):
        auto skip = get_object(raw_skip)
        auto count = 0
        match skip["cases"]:
            case JsonValue.Int(n):
                count = n
            case _:
                raise "invalid optional case count"
        skipped = skipped + count
        print(
            "OPTIONAL SKIP " + text(skip["path"]) + " cases=" + str(count) + ": " + text(skip["reason"]),
        )
    auto passed = 0
    auto failed = 0
    auto optional_passed = 0
    auto optional_failed = 0
    for raw in corpus:
        auto group = get_object(raw)
        auto tests = get_array(group["tests"])
        auto optional = "optional" in group
        auto ready = False
        auto failure = ""
        auto compiled = jsonschema.compile(JsonValue.Bool(True), {}, "", draft)
        try:
            compiled = jsonschema.compile(
                group["schema"],
                get_object(group["registry"]),
                "",
                draft,
            )
            ready = True
        except Exception as e:
            failure = e
        for item in tests:
            auto test = get_object(item)
            auto ok = False
            if ready:
                try:
                    auto valid = jsonschema.is_valid_compiled(test["data"], compiled)
                    auto expected = False
                    match test["valid"]:
                        case JsonValue.Bool(b):
                            expected = b
                        case _:
                            raise "invalid expected result"
                    ok = valid == expected
                    if not ok:
                        failure = "got " + str(valid) + ", wanted " + str(expected)
                except Exception as e:
                    failure = e
            if ok:
                passed = passed + 1
                if optional:
                    optional_passed = optional_passed + 1
            else:
                failed = failed + 1
                if optional:
                    optional_failed = optional_failed + 1
                print(
                    "FAIL " + text(group["name"]) + " / " + text(test["description"]) + ": " + failure,
                )
    print(
        draft + ": executed=" + str(passed + failed) + " pass=" + str(passed) + " fail=" + str(failed) + " required_skip=0",
    )
    print(
        "required: pass=" + str(passed - optional_passed) + " fail=" + str(failed - optional_failed) + " skip=0; optional: pass=" + str(optional_passed) + " fail=" + str(optional_failed) + " skip=" + str(skipped),
    )
    if failed != 0:
        raise "Conformance failures"
