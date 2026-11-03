# Bounded ECMA-262-style search over Unicode codepoints. Captures are structural;
# backreferences and lookaround are rejected rather than given another meaning.
struct Node:
    int64 kind
    int64 left
    int64 right
    int64 minimum
    int64 maximum
    list[int64] ranges
    bool negate
    str property

struct Regex:
    list[int64] source
    int64 offset
    list[Node] nodes
    int64 root

struct MatchState:
    Regex regex
    list[int64] text
    dict[str, list[int64]] memo
    int64 steps

def _fail():
    raise "SchemaError: invalid or unsupported regular expression"

def _points(str text) -> list[int64]:
    list[int64] result = []
    for c in text:
        result.append(ord(c))
    return result

def _peek(Regex r) -> int64:
    if r.offset >= len(r.source):
        return -1
    return r.source[r.offset]

def _take(Regex r) -> int64:
    auto value = _peek(r)
    if value < 0:
        _fail()
    r.offset = r.offset + 1
    return value

def _node(
    Regex r,
    int64 kind,
    int64 left,
    int64 right,
    int64 minimum,
    int64 maximum,
    list[int64] ranges,
    bool negate,
    str property,
) -> int64:
    r.nodes.append(
        Node(
            kind=kind,
            left=left,
            right=right,
            minimum=minimum,
            maximum=maximum,
            ranges=ranges,
            negate=negate,
            property=property,
        ),
    )
    return len(r.nodes) - 1

def _simple(Regex r, int64 kind) -> int64:
    return _node(r, kind, 0, 0, 0, 0, [], False, "")

def _literal(Regex r, int64 cp) -> int64:
    return _node(r, 1, 0, 0, 0, 0, [cp, cp], False, "")

def _digit(int64 c) -> bool:
    return c >= 48 and c <= 57

def _hex(Regex r, int64 count) -> int64:
    auto value = 0
    for i in range(count):
        auto cp = _take(r)
        auto digit = "0123456789abcdef".find(str(chr(cp)).lower())
        if digit < 0:
            _fail()
        value = value * 16 + digit
    return value

def _escape(Regex r, bool in_class) -> int64:
    auto c = _take(r)
    if c in [100, 68, 119, 87, 115, 83]:
        auto negate = c in [68, 87, 83]
        auto letter = str(chr(c)).lower()
        list[int64] ranges = []
        if letter == "d":
            ranges = [48, 57]
        elif letter == "w":
            ranges = [48, 57, 65, 90, 95, 95, 97, 122]
        else:
            ranges = [
                9,
                13,
                32,
                32,
                160,
                160,
                5760,
                5760,
                8192,
                8202,
                8232,
                8233,
                8239,
                8239,
                8287,
                8287,
                12288,
                12288,
                65279,
                65279,
            ]
        return _node(r, 1, 0, 0, 0, 0, ranges, negate, "")
    if c == 112 or c == 80:
        if _take(r) != 123:
            _fail()
        auto name = ""
        while _peek(r) != 125:
            name = name + str(chr(_take(r)))
        auto close = _take(r)
        if not name in ["L", "Letter", "N", "Number", "Nd", "Decimal_Number", "M", "Mark", "Z", "Separator"]:
            _fail()
        return _node(r, 1, 0, 0, 0, 0, [], c == 80, name)
    if c == 117:
        auto cp = 0
        if _peek(r) == 123:
            auto open = _take(r)
            auto digits = 0
            while _peek(r) != 125:
                cp = cp * 16 + _hex(r, 1)
                digits = digits + 1
                if digits > 6:
                    _fail()
            auto close = _take(r)
        else:
            cp = _hex(r, 4)
            if cp >= 55296 and cp <= 56319:
                if _take(r) != 92:
                    _fail()
                if _take(r) != 117:
                    _fail()
                auto low = _hex(r, 4)
                if low < 56320 or low > 57343:
                    _fail()
                cp = 65536 + (cp - 55296) * 1024 + low - 56320
        if cp > 1114111 or cp >= 55296 and cp <= 57343:
            _fail()
        return _literal(r, cp)
    if c == 120:
        return _literal(r, _hex(r, 2))
    if c == 99:
        auto letter = _take(r)
        if letter >= 97 and letter <= 122:
            letter = letter - 32
        if letter < 65 or letter > 90:
            _fail()
        return _literal(r, letter - 64)
    if c == 98:
        if in_class:
            return _literal(r, 8)
        return _simple(r, 8)
    if c == 66:
        if in_class:
            _fail()
        return _simple(r, 9)
    if c == 116:
        return _literal(r, 9)
    if c == 110:
        return _literal(r, 10)
    if c == 118:
        return _literal(r, 11)
    if c == 102:
        return _literal(r, 12)
    if c == 114:
        return _literal(r, 13)
    if c == 48:
        if _digit(_peek(r)):
            _fail()
        return _literal(r, 0)
    if _digit(c):
        _fail()
    return _literal(r, c)

