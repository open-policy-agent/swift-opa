import AST
import Foundation
import Testing

@testable import Rego

extension BuiltinTests {
    @Suite("BuiltinTests - Strings", .tags(.builtins))
    struct StringsTests {}
}

extension BuiltinTests.StringsTests {
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
            expected: .failure(BuiltinError.argumentCountMismatch(got: 3, want: 2))
        ),
        BuiltinTests.TestCase(
            description: "too few args 1",
            name: "array.concat",
            args: [","],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 1, want: 2))
        ),
        BuiltinTests.TestCase(
            description: "too few args 2",
            name: "array.concat",
            args: [["a"]],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 1, want: 2))
        ),
        BuiltinTests.TestCase(
            description: "wrong delineator type",
            name: "concat",
            args: [123, ["a", "b", "c"]],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "delimiter", got: "number", want: "string"))
        ),
        BuiltinTests.TestCase(
            description: "wrong collection type",
            name: "concat",
            args: [",", .object(["not an array or set": "but still a swift Collection"])],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "collection", got: "object", want: "array|set"))
        ),
        BuiltinTests.TestCase(
            description: "wrong collection element type in array",
            name: "concat",
            args: [",", ["a", 123, "c"]],
            expected: .failure(
                BuiltinError.argumentTypeMismatch(arg: "collection element: number(123)", got: "number", want: "string")
            )
        ),
        BuiltinTests.TestCase(
            description: "wrong collection element type in set",
            name: "concat",
            args: [",", .set(["a", 123, "c"])],
            expected: .failure(
                BuiltinError.argumentTypeMismatch(arg: "collection element: number(123)", got: "number", want: "string")
            )
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
            expected: .failure(BuiltinError.argumentCountMismatch(got: 3, want: 2))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "contains",
            args: ["hello, world!"],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 1, want: 2))
        ),
        BuiltinTests.TestCase(
            description: "no args",
            name: "contains",
            args: [],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 0, want: 2))
        ),
        BuiltinTests.TestCase(
            description: "wrong type needle",
            name: "contains",
            args: ["hello, world!", 1],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "needle", got: "number", want: "string"))
        ),
        BuiltinTests.TestCase(
            description: "wrong type haystack",
            name: "contains",
            args: [1, "hello, world!"],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "haystack", got: "number", want: "string"))
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
            expected: .failure(BuiltinError.argumentCountMismatch(got: 3, want: 2))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "endswith",
            args: ["hello, world!"],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 1, want: 2))
        ),
        BuiltinTests.TestCase(
            description: "no args",
            name: "endswith",
            args: [],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 0, want: 2))
        ),
        BuiltinTests.TestCase(
            description: "wrong type base",
            name: "endswith",
            args: ["hello, world!", 1],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "base", got: "number", want: "string"))
        ),
        BuiltinTests.TestCase(
            description: "wrong type search",
            name: "endswith",
            args: [1, "hello, world!"],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "search", got: "number", want: "string"))
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
            expected: .failure(BuiltinError.evalError(msg: "empty search character"))
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
            expected: .failure(BuiltinError.evalError(msg: "empty search character"))
        ),
        BuiltinTests.TestCase(
            description: "too many args",
            name: "indexof",
            args: ["hello, world!", "world", "extra"],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 3, want: 2))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "indexof",
            args: ["hello, world!"],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 1, want: 2))
        ),
        BuiltinTests.TestCase(
            description: "no args",
            name: "indexof",
            args: [],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 0, want: 2))
        ),
        BuiltinTests.TestCase(
            description: "wrong type needle",
            name: "indexof",
            args: ["hello, world!", 1],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "needle", got: "number", want: "string"))
        ),
        BuiltinTests.TestCase(
            description: "wrong type haystack",
            name: "indexof",
            args: [1, "hello, world!"],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "haystack", got: "number", want: "string"))
        ),
    ]

    static let indexOfNTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "base case positive",
            name: "indexof_n",
            args: ["hello, world world worldy-world! ", "world"],
            expected: .success([7, 13, 19, 26])
        ),
        BuiltinTests.TestCase(
            description: "base case negative",
            name: "indexof_n",
            args: ["hello, world!", "zzzzz"],
            expected: .success([])
        ),
        BuiltinTests.TestCase(
            description: "empty needle",
            name: "indexof_n",
            args: ["hello, world!", ""],
            expected: .failure(BuiltinError.evalError(msg: "empty search character"))
        ),
        BuiltinTests.TestCase(
            description: "full match",
            name: "indexof_n",
            args: ["abc", "abc"],
            expected: .success([0])
        ),
        BuiltinTests.TestCase(
            description: "more than a full match",
            name: "indexof_n",
            args: ["bc", "abcd"],
            expected: .success([])
        ),
        BuiltinTests.TestCase(
            description: "empty haystack",
            name: "indexof_n",
            args: ["", "abc"],
            expected: .success([])
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
            expected: .failure(BuiltinError.argumentCountMismatch(got: 2, want: 1))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "lower",
            args: [],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 0, want: 1))
        ),
        BuiltinTests.TestCase(
            description: "wrong type arg",
            name: "lower",
            args: [1],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "x", got: "number", want: "string"))
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
            description: "wrong type args",
            name: "sprintf",
            args: ["hello, world!", "world"],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "values", got: "string", want: "array"))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "sprintf",
            args: ["%s"],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 1, want: 2))
        ),
        BuiltinTests.TestCase(
            description: "wrong type arg 1",
            name: "sprintf",
            args: [["%s"], ["world!"]],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "format", got: "array", want: "string"))
        ),
        BuiltinTests.TestCase(
            description: "wrong type arg 2",
            name: "sprintf",
            args: ["hello, %s", "world!"],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "values", got: "string", want: "array"))
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

    static let trimLeftTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "cuts leading characters but not suffix",
            name: "trim_left",
            args: ["{}{}{}{}{}{}{!#}lorem ipsum{!#}", "{!#}"],
            expected: .success("lorem ipsum{!#}")
        ),
        BuiltinTests.TestCase(
            description: "cutset empty",
            name: "trim_left",
            args: ["lorem ipsum", ""],
            expected: .success("lorem ipsum")
        ),
        BuiltinTests.TestCase(
            description: "cuts whole string",
            name: "trim_left",
            args: ["{!#}{!#}!#", "{!#}"],
            expected: .success("")
        ),
        BuiltinTests.TestCase(
            description: "cutset doesn't match",
            name: "trim_left",
            args: ["lorem ipsum", "X"],
            expected: .success("lorem ipsum")
        ),
        BuiltinTests.TestCase(
            description: "value empty",
            name: "trim_left",
            args: ["", "f"],
            expected: .success("")
        ),
    ]

    static let trimRightTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "cuts trailing characters but not prefix",
            name: "trim_right",
            args: ["{!#}lorem ipsum{!#}!#", "{!#}"],
            expected: .success("{!#}lorem ipsum")
        ),
        BuiltinTests.TestCase(
            description: "cuts whole string",
            name: "trim_right",
            args: ["{!#}{!#}!#", "{!#}"],
            expected: .success("")
        ),
        BuiltinTests.TestCase(
            description: "cutset doesn't match",
            name: "trim_right",
            args: ["lorem ipsum", "X"],
            expected: .success("lorem ipsum")
        ),
        BuiltinTests.TestCase(
            description: "cutset empty",
            name: "trim_right",
            args: ["lorem ipsum", ""],
            expected: .success("lorem ipsum")
        ),
        BuiltinTests.TestCase(
            description: "value empty",
            name: "trim_right",
            args: ["", "f"],
            expected: .success("")
        ),
    ]

    static let trimPrefixTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "cuts leading prefix",
            name: "trim_prefix",
            args: ["foolorem ipsum", "foo"],
            expected: .success("lorem ipsum")
        ),
        BuiltinTests.TestCase(
            description: "prefix empty",
            name: "trim_prefix",
            args: ["lorem ipsum", ""],
            expected: .success("lorem ipsum")
        ),
        BuiltinTests.TestCase(
            description: "value does not start with prefix",
            name: "trim_prefix",
            args: ["lorem ipsum", "bar"],
            expected: .success("lorem ipsum")
        ),
        BuiltinTests.TestCase(
            description: "value empty",
            name: "trim_prefix",
            args: ["", "f"],
            expected: .success("")
        ),
    ]

    static let trimSpaceTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "removes spaces, tabs, carriage returns",
            name: "trim_space",
            args: ["    \t\t\t lorem ipsum\t\t        \r"],
            expected: .success("lorem ipsum")
        ),
        BuiltinTests.TestCase(
            description: "does not modify strings without whitespaces",
            name: "trim_space",
            args: ["loremipsum"],
            expected: .success("loremipsum")
        ),
        BuiltinTests.TestCase(
            description: "does not remove inner whitespace",
            name: "trim_space",
            args: ["lorem \t\t ipsum"],
            expected: .success("lorem \t\t ipsum")
        ),
    ]

    static let trimSuffixTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "cuts trailing suffix",
            name: "trim_suffix",
            args: ["lorem ipsumfoo", "foo"],
            expected: .success("lorem ipsum")
        ),
        BuiltinTests.TestCase(
            description: "suffix empty",
            name: "trim_suffix",
            args: ["lorem ipsum", ""],
            expected: .success("lorem ipsum")
        ),
        BuiltinTests.TestCase(
            description: "value does not end with suffix",
            name: "trim_suffix",
            args: ["lorem ipsum", "bar"],
            expected: .success("lorem ipsum")
        ),
        BuiltinTests.TestCase(
            description: "value empty",
            name: "trim_suffix",
            args: ["", "f"],
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
            expected: .failure(BuiltinError.argumentCountMismatch(got: 2, want: 1))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "upper",
            args: [],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 0, want: 1))
        ),
        BuiltinTests.TestCase(
            description: "wrong type arg",
            name: "upper",
            args: [1],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "x", got: "number", want: "string"))
        ),
    ]

    static let startsWithTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "base case positive",
            name: "startswith",
            args: ["hello, world!", "hello"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "base case negative",
            name: "startswith",
            args: ["hello, world!", "world!"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "empty base",
            name: "startswith",
            args: ["hello, world!", ""],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "full match",
            name: "startswith",
            args: ["abc", "abc"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "more than a full match",
            name: "startswith",
            args: ["bc", "abcd"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "empty search",
            name: "startswith",
            args: ["", "abc"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "both empty",
            name: "startswith",
            args: ["", ""],
            expected: .success(true)
        ),
    ]

    static let formatIntTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "integer base 10",
            name: "format_int",
            args: [123, 10],
            expected: .success("123")
        ),
        BuiltinTests.TestCase(
            description: "integer base 16",
            name: "format_int",
            args: [123, 16],
            expected: .success("7b")
        ),
        BuiltinTests.TestCase(
            description: "integer base 8",
            name: "format_int",
            args: [123, 8],
            expected: .success("173")
        ),
        BuiltinTests.TestCase(
            description: "integer base 2",
            name: "format_int",
            args: [123, 2],
            expected: .success("1111011")
        ),
        BuiltinTests.TestCase(
            description: "unsupported base",
            name: "format_int",
            args: [123, 7],
            expected: .failure(BuiltinError.evalError(msg: "operand 2 must be one of {2, 8, 10, 16}"))
        ),
        BuiltinTests.TestCase(
            description: "negative base",
            name: "format_int",
            args: [123, -2],
            expected: .failure(BuiltinError.evalError(msg: "operand 2 must be one of {2, 8, 10, 16}"))
        ),
        BuiltinTests.TestCase(
            description: "float base",
            name: "format_int",
            args: [123, 10.1],
            expected: .failure(BuiltinError.evalError(msg: "operand 2 must be one of {2, 8, 10, 16}"))
        ),
        BuiltinTests.TestCase(
            description: "float base with integer value",
            name: "format_int",
            args: [123, 10.0],
            expected: .failure(BuiltinError.evalError(msg: "operand 2 must be one of {2, 8, 10, 16}"))
        ),
        BuiltinTests.TestCase(
            description: "float base 10 uses floor",
            name: "format_int",
            args: [123.9, 10],
            expected: .success("123")
        ),
        BuiltinTests.TestCase(
            description: "float base 16 uses floor",
            name: "format_int",
            args: [123.9, 16],
            expected: .success("7b")
        ),
        BuiltinTests.TestCase(
            description: "float base 8 uses floor",
            name: "format_int",
            args: [123.9, 8],
            expected: .success("173")
        ),
        BuiltinTests.TestCase(
            description: "float base 2 uses floor",
            name: "format_int",
            args: [123.9, 2],
            expected: .success("1111011")
        ),
        BuiltinTests.TestCase(
            description: "negative float base 10 uses floor",
            name: "format_int",
            args: [-122.1, 10],
            expected: .success("-123")
        ),
        BuiltinTests.TestCase(
            description: "negative float base 16 uses floor",
            name: "format_int",
            args: [-122.1, 16],
            expected: .success("-7b")
        ),
        BuiltinTests.TestCase(
            description: "negative float base 8 uses floor",
            name: "format_int",
            args: [-122.1, 8],
            expected: .success("-173")
        ),
        BuiltinTests.TestCase(
            description: "negative float base 2 uses floor",
            name: "format_int",
            args: [-122.1, 2],
            expected: .success("-1111011")
        ),
    ]

    static let replaceTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "base case positive",
            name: "replace",
            args: ["hello, world world worldy-world!", "world", "universe"],
            expected: .success("hello, universe universe universey-universe!")
        ),
        BuiltinTests.TestCase(
            description: "base case negative",
            name: "replace",
            args: ["hello, world world worldy-world!", "foo", "universe"],
            expected: .success("hello, world world worldy-world!")
        ),
        BuiltinTests.TestCase(
            description: "empty search string",
            name: "replace",
            args: ["", "foo", "bar"],
            expected: .success("")
        ),
        BuiltinTests.TestCase(
            description: "empty old string",
            name: "replace",
            args: ["foo", "", "bar"],
            expected: .success("foo")
        ),
        BuiltinTests.TestCase(
            description: "empty new string",
            name: "replace",
            args: ["foo", "o", ""],
            expected: .success("f")
        ),
    ]

    static let reverseTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "reverses a string",
            name: "strings.reverse",
            args: ["abcdefg"],
            expected: .success("gfedcba")
        ),
        BuiltinTests.TestCase(
            description: "reverses empty string",
            name: "strings.reverse",
            args: [""],
            expected: .success("")
        ),
    ]

    static let substringTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "negative offset",
            name: "substring",
            args: ["abcdefgh", -1, 3],
            expected: .failure(BuiltinError.evalError(msg: "negative offset"))
        ),
        BuiltinTests.TestCase(
            description: "float offset",
            name: "substring",
            args: ["abcdefgh", 0.1, 3],
            expected: .failure(
                BuiltinError.evalError(
                    msg: "operand 2 must be integer number but got floating-point number"))
        ),
        BuiltinTests.TestCase(
            description: "float offset with integer value",
            name: "substring",
            args: ["abcdefgh", 0.0, 3],
            expected: .failure(
                BuiltinError.evalError(
                    msg: "operand 2 must be integer number but got floating-point number"))
        ),
        BuiltinTests.TestCase(
            description: "float length",
            name: "substring",
            args: ["abcdefgh", 0, 3.3],
            expected: .failure(
                BuiltinError.evalError(
                    msg: "operand 3 must be integer number but got floating-point number"))
        ),
        BuiltinTests.TestCase(
            description: "float length with integer value",
            name: "substring",
            args: ["abcdefgh", 0, 3.0],
            expected: .failure(
                BuiltinError.evalError(
                    msg: "operand 3 must be integer number but got floating-point number"))
        ),
        BuiltinTests.TestCase(
            description: "returns correct substring",
            name: "substring",
            args: ["abcdefgh", 2, 4],
            expected: .success("cdef")
        ),
        BuiltinTests.TestCase(
            description: "negative length returns remainder of the string",
            name: "substring",
            args: ["abcdefgh", 2, -1],
            expected: .success("cdefgh")
        ),
        BuiltinTests.TestCase(
            description: "long length returns remainder of the string",
            name: "substring",
            args: ["abcdefgh", 2, 100],
            expected: .success("cdefgh")
        ),
        BuiltinTests.TestCase(
            description: "offset + length = len(string) returns remainder of the string",
            name: "substring",
            args: ["abcdefgh", 2, 6],
            expected: .success("cdefgh")
        ),
        BuiltinTests.TestCase(
            description: "zero length returns empty string",
            name: "substring",
            args: ["abcdefgh", 2, 0],
            expected: .success("")
        ),
        BuiltinTests.TestCase(
            description: "offset beyond string length returns empty string",
            name: "substring",
            args: ["abcdefgh", 9, 1],
            expected: .success("")
        ),
        BuiltinTests.TestCase(
            description: "offset equal to string length returns empty string",
            name: "substring",
            args: ["abcdefgh", 8, 1],
            expected: .success("")
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

            BuiltinTests.generateFailureTests(
                builtinName: "startswith", sampleArgs: ["a", "b"], argIndex: 0, argName: "search",
                allowedArgTypes: ["string"], generateNumberOfArgsTest: true),
            BuiltinTests.generateFailureTests(
                builtinName: "startswith", sampleArgs: ["a", "b"], argIndex: 1, argName: "base",
                allowedArgTypes: ["string"], generateNumberOfArgsTest: false),
            startsWithTests,

            BuiltinTests.generateFailureTests(
                builtinName: "format_int", sampleArgs: [123, 10], argIndex: 0, argName: "number",
                allowedArgTypes: ["number"], generateNumberOfArgsTest: true),
            BuiltinTests.generateFailureTests(
                builtinName: "format_int", sampleArgs: [123, 10], argIndex: 1, argName: "base",
                allowedArgTypes: ["number"], generateNumberOfArgsTest: false),
            formatIntTests,

            BuiltinTests.generateFailureTests(
                builtinName: "indexof_n", sampleArgs: ["haystack", "needle"], argIndex: 0, argName: "haystack",
                allowedArgTypes: ["string"], generateNumberOfArgsTest: true),
            BuiltinTests.generateFailureTests(
                builtinName: "indexof_n", sampleArgs: ["haystack", "needle"], argIndex: 1, argName: "needle",
                allowedArgTypes: ["string"], generateNumberOfArgsTest: false),
            indexOfNTests,

            BuiltinTests.generateFailureTests(
                builtinName: "replace", sampleArgs: ["s", "old", "new"], argIndex: 0, argName: "x",
                allowedArgTypes: ["string"], generateNumberOfArgsTest: true),
            BuiltinTests.generateFailureTests(
                builtinName: "replace", sampleArgs: ["s", "old", "new"], argIndex: 1, argName: "old",
                allowedArgTypes: ["string"], generateNumberOfArgsTest: false),
            BuiltinTests.generateFailureTests(
                builtinName: "replace", sampleArgs: ["s", "old", "new"], argIndex: 2, argName: "new",
                allowedArgTypes: ["string"], generateNumberOfArgsTest: false),
            replaceTests,

            BuiltinTests.generateFailureTests(
                builtinName: "strings.reverse", sampleArgs: ["value"], argIndex: 0, argName: "value",
                allowedArgTypes: ["string"], generateNumberOfArgsTest: true),
            reverseTests,

            BuiltinTests.generateFailureTests(
                builtinName: "trim_left", sampleArgs: ["value", "cutset"], argIndex: 0, argName: "value",
                allowedArgTypes: ["string"], generateNumberOfArgsTest: true),
            BuiltinTests.generateFailureTests(
                builtinName: "trim_left", sampleArgs: ["value", "cutset"], argIndex: 1, argName: "cutset",
                allowedArgTypes: ["string"], generateNumberOfArgsTest: false),
            trimLeftTests,

            BuiltinTests.generateFailureTests(
                builtinName: "trim_prefix", sampleArgs: ["value", "prefix"], argIndex: 0, argName: "value",
                allowedArgTypes: ["string"], generateNumberOfArgsTest: true),
            BuiltinTests.generateFailureTests(
                builtinName: "trim_prefix", sampleArgs: ["value", "prefix"], argIndex: 1, argName: "prefix",
                allowedArgTypes: ["string"], generateNumberOfArgsTest: false),
            trimPrefixTests,

            BuiltinTests.generateFailureTests(
                builtinName: "trim_right", sampleArgs: ["value", "prefix"], argIndex: 0, argName: "value",
                allowedArgTypes: ["string"], generateNumberOfArgsTest: true),
            BuiltinTests.generateFailureTests(
                builtinName: "trim_right", sampleArgs: ["value", "prefix"], argIndex: 1, argName: "cutset",
                allowedArgTypes: ["string"], generateNumberOfArgsTest: false),
            trimRightTests,

            BuiltinTests.generateFailureTests(
                builtinName: "trim_space", sampleArgs: ["value"], argIndex: 0, argName: "value",
                allowedArgTypes: ["string"], generateNumberOfArgsTest: true),
            trimSpaceTests,

            BuiltinTests.generateFailureTests(
                builtinName: "trim_suffix", sampleArgs: ["value", "suffix"], argIndex: 0, argName: "value",
                allowedArgTypes: ["string"], generateNumberOfArgsTest: true),
            BuiltinTests.generateFailureTests(
                builtinName: "trim_suffix", sampleArgs: ["value", "suffix"], argIndex: 1, argName: "suffix",
                allowedArgTypes: ["string"], generateNumberOfArgsTest: false),
            trimSuffixTests,

            BuiltinTests.generateFailureTests(
                builtinName: "substring", sampleArgs: ["value", 1, 2], argIndex: 0, argName: "value",
                allowedArgTypes: ["string"], generateNumberOfArgsTest: true),
            BuiltinTests.generateFailureTests(
                builtinName: "substring", sampleArgs: ["value", 1, 2], argIndex: 1, argName: "offset",
                allowedArgTypes: ["number"], generateNumberOfArgsTest: false),
            BuiltinTests.generateFailureTests(
                builtinName: "substring", sampleArgs: ["value", 1, 2], argIndex: 2, argName: "length",
                allowedArgTypes: ["number"], generateNumberOfArgsTest: false),
            substringTests,
        ].flatMap { $0 }
    }

    @Test(arguments: allTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await BuiltinTests.testBuiltin(tc: tc)
    }
}
