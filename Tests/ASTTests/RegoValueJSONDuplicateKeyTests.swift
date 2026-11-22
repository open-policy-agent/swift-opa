import Foundation
import Testing

@testable import AST

// Builds a JSON `\uXXXX` escape. Kept as a helper so the escapes are spelled out at runtime.
private func esc(_ hex: String) -> String { "\\" + "u" + hex }

private func utf16(_ s: String, bigEndian: Bool) -> Data {
    var out = Data()
    for unit in s.utf16 {
        let bytes = bigEndian ? [UInt8(unit >> 8), UInt8(unit & 0xFF)] : [UInt8(unit & 0xFF), UInt8(unit >> 8)]
        out.append(contentsOf: bytes)
    }
    return out
}

private func utf32LE(_ s: String) -> Data {
    var out = Data()
    for scalar in s.unicodeScalars {
        let v = scalar.value
        out.append(contentsOf: [UInt8(v & 0xFF), UInt8((v >> 8) & 0xFF), UInt8((v >> 16) & 0xFF), UInt8(v >> 24)])
    }
    return out
}

@Suite
struct RegoValueJSONDuplicateKeyTests {
    struct TestCase: Sendable, CustomTestStringConvertible {
        let description: String
        let json: String
        var testDescription: String { description }
    }