def _atom(Regex r, int64 depth) -> int64:
    if depth > 64:
        _fail()
    auto c = _take(r)
    if c == 40:
        if _peek(r) == 63:
            auto question = _take(r)
            if _take(r) != 58:
                _fail()
        auto child = _alternative(r, depth + 1)
        if _take(r) != 41:
            _fail()
        return child
    if c == 91:
        auto negate = False
        if _peek(r) == 94:
            negate = True
            auto caret = _take(r)
        list[int64] ranges = []
        list[int64] choices = []
        while _peek(r) != 93:
            auto first = _take(r)
            auto atom = -1
            if first == 92:
                atom = _escape(r, True)
            else:
                atom = _literal(r, first)
            if _peek(r) == 45:
                # A trailing dash is a literal, not a range.
                if r.offset + 1 < len(r.source):
                    if r.source[r.offset + 1] != 93:
                        auto dash = _take(r)
                        auto last = _take(r)
                        auto end = -1
                        if last == 92:
                            end = _escape(r, True)
                        else:
                            end = _literal(r, last)
                        auto a = r.nodes[atom]
                        auto b = r.nodes[end]
                        if a.negate or b.negate or a.property != "" or b.property != "":
                            _fail()
                        if len(a.ranges) != 2 or len(b.ranges) != 2:
                            _fail()
                        if a.ranges[0] > b.ranges[0]:
                            _fail()
                        atom = _node(
                            r,
                            1,
                            0,
                            0,
                            0,
                            0,
                            [a.ranges[0], b.ranges[0]],
                            False,
                            "",
                        )
            choices.append(atom)
        auto close = _take(r)
        auto result = _simple(r, 10)
        for choice in choices:
            result = _node(r, 4, result, choice, 0, 0, [], False, "")
        if negate:
            result = _node(r, 11, result, 0, 0, 0, [], False, "")
        return result
    if c == 92:
        return _escape(r, False)
    if c == 46:
        return _simple(r, 2)
    if c == 94:
        return _simple(r, 6)
    if c == 36:
        return _simple(r, 7)
    if c in [41, 42, 43, 63]:
        _fail()
    return _literal(r, c)

def _integer(Regex r) -> int64:
    if not _digit(_peek(r)):
        _fail()
    auto value = 0
    while _digit(_peek(r)):
        value = value * 10 + _take(r) - 48
        if value > 100000:
            _fail()
    return value

def _sequence(Regex r, int64 depth) -> int64:
    auto result = _simple(r, 0)
    while not _peek(r) in [-1, 41, 124]:
        auto child = _atom(r, depth)
        auto c = _peek(r)
        auto minimum = -1
        auto maximum = -1
        if c in [42, 43, 63]:
            auto token = _take(r)
            minimum = 0
            if c == 43:
                minimum = 1
            if c == 63:
                maximum = 1
        elif c == 123:
            if r.offset + 1 < len(r.source):
                if _digit(r.source[r.offset + 1]):
                    auto open = _take(r)
                    minimum = _integer(r)
                    maximum = minimum
                    if _peek(r) == 44:
                        auto comma = _take(r)
                        maximum = -1
                        if _digit(_peek(r)):
                            maximum = _integer(r)
                    if _take(r) != 125:
                        _fail()
                    if maximum >= 0 and maximum < minimum:
                        _fail()
        if minimum >= 0:
            child = _node(r, 5, child, 0, minimum, maximum, [], False, "")
            if _peek(r) == 63:
                auto lazy = _take(r)
        result = _node(r, 3, result, child, 0, 0, [], False, "")
    return result

def _alternative(Regex r, int64 depth) -> int64:
    auto result = _sequence(r, depth)
    while _peek(r) == 124:
        auto bar = _take(r)
        result = _node(r, 4, result, _sequence(r, depth), 0, 0, [], False, "")
    return result

