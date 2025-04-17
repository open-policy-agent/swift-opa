import AST
import Foundation
import Testing

@testable import Rego

extension BuiltinTests {
    @Suite("BuiltinTests - Types", .tags(.builtins))
    struct TypesTests {}
}

extension BuiltinTests.TypesTests {
    static var allTests: [BuiltinTests.TestCase] {
        [
            generate(
                name: "is_array",
                expectedResults: [
                    "array argument": true,
                    "empty array argument": true,
                ]),
            generate(
                name: "is_boolean",
                expectedResults: [
                    "boolean true argument": true,
                    "boolean false argument": true,
                ]),
            generate(
                name: "is_null",
                expectedResults: [
                    "null argument": true,
                    "null argument expressed as nil": true,
                ]),
            generate(
                name: "is_number",
                expectedResults: [
                    "integer argument": true,
                    "float argument": true,
                ]),
            generate(
                name: "is_object",
                expectedResults: [
                    "object argument": true,
                    "empty object argument": true,
                ]),
            generate(
                name: "is_set",
                expectedResults: [
                    "set argument": true,
                    "empty set argument": true,
                ]),
            generate(
                name: "is_string",
                expectedResults: [
                    "string argument": true,
                    "empty string argument": true,
                ]),
            generate(
                name: "type_name",
                expectedResults: [
                    "array argument": "array",
                    "empty array argument": "array",
                    "boolean true argument": "boolean",
                    "boolean false argument": "boolean",
                    "integer argument": "number",
                    "float argument": "number",
                    "null argument": "null",
                    "null argument expressed as nil": "null",
                    "object argument": "object",
                    "empty object argument": "object",
                    "string argument": "string",
                    "empty string argument": "string",
                    "set argument": "set",
                    "empty set argument": "set",
                    "undefined argument": "undefined",
                ]),
        ].flatMap { $0 }
    }

    @Test(arguments: allTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await BuiltinTests.testBuiltin(tc: tc)
    }

    // For all types tests, we will generate standard list of named tests plus two failure tests,
    // covering arguments size checks.
    // Note that failure tests are the same and expected result is hardcoded here.
    // To configure which tests should return true, we will provide expectedResults map that contains
    // test names to expected RegoValues.
    // Name argument is expected to match the builtin's name.
    static func generate(name: String, expectedResults: [String: RegoValue]) -> [BuiltinTests.TestCase] {
        return [
            BuiltinTests.TestCase(
                description: "wrong number of arguments (too few)",
                name: name,
                args: [],
                expected: .failure(BuiltinError.argumentCountMismatch(got: 0, want: 1))
            ),
            BuiltinTests.TestCase(
                description: "wrong number of arguments (too many)",
                name: name,
                args: [1, 2, 3],
                expected: .failure(BuiltinError.argumentCountMismatch(got: 3, want: 1))
            ),
            BuiltinTests.TestCase(
                description: "boolean true argument",
                name: name,
                args: [true],
                expected: .success(expectedResults["boolean true argument"] ?? .boolean(false))
            ),
            BuiltinTests.TestCase(
                description: "boolean false argument",
                name: name,
                args: [true],
                expected: .success(expectedResults["boolean false argument"] ?? .boolean(false))
            ),
            BuiltinTests.TestCase(
                description: "null argument",
                name: name,
                args: [.null],
                expected: .success(expectedResults["null argument"] ?? .boolean(false))
            ),
            BuiltinTests.TestCase(
                description: "null argument expressed as nil",
                name: name,
                args: [nil],
                expected: .success(expectedResults["null argument expressed as nil"] ?? .boolean(false))
            ),
            BuiltinTests.TestCase(
                description: "integer argument",
                name: name,
                args: [1],
                expected: .success(expectedResults["integer argument"] ?? .boolean(false))
            ),
            BuiltinTests.TestCase(
                description: "float argument",
                name: name,
                args: [-2.71828],
                expected: .success(expectedResults["float argument"] ?? .boolean(false))
            ),
            BuiltinTests.TestCase(
                description: "string argument",
                name: name,
                args: ["123"],
                expected: .success(expectedResults["string argument"] ?? .boolean(false))
            ),
            BuiltinTests.TestCase(
                description: "empty string argument",
                name: name,
                args: [""],
                expected: .success(expectedResults["empty string argument"] ?? .boolean(false))
            ),
            BuiltinTests.TestCase(
                description: "set argument",
                name: name,
                args: [.set([1])],
                expected: .success(expectedResults["set argument"] ?? .boolean(false))
            ),
            BuiltinTests.TestCase(
                description: "empty set argument",
                name: name,
                args: [.set([])],
                expected: .success(expectedResults["empty set argument"] ?? .boolean(false))
            ),
            BuiltinTests.TestCase(
                description: "object argument",
                name: name,
                args: [["a": 123]],
                expected: .success(expectedResults["object argument"] ?? .boolean(false))
            ),
            BuiltinTests.TestCase(
                description: "empty object argument",
                name: name,
                args: [[:]],
                expected: .success(expectedResults["empty object argument"] ?? .boolean(false))
            ),
            BuiltinTests.TestCase(
                description: "undefined argument",
                name: name,
                args: [.undefined],
                expected: .success(expectedResults["undefined argument"] ?? .boolean(false))
            ),
        ]
    }
}
