import jsonschema

def object(JsonValue v) -> dict[str, JsonValue]:
    match v:
        case JsonValue.Object(fields):
            return fields
        case _:
            raise "invalid corpus object"
    return {}

def array(JsonValue v) -> list[JsonValue]:
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
    auto corpus = array(json.loads(fs.read_file(os.getenv("SCHEMA_CORPUS"))))
    auto draft = os.getenv("SCHEMA_DRAFT")
    auto passed = 0
    auto failed = 0
    for raw in corpus:
        auto group = object(raw)
        auto tests = array(group["tests"])
        auto ready = False
        auto failure = ""
        auto compiled = jsonschema.compile(JsonValue.Bool(True), {}, "", draft)
        try:
            compiled = jsonschema.compile(group["schema"], object(group["registry"]), "", draft)
            ready = True
        except Exception as e:
            failure = e
        for item in tests:
            auto test = object(item)
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
            else:
                failed = failed + 1
                print("FAIL " + text(group["name"]) + " / " + text(test["description"]) + ": " + failure)
    print(draft + ": executed=" + str(passed + failed) + " pass=" + str(passed) + " fail=" + str(failed) + " required_skip=0")
    if failed != 0:
        raise "Conformance failures"
