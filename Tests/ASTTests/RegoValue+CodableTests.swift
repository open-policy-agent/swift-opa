import Foundation
import Testing

@testable import AST

@Suite
struct RegoValueEncodingTests {

    struct TestCase: CustomDebugStringConvertible {
        let description: String
        let value: AST.RegoValue
        var expected: String = ""
        var expectError: Bool = false

        var debugDescription: String {
            description
        }
    }

    static var stringEncodingTests: [TestCase] {
        [
            TestCase(description: "empty string", value: .string(""), expected: ""),
            TestCase(description: "simple string", value: .string("simple string"), expected: "simple string"),
            TestCase(description: "with quotes", value: .string("with \"quotes\""), expected: "with \"quotes\""),
            TestCase(description: "emojis", value: .string("🐙🐠🐈"), expected: "🐙🐠🐈"),
        ]
    }

    @Test(arguments: stringEncodingTests)
    func testEncodeStrings(tc: TestCase) throws {
        let encoded = try String(tc.value)
        #expect(encoded == tc.expected)
    }

    static var objectEncodingTests: [TestCase] {
        [
            TestCase(
                description: "empty object",
                value: [:],
                expected: "{}"
            ),
            TestCase(
                description: "simple string keys",
                value: [
                    "a": 1,
                    "b": "🐝",
                    "c": "see",
                ],
                expected: #"{"a":1,"b":"🐝","c":"see"}"#
            ),
            TestCase(
                description: "string keys with quotes",
                value: [
                    #""escaped""#: 1
                ],
                expected: #"{"\"escaped\"":1}"#
            ),
            TestCase(
                description: "numeric keys",
                value: .object([
                    0: "zero",
                    1: "one",
                    2: "two",
                ]),
                expected: #"{"0":"zero","1":"one","2":"two"}"#
            ),
            TestCase(
                description: "array keys",
                value: .object([
                    [0, "2", 3]: "value"
                ]),
                expected: #"{"[0,\"2\",3]":"value"}"#
            ),
            TestCase(
                description: "set keys",
                value: .object([
                    .set([3, 2, 1]): "value"
                ]),
                expected: #"{"[1,2,3]":"value"}"#
            ),
            TestCase(
                description: "object keys",
                value: .object([
                    .object([1: "a", "2": "b", 3: "c"]): "value"
                ]),
                expected: #"{"{\"1\":\"a\",\"2\":\"b\",\"3\":\"c\"}":"value"}"#
            ),
        ]
    }

    @Test(arguments: objectEncodingTests)
    func testEncodeObjects(tc: TestCase) throws {
        let encoded = try String(tc.value)
        #expect(encoded == tc.expected)
    }

    static let floatEncodingTests: [TestCase] = [
        TestCase(description: "nonconforming: NaN", value: .number(RegoNumber(value: Float.nan)), expectError: true),
        TestCase(
            description: "nonconforming: Infinity",
            value: .number(RegoNumber(value: Float.infinity)),
            expectError: true
        ),
        TestCase(description: "0.0->0", value: .number(RegoNumber(value: 0.0)), expected: "0"),
        TestCase(description: "3.141592657", value: .number(RegoNumber(value: 3.141592657)), expected: "3.141592657"),
        TestCase(description: "2.998e8->exploded", value: .number(RegoNumber(value: 2.998e8)), expected: "299800000"),
    ]

    static let knownLinuxIssues: Set<String> = [
        "3.141592657"
    ]

    private var isLinux: Bool {
        #if os(Linux)
            true
        #else
            false
        #endif
    }

    @Test(arguments: floatEncodingTests)
    func testEncodeFloat(tc: TestCase) throws {
        guard !tc.expectError else {
            #expect(throws: (any Error).self) {
                _ = try String(tc.value)
            }
            return
        }
        try withKnownIssue(isIntermittent: true) {
            let encoded = try String(tc.value)
            #expect(encoded == tc.expected)
        } when: {
            isLinux
        } matching: { _ in
            RegoValueEncodingTests.knownLinuxIssues.contains(tc.description)
        }
    }

    @Test
    func testEncodeNull() throws {
        #expect(try String(AST.RegoValue.null) == "null")
    }

    @Test
    func testEncodeBool() throws {
        #expect(try String(AST.RegoValue.boolean(true)) == "true")
        #expect(try String(AST.RegoValue.boolean(false)) == "false")
    }

}
