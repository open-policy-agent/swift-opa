import Foundation
import Testing

@testable import AST

// Builds a JSON `\uXXXX` escape. Kept as a helper so the escapes are spelled out at runtime.
private func esc(_ hex: String) -> String { "\\" + "u" + hex }

// Builds an object with keys k0..<k(count), each mapped to `value`, plus any extra raw members.
private func object(keys count: Int, value: String = "1", extra: String = "") -> String {
    let members = (0..<count).map { "\"k\($0)\":\(value)" } + (extra.isEmpty ? [] : [extra])
    return "{" + members.joined(separator: ",") + "}"
}

// The number of keys at which an object switches from linear checks to a Set.
private let limit = jsonKeyScanLinearLimit

@Suite
struct JSONDuplicateKeyScannerTests {
    struct Case: Sendable, CustomTestStringConvertible {
        let description: String
        let json: String
        var testDescription: String { description }
    }

    static let duplicates: [Case] = [
        Case(description: "top level", json: #"{"a":1,"a":2}"#),
        Case(description: "with whitespace", json: "{ \"a\" : 1 ,\n \"a\" : 2 }"),
        Case(description: "after a nested object", json: #"{"a":{"b":1},"a":2}"#),
        Case(description: "after a nested array", json: #"{"a":[1,{"a":1}],"a":2}"#),
        Case(description: "inside an array element", json: #"[{"a":1},{"a":1,"a":2}]"#),
        Case(description: "deep inside arrays", json: #"{"x":[[{"y":[{"a":1,"a":2}]}]]}"#),
        Case(description: "with a trailing comma", json: #"{"a":1,"a":2,}"#),
        Case(description: "empty keys", json: #"{"":1,"":2}"#),
        Case(description: "escaped letter", json: #"{"role":1,""# + esc("0072") + #"ole":2}"#),
        Case(description: "escaped quote", json: #"{"a\"b":1,"a"# + esc("0022") + #"b":2}"#),
        Case(description: "escaped solidus", json: #"{"a/b":1,"a\/b":2}"#),
        Case(description: "escaped backslash", json: #"{"a\\":1,"a"# + esc("005c") + #"":2}"#),
        Case(description: "escaped newline", json: #"{"\n":1,""# + esc("000a") + #"":2}"#),
        Case(description: "uppercase hex escape", json: #"{""# + esc("00E9") + #"":1,""# + esc("00e9") + #"":2}"#),
        Case(
            description: "precomposed vs decomposed (escaped)",
            json: #"{""# + esc("00e9") + #"":1,"e"# + esc("0301") + #"":2}"#),
        Case(description: "precomposed vs decomposed (raw)", json: "{\"\u{00E9}\":1,\"e\u{0301}\":2}"),
        Case(description: "Kelvin sign vs K", json: "{\"K\":1,\"\u{212A}\":2}"),
        Case(description: "Angstrom sign vs A with ring", json: "{\"\u{00C5}\":1,\"\u{212B}\":2}"),
        Case(
            description: "surrogate pair vs raw astral",
            json: "{\"\u{1F600}\":1,\"" + esc("d83d") + esc("de00") + "\":2}"),
        Case(description: "duplicate below the Set limit", json: object(keys: 10, extra: #""k3":0"#)),
        Case(
            description: "duplicate of an early key past the Set limit",
            json: object(keys: limit + 8, extra: #""k3":0"#)),
        Case(
            description: "duplicate of a late key past the Set limit",
            json: object(keys: limit + 8, extra: "\"k\(limit + 4)\":0")),
        Case(description: "duplicate right at the Set limit", json: object(keys: limit, extra: #""k0":0"#)),
        Case(
            description: "duplicate of the key that reached the Set limit",
            json: object(keys: limit, extra: "\"k\(limit - 1)\":0")),
        Case(
            description: "duplicate after a nested object, past the Set limit",
            json: object(keys: limit + 8, extra: #""child":{"x":1,"y":2},"k3":0"#)),
    ]

    static let unique: [Case] = [
        Case(description: "empty object", json: "{}"),
        Case(description: "distinct keys", json: #"{"a":1,"b":2}"#),
        Case(description: "case differs", json: #"{"a":1,"A":2}"#),
        Case(description: "same key in sibling objects", json: #"{"a":{"a":1},"b":{"a":2}}"#),
        Case(description: "same key in array elements", json: #"[{"a":1},{"a":1}]"#),
        Case(description: "same key at different depths", json: #"{"a":{"a":{"a":1}}}"#),
        Case(description: "parent key repeats a closed child's key", json: #"{"a":{"b":1},"b":2}"#),
        Case(description: "parent key repeats a closed array element's key", json: #"{"a":[{"b":1}],"b":2}"#),
        Case(description: "repeated strings in an array", json: #"{"k":["a","a"],"j":"a"}"#),
        Case(description: "structural characters inside strings", json: #"{"x":"a:b,{\"c\":1}","y":"}],\"x\":"}"#),
        Case(description: "key-like value", json: #"{"a":"a","b":"a"}"#),
        Case(description: "with a trailing comma", json: #"{"a":1,"b":2,}"#),
        Case(description: "top-level scalar", json: #""a""#),
        Case(description: "top-level array of strings", json: #"["a","a"]"#),
        Case(description: "many keys", json: object(keys: 1_000)),
        Case(
            description: "sibling objects past the Set limit",
            json: "[" + object(keys: limit + 8) + "," + object(keys: limit + 8) + "]"),
        Case(
            description: "nested object reusing a key, past the Set limit",
            json: object(keys: limit + 8, extra: "\"child\":{\"k\(limit + 4)\":1,\"k0\":2},\"z\":0")),
        Case(
            description: "nested objects past the Set limit",
            json: object(keys: limit + 8, value: object(keys: limit + 8))),
        Case(
            description: "deep nesting",
            json: String(repeating: #"{"a":["#, count: 300) + String(repeating: "]}", count: 300)),
    ]

    @Test(arguments: duplicates)
    func findsDuplicates(tc: Case) {
        #expect(scanJSONObjectKeys(Data(tc.json.utf8)) == .duplicate)
    }

    @Test(arguments: unique)
    func acceptsUniqueKeys(tc: Case) {
        #expect(scanJSONObjectKeys(Data(tc.json.utf8)) == .unique)
    }

    static let nulInputs: [(String, Data)] = [
        ("outside strings", Data(#"{"a":1}"#.utf8) + Data([0])),
        ("in a key", Data(#"{"a"#.utf8) + Data([0]) + Data(#"":1}"#.utf8)),
        ("in a value", Data(#"{"a":"x"#.utf8) + Data([0]) + Data(#""}"#.utf8)),
        ("after a backslash", Data(#"{"a":"x\"#.utf8) + Data([0]) + Data(#""}"#.utf8)),
        ("UTF-16LE", Data([0x7B, 0x00, 0x7D, 0x00])),
    ]

    @Test(arguments: nulInputs)
    func rejectsNULBytes(input: (String, Data)) {
        #expect(scanJSONObjectKeys(input.1) == .nulByte)
    }

    // Data slices have a non-zero startIndex.
    @Test
    func scansDataSlices() {
        let data = Data(#"xx{"a":1,"a":2}xx"#.utf8)
        #expect(scanJSONObjectKeys(data[2..<15]) == .duplicate)
        #expect(scanJSONObjectKeys(data[2..<9]) == .unique)
    }

    // Truncated input must not crash. The parser rejects it.
    @Test(arguments: [#"{"a"#, #"{"a\"#, #"{""# + esc("00"), #"{"a":1,"#, "{", "[", "\""])
    func toleratesTruncatedInput(json: String) {
        _ = scanJSONObjectKeys(Data(json.utf8))
    }

    // Malformed escapes and lone surrogates decode to U+FFFD, so they can collide. The parser rejects such input
    // anyway, and its error is reported instead, since duplicates are only reported once parsing succeeds.
    @Test
    func malformedEscapesCollide() {
        let invalidEscapes = #"{"\q":1,"\z":2}"#
        #expect(scanJSONObjectKeys(Data(invalidEscapes.utf8)) == .duplicate)
        #expect {
            try RegoValue(jsonData: Data(invalidEscapes.utf8))
        } throws: { error in
            !(error is RegoValue.JSONInputError)
        }
        let loneSurrogate = #"{""# + esc("d800") + #"":1,""# + esc("fffd") + #"":2}"#
        #expect(scanJSONObjectKeys(Data(loneSurrogate.utf8)) == .duplicate)
    }

    // A NUL byte is reported even when the parser would accept the input, as it does for UTF-16.
    @Test
    func nulTakesPrecedenceOverParsing() {
        #expect(throws: RegoValue.JSONInputError.nulByte) {
            try RegoValue.parseRejectingDuplicateKeys(Data([0x7B, 0x00, 0x7D, 0x00])) { 0 }
        }
    }

    // Duplicates are reported only once parsing succeeds.
    @Test
    func parseErrorsTakePrecedenceOverDuplicates() {
        struct ParseFailure: Error {}
        #expect(throws: ParseFailure.self) {
            try RegoValue.parseRejectingDuplicateKeys(Data(#"{"a":1,"a":2}"#.utf8)) { throw ParseFailure() }
        }
        #expect(throws: RegoValue.JSONInputError.duplicateObjectKeys) {
            try RegoValue.parseRejectingDuplicateKeys(Data(#"{"a":1,"a":2}"#.utf8)) { 0 }
        }
    }
}
