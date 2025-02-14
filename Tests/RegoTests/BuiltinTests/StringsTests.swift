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
            args: [",", ["a", "b", "c"]],
            expected: .success("a,b,c")
        ),
        BuiltinTests.TestCase(
            description: "empty array csv",
            name: "concat",
            args: [",", []],
            expected: .success("")
        ),
        BuiltinTests.TestCase(
            description: "array multi character separator",
            name: "concat",
            args: [
                "a really big delineator compared to the usual comma",
                ["a", "b", "c"],
            ],
            expected: .success(
                .string(
                    "aa really big delineator compared to the usual commaba really big delineator compared to the usual commac"
                ))
        ),
        BuiltinTests.TestCase(
            description: "simple set csv",
            name: "concat",
            args: [",", .set(["a", "b", "c"])],
            expected: .success("a,b,c")
        ),
        BuiltinTests.TestCase(
            description: "empty set csv",
            name: "concat",
            args: [",", .set([])],
            expected: .success("")
        ),
        BuiltinTests.TestCase(
            description: "set multi character separator",
            name: "concat",
            args: [
                "a really big delineator compared to the usual comma",
                .set(["a", "b", "c"]),
            ],
            expected: .success(
                .string(
                    "aa really big delineator compared to the usual commaba really big delineator compared to the usual commac"
                ))
        ),
        BuiltinTests.TestCase(
            description: "empty delineator",
            name: "concat",
            args: ["", ["a", "b", "c"]],
            expected: .success("abc")
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "array.concat",
            args: [1, 1, 1],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 3, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "too few args 1",
            name: "array.concat",
            args: [","],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 1, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "too few args 2",
            name: "array.concat",
            args: [["a"]],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 1, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "wrong delineator type",
            name: "concat",
            args: [123, ["a", "b", "c"]],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "delineator"))
        ),
        BuiltinTests.TestCase(
            description: "wrong collection type",
            name: "concat",
            args: [",", .object(["not an array or set": "but still a swift Collection"])],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "collection"))
        ),
        BuiltinTests.TestCase(
            description: "wrong collection element type in array",
            name: "concat",
            args: [",", ["a", 123, "c"]],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "collection element 123"))
        ),
        BuiltinTests.TestCase(
            description: "wrong collection element type in set",
            name: "concat",
            args: [",", .set(["a", 123, "c"])],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "collection element 123"))
        ),
    ]

    static let containsTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "base case positive",
            name: "contains",
            args: ["hello, world!", "world"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "base case negative",
            name: "contains",
            args: ["hello, world!", "zzzzz"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "empty needle",
            name: "contains",
            args: ["hello, world!", ""],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "full match",
            name: "contains",
            args: ["abc", "abc"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "more than a full match",
            name: "contains",
            args: ["bc", "abcd"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "empty haystack",
            name: "contains",
            args: ["", "abc"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "both empty",
            name: "contains",
            args: ["", ""],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "contains",
            args: ["hello, world!", "world", "extra"],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 3, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "contains",
            args: ["hello, world!"],
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
            args: ["hello, world!", 1],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "needle"))
        ),
        BuiltinTests.TestCase(
            description: "wrong type haystack",
            name: "contains",
            args: [1, "hello, world!"],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "needle"))
        ),
    ]

    static let endsWithTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "base case positive",
            name: "endswith",
            args: ["hello, world!", "world!"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "base case negative",
            name: "endswith",
            args: ["hello, world!", "zzzzz"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "empty base",
            name: "endswith",
            args: ["hello, world!", ""],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "full match",
            name: "endswith",
            args: ["abc", "abc"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "more than a full match",
            name: "endswith",
            args: ["bc", "abcd"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "empty search",
            name: "endswith",
            args: ["", "abc"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "both empty",
            name: "endswith",
            args: ["", ""],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "endswith",
            args: ["hello, world!", "world!", "extra"],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 3, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "endswith",
            args: ["hello, world!"],
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
            args: ["hello, world!", 1],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "search"))
        ),
        BuiltinTests.TestCase(
            description: "wrong type base",
            name: "endswith",
            args: [1, "hello, world!"],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "base"))
        ),
    ]

    static let indexOfTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "base case positive",
            name: "indexof",
            args: ["hello, world!", "world"],
            expected: .success(7)
        ),
        BuiltinTests.TestCase(
            description: "base case negative",
            name: "indexof",
            args: ["hello, world!", "zzzzz"],
            expected: .success(-1)
        ),
        BuiltinTests.TestCase(
            description: "empty needle",
            name: "indexof",
            args: ["hello, world!", ""],
            expected: .success(.undefined)
        ),
        BuiltinTests.TestCase(
            description: "full match",
            name: "indexof",
            args: ["abc", "abc"],
            expected: .success(0)
        ),
        BuiltinTests.TestCase(
            description: "more than a full match",
            name: "indexof",
            args: ["bc", "abcd"],
            expected: .success(-1)
        ),
        BuiltinTests.TestCase(
            description: "empty haystack",
            name: "indexof",
            args: ["", "abc"],
            expected: .success(-1)
        ),
        BuiltinTests.TestCase(
            description: "both empty",
            name: "indexof",
            args: ["", ""],
            expected: .success(.undefined)
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "indexof",
            args: ["hello, world!", "world", "extra"],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 3, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "indexof",
            args: ["hello, world!"],
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
            args: ["hello, world!", 1],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "needle"))
        ),
        BuiltinTests.TestCase(
            description: "wrong type haystack",
            name: "indexof",
            args: [1, "hello, world!"],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "needle"))
        ),
    ]

    static let lowerTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "base",
            name: "lower",
            args: ["aAaAAaaAAAA A A a"],
            expected: .success("aaaaaaaaaaa a a a")
        ),
        BuiltinTests.TestCase(
            description: "empty string",
            name: "lower",
            args: [""],
            expected: .success("")
        ),
        BuiltinTests.TestCase(
            description: "all lowercase",
            name: "lower",
            args: ["aaaa"],
            expected: .success("aaaa")
        ),
        BuiltinTests.TestCase(
            description: "all uppercase",
            name: "lower",
            args: ["AAAA"],
            expected: .success("aaaa")
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "lower",
            args: ["hello, world!", "world"],
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
            args: [1],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "x"))
        ),
    ]

    static let splitTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "base",
            name: "split",
            args: ["foo/bar/baz", "/"],
            expected: .success(["foo", "bar", "baz"])
        ),
        BuiltinTests.TestCase(
            description: "delimiter not found",
            name: "split",
            args: ["aaaa", "b"],
            expected: .success(["aaaa"])
        ),
        BuiltinTests.TestCase(
            description: "empty delimiter, split after each character",
            name: "split",
            args: ["aaaa", ""],
            expected: .success(["a", "a", "a", "a"])
        ),
        BuiltinTests.TestCase(
            description: "both empty",
            name: "split",
            args: ["", ""],
            expected: .success([])
        ),
        BuiltinTests.TestCase(
            description: "empty string",
            name: "split",
            args: ["", "/"],
            expected: .success([""])
        ),
        BuiltinTests.TestCase(
            description: "prefix and then empty splits",
            name: "split",
            args: ["baaa", "a"],
            expected: .success(["b", "", "", ""])
        ),
        BuiltinTests.TestCase(
            description: "aaaa->aaa",
            name: "split",
            args: ["aaaa", "aaa"],
            expected: .success(["", "a"])
        ),
        BuiltinTests.TestCase(
            description: "aaaa->aa",
            name: "split",
            args: ["aaaa", "aa"],
            expected: .success(["", "", ""])
        ),
    ]

    static let sprintfBasicTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "base",
            name: "sprintf",
            args: ["hello, %s", ["world!"]],
            expected: .success("hello, world!")
        ),
        BuiltinTests.TestCase(
            description: "no format args",
            name: "sprintf",
            args: ["hello, world!", []],
            expected: .success("hello, world!")
        ),
        BuiltinTests.TestCase(
            description: "multiple args",
            name: "sprintf",
            args: ["%v, %v%s", ["hello", "world", "!"]],
            expected: .success("hello, world!")
        ),
        BuiltinTests.TestCase(
            description: "multiple args with indexes",
            name: "sprintf",
            args: ["%[2]v %[1]v %v %[1]v %[2]v %v %[3]v %[9]v", [1, 2, 3]],
            expected: .success("2 1 2 1 2 3 3 %!v(BADINDEX)")
        ),
        BuiltinTests.TestCase(
            description: "json encoded for complex types",
            name: "sprintf",
            args: ["%v", [["hello": "world", "nested": ["obj": "val"]]]],
            expected: .success("{\"hello\":\"world\",\"nested\":{\"obj\":\"val\"}}")
        ),
        BuiltinTests.TestCase(
            description: "int",
            name: "sprintf",
            args: ["hello, int %d", [123]],
            expected: .success("hello, int 123")
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "sprintf",
            args: ["hello, world!", "world"],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 2, expected: 1))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "sprintf",
            args: ["%s"],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 1, expected: 2))
        ),
        BuiltinTests.TestCase(
            description: "wrong type arg 1",
            name: "sprintf",
            args: [["%s"], ["world!"]],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "format"))
        ),
        BuiltinTests.TestCase(
            description: "wrong type arg 2",
            name: "sprintf",
            args: ["hello, %s", "world!"],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "values"))
        ),
    ]

    static let trimTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "base",
            name: "trim",
            args: ["    lorem ipsum        ", "     "],
            expected: .success("lorem ipsum")
        ),
        BuiltinTests.TestCase(
            description: "cutset empty",
            name: "trim",
            args: ["    lorem ipsum    ", ""],
            expected: .success("    lorem ipsum    ")
        ),
        BuiltinTests.TestCase(
            description: "non-whitespace",
            name: "trim",
            args: ["01234number 1!43210", "0123456789"],
            expected: .success("number 1!")
        ),
        BuiltinTests.TestCase(
            description: "value empty",
            name: "trim",
            args: ["", "0123456789"],
            expected: .success("")
        ),
    ]

    static let upperTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "base",
            name: "upper",
            args: ["aAaAAaaAAAA A A a"],
            expected: .success("AAAAAAAAAAA A A A")
        ),
        BuiltinTests.TestCase(
            description: "empty string",
            name: "upper",
            args: [""],
            expected: .success("")
        ),
        BuiltinTests.TestCase(
            description: "all lowercase",
            name: "upper",
            args: ["aaaa"],
            expected: .success("AAAA")
        ),
        BuiltinTests.TestCase(
            description: "all uppercase",
            name: "upper",
            args: ["AAAA"],
            expected: .success("AAAA")
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "upper",
            args: ["hello, world!", "world"],
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
            args: [1],
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
            splitTests,
            sprintfBasicTests,
            trimTests,
            upperTests,
        ].flatMap { $0 }
    }

    @Test(arguments: allTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await BuiltinTests.testBuiltin(tc: tc)
    }
}