def compile(str source) -> Regex:
    auto points = _points(source)
    if len(points) > 4096:
        _fail()
    auto r = Regex(source=points, offset=0, nodes=[], root=0)
    r.root = _alternative(r, 0)
    if _peek(r) != -1:
        _fail()
    return r

def _word(int64 cp) -> bool:
    return cp >= 48 and cp <= 57 or cp >= 65 and cp <= 90 or cp == 95 or cp >= 97 and cp <= 122

def _property(int64 cp, str name) -> bool:
    auto text = str(chr(cp))
    if name in ["L", "Letter"]:
        if text =~ m/(*UTF)\p{L}/:
            return True
        return False
    if name in ["N", "Number"]:
        if text =~ m/(*UTF)\p{N}/:
            return True
        return False
    if name in ["Nd", "Decimal_Number"]:
        if text =~ m/(*UTF)\p{Nd}/:
            return True
        return False
    if name in ["M", "Mark"]:
        if text =~ m/(*UTF)\p{M}/:
            return True
        return False
    if text =~ m/(*UTF)\p{Z}/:
        return True
    return False

def _add(list[int64] target, int64 value):
    if not value in target:
        target.append(value)

def _positions(MatchState state, int64 id, int64 start, int64 depth) -> list[int64]:
    state.steps = state.steps + 1
    if state.steps > 250000 or depth > 512:
        raise "EvaluationError: regex resource limit exceeded"
    auto key = str(id) + ":" + str(start)
    if key in state.memo:
        return state.memo[key]
    auto node = state.regex.nodes[id]
    list[int64] result = []
    if node.kind == 0:
        result.append(start)
    elif node.kind == 1:
        if start < len(state.text):
            auto cp = state.text[start]
            auto matches = False
            if node.property != "":
                matches = _property(cp, node.property)
            else:
                auto i = 0
                while i < len(node.ranges):
                    if cp >= node.ranges[i] and cp <= node.ranges[i + 1]:
                        matches = True
                    i = i + 2
            if matches != node.negate:
                result.append(start + 1)
    elif node.kind == 2:
        if start < len(state.text):
            if not state.text[start] in [10, 13, 8232, 8233]:
                result.append(start + 1)
    elif node.kind == 3:
        for middle in _positions(state, node.left, start, depth + 1):
            for end in _positions(state, node.right, middle, depth + 1):
                _add(result, end)
    elif node.kind == 4:
        for end in _positions(state, node.left, start, depth + 1):
            _add(result, end)
        for end in _positions(state, node.right, start, depth + 1):
            _add(result, end)
    elif node.kind == 5:
        list[int64] frontier = [start]
        auto repeats = 0
        auto maximum = node.maximum
        if maximum < 0:
            maximum = len(state.text) + node.minimum + 1
        if node.minimum == 0:
            result.append(start)
        while repeats < maximum and len(frontier) > 0:
            list[int64] next = []
            for position in frontier:
                for end in _positions(state, node.left, position, depth + 1):
                    _add(next, end)
            repeats = repeats + 1
            if repeats >= node.minimum:
                for end in next:
                    _add(result, end)
            if _same(next, frontier):
                # A nullable expression cannot add new positions after stability.
                if maximum >= node.minimum:
                    for end in next:
                        _add(result, end)
                break
            frontier = next
    elif node.kind == 6:
        if start == 0:
            result.append(start)
    elif node.kind == 7:
        if start == len(state.text):
            result.append(start)
    elif node.kind in [8, 9]:
        auto before = False
        auto after = False
        if start > 0:
            before = _word(state.text[start - 1])
        if start < len(state.text):
            after = _word(state.text[start])
        if (before != after) == (node.kind == 8):
            result.append(start)
    elif node.kind == 11:
        if start < len(state.text):
            if len(_positions(state, node.left, start, depth + 1)) == 0:
                result.append(start + 1)
    state.memo[key] = result
    return result

def search(Regex regex, str text) -> bool:
    auto state = MatchState(regex=regex, text=_points(text), memo={}, steps=0)
    for start in range(len(state.text) + 1):
        if len(_positions(state, regex.root, start, 0)) > 0:
            return True
    return False


def _same(list[int64] a, list[int64] b) -> bool:
    if len(a) != len(b):
        return False
    for i in range(len(a)):
        if a[i] != b[i]:
            return False
    return True
