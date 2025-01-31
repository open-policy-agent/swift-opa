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

    static let containsTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "base case positive",
            name: "contains",
            args: [.string("hello, world!"), .string("world")],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "base case negative",
            name: "contains",
            args: [.string("hello, world!"), .string("zzzzz")],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "empty needle",
            name: "contains",
            args: [.string("hello, world!"), .string("")],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "full match",
            name: "contains",
            args: [.string("abc"), .string("abc")],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "more than a full match",
            name: "contains",
            args: [.string("bc"), .string("abcd")],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "empty haystack",
            name: "contains",
            args: [.string(""), .string("abc")],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "both empty",
            name: "contains",
            args: [.string(""), .string("")],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "contains",
            args: [.string("hello, world!"), .string("world"), .string("extra")],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 3, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "contains",
            args: [.string("hello, world!")],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 1, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "no args",
            name: "contains",
            args: [],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 0, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "wrong type needle",
            name: "contains",
            args: [.string("hello, world!"), .number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "needle"))
        ),
        BuiltinTests.TestCase(
            description: "wrong type haystack",
            name: "contains",
            args: [.number(1), .string("hello, world!")],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "needle"))
        ),
    ]

    static var allTests: [BuiltinTests.TestCase] {
        [
            concatTests,
            containsTests,
        ].flatMap { $0 }
    }

    @Test(arguments: allTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await BuiltinTests.testBuiltin(tc: tc)
    }
}
