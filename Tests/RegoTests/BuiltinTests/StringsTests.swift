import AST
import Foundation
import Testing

@testable import Rego

@Suite("BuiltinTests - Strings")
struct StringsTests {
    static let concatTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "simple array csv",
            name: "concat",
            args: [.string(","), .array([.string("a"), .string("b"), .string("c")])],
            expected: .success(.string("a,b,c"))
        ),
        BuiltinTests.TestCase(
            description: "empty array csv",
            name: "concat",
            args: [.string(","), .array([])],
            expected: .success(.string(""))
        ),
        BuiltinTests.TestCase(
            description: "array multi character separator",
            name: "concat",
            args: [
                .string("a really big delineator compared to the usual comma"),
                .array([.string("a"), .string("b"), .string("c")]),
            ],
            expected: .success(
                .string(
                    "aa really big delineator compared to the usual commaba really big delineator compared to the usual commac"
                ))
        ),
        BuiltinTests.TestCase(
            description: "simple set csv",
            name: "concat",
            args: [.string(","), .set([.string("a"), .string("b"), .string("c")])],
            expected: .success(.string("a,b,c"))
        ),
        BuiltinTests.TestCase(
            description: "empty set csv",
            name: "concat",
            args: [.string(","), .set([])],
            expected: .success(.string(""))
        ),
        BuiltinTests.TestCase(
            description: "set multi character separator",
            name: "concat",
            args: [
                .string("a really big delineator compared to the usual comma"),
                .set([.string("a"), .string("b"), .string("c")]),
            ],
            expected: .success(
                .string(
                    "aa really big delineator compared to the usual commaba really big delineator compared to the usual commac"
                ))
        ),
        BuiltinTests.TestCase(
            description: "empty delineator",
            name: "concat",
            args: [.string(""), .array([.string("a"), .string("b"), .string("c")])],
            expected: .success(.string("abc"))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "array.concat",
            args: [.number(1), .number(1), .number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 3, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "too few args 1",
            name: "array.concat",
            args: [.string(",")],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 1, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "too few args 2",
            name: "array.concat",
            args: [.array([.string("a")])],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 1, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "wrong delineator type",
            name: "concat",
            args: [.number(123), .array([.string("a"), .string("b"), .string("c")])],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "delineator"))
        ),
        BuiltinTests.TestCase(
            description: "wrong collection type",
            name: "concat",
            args: [.string(","), .object([.string("not an array or set"): .string("but still a swift Collection")])],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "collection"))
        ),
        BuiltinTests.TestCase(
            description: "wrong collection element type in array",
            name: "concat",
            args: [.string(","), .array([.string("a"), .number(123), .string("c")])],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "collection element 123"))
        ),
        BuiltinTests.TestCase(
            description: "wrong collection element type in set",
            name: "concat",
            args: [.string(","), .set([.string("a"), .number(123), .string("c")])],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "collection element 123"))
        ),
    ]

    static var allTests: [BuiltinTests.TestCase] {
        [
            concatTests
        ].flatMap { $0 }
    }

    @Test(arguments: allTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await BuiltinTests.testBuiltin(tc: tc)
    }
}