    static let duplicateCases: [TestCase] = [
        TestCase(description: "top-level duplicate", json: #"{"role":"guest","role":"admin"}"#),
        TestCase(description: "triple duplicate", json: #"{"role":"a","role":"b","role":"c"}"#),
        TestCase(description: "nested duplicate", json: #"{"user":{"role":"guest","role":"admin"}}"#),
        TestCase(description: "duplicate in array element", json: #"[{"a":1},{"a":1,"a":2}]"#),
        TestCase(description: "same values", json: #"{"a":1,"a":1}"#),
        TestCase(description: "empty key", json: #"{"":1,"":2}"#),
        TestCase(description: "escaped letter", json: #"{"role":"guest",""# + esc("0072") + #"ole":"admin"}"#),
        TestCase(description: "escaped quote in key", json: #"{"a\"b":1,"a\"b":2}"#),
        TestCase(description: "escaped vs raw quote", json: #"{"a\"b":1,"a"# + esc("0022") + #"b":2}"#),
        TestCase(description: "escaped solidus", json: #"{"a/b":1,"a\/b":2}"#),
        TestCase(description: "escaped backslash", json: #"{"a\\":1,"a"# + esc("005c") + #"":2}"#),
        // Unicode can encode some characters in more than one way. "é" is one precomposed code point (U+00E9),
        // or a decomposed "e" followed by a combining accent (U+0301). Swift treats both spellings as the same string.
        TestCase(
            description: "precomposed vs decomposed (escaped)",
            json: #"{""# + esc("00e9") + #"":1,"e"# + esc("0301") + #"":2}"#
        ),
        TestCase(
            description: "precomposed vs decomposed (raw)",
            json: "{\"\u{00E9}\":1,\"e\u{0301}\":2}"
        ),
        TestCase(
            description: "surrogate pair escape vs raw astral",
            json: "{\"\u{1F600}\":1,\"" + esc("d83d") + esc("de00") + "\":2}"
        ),
    ]

    struct UniqueCase: Sendable, CustomTestStringConvertible {
        let description: String
        let json: String
        let expected: RegoValue
        var testDescription: String { description }
    }

    static let uniqueCases: [UniqueCase] = [
        UniqueCase(description: "empty object", json: "{}", expected: .object([:])),
        UniqueCase(description: "array without objects", json: "[1,2,3]", expected: [1, 2, 3]),
        UniqueCase(
            description: "same key in nested objects",
            json: #"{"a":{"a":{"a":1}}}"#,
            expected: ["a": ["a": ["a": 1]]]
        ),
        UniqueCase(
            description: "same key in sibling objects",
            json: #"[{"a":1},{"a":2}]"#,
            expected: [["a": 1], ["a": 2]]
        ),
        UniqueCase(description: "case differs", json: #"{"a":1,"A":2}"#, expected: ["a": 1, "A": 2]),
        UniqueCase(
            description: "colons in strings",
            json: #"{"a:b":"c:d","e":"::","f":[":"]}"#,
            expected: ["a:b": "c:d", "e": "::", "f": [":"]]
        ),
        UniqueCase(
            description: "escaped quote then colon in key",
            json: #"{"x\":y":1,"z":2}"#,
            expected: ["x\":y": 1, "z": 2]
        ),
        UniqueCase(
            description: "key ending in backslash",
            json: #"{"a\\":1,"b":2}"#,
            expected: ["a\\": 1, "b": 2]
        ),
        UniqueCase(
            description: "key ending in backslash and quote",
            json: #"{"a\\\"":1,"b":2}"#,
            expected: ["a\\\"": 1, "b": 2]
        ),
        UniqueCase(
            description: "escaped colon in key",
            json: #"{"a"# + esc("003a") + #"b":1,"ab":2}"#,
            expected: ["a:b": 1, "ab": 2]
        ),
        UniqueCase(
            description: "accent vs plain letter",
            json: "{\"\u{00E9}\":1,\"e\":2}",
            expected: ["\u{00E9}": 1, "e": 2]
        ),
        UniqueCase(
            description: "whitespace around colons",
            json: "{ \"a\" : 1 ,\n\t\"b\"\r\n:\n2 }",
            expected: ["a": 1, "b": 2]
        ),
    ]

    @Test(arguments: duplicateCases, CheckedParser.allCases)
    func rejectsDuplicateKeys(tc: TestCase, parser: CheckedParser) {
        #expect(throws: RegoValue.JSONInputError.duplicateObjectKeys) {
            try parser.parse(Data(tc.json.utf8))
        }
    }

    @Test(arguments: uniqueCases, CheckedParser.allCases)
    func acceptsUniqueKeys(tc: UniqueCase, parser: CheckedParser) throws {
        #expect(try parser.parse(Data(tc.json.utf8)) == tc.expected)
    }

    // The JSONDecoder path keeps JSONDecoder's behavior for fragments and exact numbers.
    @Test(arguments: [
        ("5", RegoValue.number(RegoNumber(int: 5))),
        (#""text""#, .string("text")),
        ("null", .null),
        ("18446744073709551615", .number(RegoNumber(value: UInt64.max))),
    ])
    func jsonDecoderPathAcceptsScalars(json: String, expected: RegoValue) throws {
        #expect(try RegoValue.decodeRejectingDuplicateKeys(json: Data(json.utf8)) == expected)
    }

    @Test
    func errorsHaveReadableDescriptions() {
        let error: any Error = RegoValue.JSONInputError.duplicateObjectKeys
        #expect(error.localizedDescription == "JSON object contains duplicate keys")
    }

    @Test
    func escapeHelperProducesBackslashU() {
        #expect(Array(esc("0072").utf8) == [0x5C, 0x75, 0x30, 0x30, 0x37, 0x32])
    }

    static let nulCases: [(String, Data)] = [
        ("UTF-16LE", utf16(#"{"a":1}"#, bigEndian: false)),
        ("UTF-16BE", utf16(#"{"a":1}"#, bigEndian: true)),
        ("UTF-16LE with BOM", Data([0xFF, 0xFE]) + utf16(#"{"a":1}"#, bigEndian: false)),
        ("UTF-32LE", utf32LE(#"{"a":1}"#)),
        ("raw NUL in string", Data(#"{"a":"x"#.utf8) + Data([0]) + Data(#""}"#.utf8)),
        ("raw NUL after backslash", Data(#"{"a":"x\"#.utf8) + Data([0]) + Data(#""}"#.utf8)),
    ]

    @Test(arguments: nulCases, CheckedParser.allCases)
    func rejectsNULBytes(nulCase: (String, Data), parser: CheckedParser) {
        #expect(throws: RegoValue.JSONInputError.nulByte) {
            try parser.parse(nulCase.1)
        }
    }
}

// Canaries for the parser strictness the duplicate key scanner relies on. A failure means the check is unsound on that platform.
@Suite
struct JSONParserCanaryTests {
    static let rejected: [(String, [UInt8])] = [
        ("lone 0xFF in string", Array(#"{"a":"x"#.utf8) + [0xFF] + Array(#""}"#.utf8)),
        ("truncated lead byte before quote", Array(#"{"a":"x"#.utf8) + [0xC2] + Array(#"","b":1}"#.utf8)),
        ("truncated 3-byte lead before quote", Array(#"{"a":"x"#.utf8) + [0xE2, 0x82] + Array(#"","b":1}"#.utf8)),
        ("lead byte before colon", Array(#"{"a""#.utf8) + [0xC2] + Array(#":1}"#.utf8)),
        ("overlong quote", Array(#"{"a":"x"#.utf8) + [0xC0, 0xA2] + Array(#""}"#.utf8)),
        ("overlong colon", Array(#"{"a""#.utf8) + [0xC0, 0xBA] + Array(#"1}"#.utf8)),
        ("UTF-8 encoded surrogate", Array(#"{"a":""#.utf8) + [0xED, 0xA0, 0x80] + Array(#""}"#.utf8)),
        ("invalid escape", Array(#"{"a":"\x41"}"#.utf8)),
        ("line comment", Array("{\"a\":1 // c:\n}".utf8)),
        ("block comment", Array(#"{"a":1 /* "b":2 */}"#.utf8)),
        ("unquoted key", Array(#"{a:1}"#.utf8)),
        ("single-quoted key", Array(#"{'a':1}"#.utf8)),
    ]

    @Test(arguments: rejected)
    func jsonSerializationRejects(name: String, bytes: [UInt8]) {
        #expect(throws: (any Error).self) {
            try JSONSerialization.jsonObject(with: Data(bytes))
        }
    }

    @Test(arguments: rejected)
    func jsonDecoderRejects(name: String, bytes: [UInt8]) {
        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(RegoValue.self, from: Data(bytes))
        }
    }
}

// The checked entry points: JSONSerialization-based, JSONDecoder-based (json.unmarshal, json.is_valid),
// and the standalone check used before decoding manifests, plans, and capabilities.
enum CheckedParser: String, CaseIterable, Sendable {
    case jsonSerialization, jsonDecoder, checkThenDecode

    func parse(_ data: Data) throws -> RegoValue {
        switch self {
        case .jsonSerialization:
            return try RegoValue(jsonData: data)
        case .jsonDecoder:
            return try RegoValue.decodeRejectingDuplicateKeys(json: data)
        case .checkThenDecode:
            try RegoValue.checkForDuplicateKeys(json: data)
            return try JSONDecoder().decode(RegoValue.self, from: data)
        }
    }
}

// A seeded randomized (property-based) test. Each document is generated alongside the RegoValue it should parse to
// and whether it has duplicates, which is known because the generator picks every key from keyPool. Keys are spelled
// with random escapes, so equal keys often look different in the raw JSON. We use a fixed seed to make runs reproducible.
@Suite
struct RegoValueJSONDuplicateKeyGeneratedTests {
    // SplitMix64. Choices come from next() directly, since stdlib random helpers can change across toolchains.
    struct RNG {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
        mutating func below(_ n: Int) -> Int { Int(next() % UInt64(n)) }
        mutating func int(in r: ClosedRange<Int>) -> Int { r.lowerBound + below(r.count) }
        mutating func coin() -> Bool { next() & 1 == 1 }
        mutating func pick<T>(_ a: [T]) -> T { a[below(a.count)] }
    }

    static let keyPool: [String] = [
        "a", "b", "role", "", " ", ":", "a:b", "x\"y", "\"", "back\\", "\\", "\\\"", "/", "{}",
        "\u{00E9}", "e\u{0301}", "\u{1F600}", "\u{00C5}", "A\u{030A}", "\u{212B}",
    ]

    // Spells one scalar as JSON, either raw or escaped.
    static func spell(_ scalar: Unicode.Scalar, _ rng: inout RNG) -> String {
        let escape = rng.coin()
        switch scalar {
        case "\"":
            return escape ? esc("0022") : "\\\""
        case "\\":
            return escape ? esc("005c") : "\\\\"
        case "/":
            return escape ? "\\/" : "/"
        default:
            guard escape else { return String(scalar) }
            return String(scalar).utf16.map { unit in
                let hex = String(unit, radix: 16)
                return esc(String(repeating: "0", count: 4 - hex.count) + hex)
            }.joined()
        }
    }

    static func spellString(_ s: String, _ rng: inout RNG) -> String {
        "\"" + s.unicodeScalars.map { spell($0, &rng) }.joined() + "\""
    }

    // Returns the JSON text, expected value, and whether any object has duplicates. Top-level values are containers.
    static func generate(depth: Int, topLevel: Bool = false, _ rng: inout RNG) -> (String, RegoValue, Bool) {
        let choice = topLevel ? rng.int(in: 3...5) : rng.below(depth > 0 ? 6 : 3)
        switch choice {
        case 0:
            let n = rng.int(in: -100...100)
            return ("\(n)", .number(RegoNumber(value: n)), false)
        case 1:
            let s = rng.pick(keyPool)
            return (spellString(s, &rng), .string(s), false)
        case 2:
            return rng.coin() ? ("true", true, false) : ("null", .null, false)
        case 3:
            var parts: [String] = []
            var values: [RegoValue] = []
            var dup = false
            for _ in 0..<rng.int(in: 0...3) {
                let (j, v, d) = generate(depth: depth - 1, &rng)
                parts.append(j)
                values.append(v)
                dup = dup || d
            }
            return ("[" + parts.joined(separator: ",") + "]", .array(values), dup)
        default:
            var parts: [String] = []
            var keys: [String] = []
            var object: [RegoValue: RegoValue] = [:]
            var dup = false
            for _ in 0..<rng.int(in: 0...4) {
                let key = rng.pick(keyPool)
                let (j, v, d) = generate(depth: depth - 1, &rng)
                parts.append(spellString(key, &rng) + ":" + j)
                keys.append(key)
                object[.string(key)] = v
                dup = dup || d
            }
            dup = dup || Set(keys).count != keys.count
            return ("{" + parts.joined(separator: ",") + "}", .object(object), dup)
        }
    }

    @Test(arguments: [1, 2, 3, 4], CheckedParser.allCases)
    func generatedDocuments(seed: UInt64, parser: CheckedParser) throws {
        var rng = RNG(state: seed)
        var rejected = 0
        for i in 0..<2_000 {
            let (json, expected, hasDuplicates) = Self.generate(depth: 4, topLevel: true, &rng)
            let result = Result { try parser.parse(Data(json.utf8)) }
            if hasDuplicates {
                #expect(throws: RegoValue.JSONInputError.duplicateObjectKeys, "seed \(seed) doc \(i): \(json)") {
                    try result.get()
                }
                rejected += 1
            } else {
                #expect(try result.get() == expected, "seed \(seed) doc \(i): \(json)")
            }
        }
        // Both outcomes must be well represented for the test to mean anything.
        #expect(rejected > 200 && rejected < 1_800, "rejected \(rejected) of 2000")
    }

    // The scanner alone must find every duplicate, since decoders skip members they don't know.
    @Test(arguments: [1, 2, 3, 4])
    func generatedDocumentsScanner(seed: UInt64) {
        var rng = RNG(state: seed)
        for i in 0..<2_000 {
            let (json, _, hasDuplicates) = Self.generate(depth: 4, topLevel: true, &rng)
            let expected: JSONKeyScan = hasDuplicates ? .duplicate : .unique
            #expect(scanJSONObjectKeys(Data(json.utf8)) == expected, "seed \(seed) doc \(i): \(json)")
        }
    }
}
