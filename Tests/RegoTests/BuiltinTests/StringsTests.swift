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

    static let endsWithTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "base case positive",
            name: "endswith",
            args: [.string("hello, world!"), .string("world!")],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "base case negative",
            name: "endswith",
            args: [.string("hello, world!"), .string("zzzzz")],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "empty base",
            name: "endswith",
            args: [.string("hello, world!"), .string("")],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "full match",
            name: "endswith",
            args: [.string("abc"), .string("abc")],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "more than a full match",
            name: "endswith",
            args: [.string("bc"), .string("abcd")],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "empty search",
            name: "endswith",
            args: [.string(""), .string("abc")],
            expected: .success(.boolean(false))
        ),
        BuiltinTests.TestCase(
            description: "both empty",
            name: "endswith",
            args: [.string(""), .string("")],
            expected: .success(.boolean(true))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "endswith",
            args: [.string("hello, world!"), .string("world!"), .string("extra")],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 3, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "endswith",
            args: [.string("hello, world!")],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 1, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "no args",
            name: "endswith",
            args: [],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 0, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "wrong type search",
            name: "endswith",
            args: [.string("hello, world!"), .number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "search"))
        ),
        BuiltinTests.TestCase(
            description: "wrong type base",
            name: "endswith",
            args: [.number(1), .string("hello, world!")],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "base"))
        ),
    ]

    static let indexOfTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "base case positive",
            name: "indexof",
            args: [.string("hello, world!"), .string("world")],
            expected: .success(.number(7))
        ),
        BuiltinTests.TestCase(
            description: "base case negative",
            name: "indexof",
            args: [.string("hello, world!"), .string("zzzzz")],
            expected: .success(.number(-1))
        ),
        BuiltinTests.TestCase(
            description: "empty needle",
            name: "indexof",
            args: [.string("hello, world!"), .string("")],
            expected: .success(.undefined)
        ),
        BuiltinTests.TestCase(
            description: "full match",
            name: "indexof",
            args: [.string("abc"), .string("abc")],
            expected: .success(.number(0))
        ),
        BuiltinTests.TestCase(
            description: "more than a full match",
            name: "indexof",
            args: [.string("bc"), .string("abcd")],
            expected: .success(.number(-1))
        ),
        BuiltinTests.TestCase(
            description: "empty haystack",
            name: "indexof",
            args: [.string(""), .string("abc")],
            expected: .success(.number(-1))
        ),
        BuiltinTests.TestCase(
            description: "both empty",
            name: "indexof",
            args: [.string(""), .string("")],
            expected: .success(.undefined)
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "indexof",
            args: [.string("hello, world!"), .string("world"), .string("extra")],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 3, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "indexof",
            args: [.string("hello, world!")],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 1, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "no args",
            name: "indexof",
            args: [],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 0, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "wrong type needle",
            name: "indexof",
            args: [.string("hello, world!"), .number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "needle"))
        ),
        BuiltinTests.TestCase(
            description: "wrong type haystack",
            name: "indexof",
            args: [.number(1), .string("hello, world!")],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "needle"))
        ),
    ]

    static let lowerTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "base",
            name: "lower",
            args: [.string("aAaAAaaAAAA A A a")],
            expected: .success(.string("aaaaaaaaaaa a a a"))
        ),
        BuiltinTests.TestCase(
            description: "empty string",
            name: "lower",
            args: [.string("")],
            expected: .success(.string(""))
        ),
        BuiltinTests.TestCase(
            description: "all lowercase",
            name: "lower",
            args: [.string("aaaa")],
            expected: .success(.string("aaaa"))
        ),
        BuiltinTests.TestCase(
            description: "all uppercase",
            name: "lower",
            args: [.string("AAAA")],
            expected: .success(.string("aaaa"))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "lower",
            args: [.string("hello, world!"), .string("world")],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 2, expected: 1))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "lower",
            args: [],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 0, expected: 1))
        ),
        BuiltinTests.TestCase(
            description: "wrong type arg",
            name: "lower",
            args: [.number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "x"))
        ),
    ]

    static let upperTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "base",
            name: "upper",
            args: [.string("aAaAAaaAAAA A A a")],
            expected: .success(.string("AAAAAAAAAAA A A A"))
        ),
        BuiltinTests.TestCase(
            description: "empty string",
            name: "upper",
            args: [.string("")],
            expected: .success(.string(""))
        ),
        BuiltinTests.TestCase(
            description: "all lowercase",
            name: "upper",
            args: [.string("aaaa")],
            expected: .success(.string("AAAA"))
        ),
        BuiltinTests.TestCase(
            description: "all uppercase",
            name: "upper",
            args: [.string("AAAA")],
            expected: .success(.string("AAAA"))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "upper",
            args: [.string("hello, world!"), .string("world")],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 2, expected: 1))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "upper",
            args: [],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 0, expected: 1))
        ),
        BuiltinTests.TestCase(
            description: "wrong type arg",
            name: "upper",
            args: [.number(1)],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "x"))
        ),
    ]

    static var allTests: [BuiltinTests.TestCase] {
        [
            concatTests,
            containsTests,
            endsWithTests,
            indexOfTests,
            lowerTests,
        ].flatMap { $0 }
    }

    @Test(arguments: allTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await BuiltinTests.testBuiltin(tc: tc)
    }
}
