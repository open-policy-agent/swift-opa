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
        BuiltinTests.TestCase(
            description: "multi-byte UTF-8 emoji",
            name: "contains",
            args: ["hello \u{1F600} world", "\u{1F600}"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "multi-byte UTF-8 CJK",
            name: "contains",
            args: ["\u{4F60}\u{597D}\u{4E16}\u{754C}", "\u{4E16}\u{754C}"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "single character needle found",
            name: "contains",
            args: ["abcdef", "d"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "single character needle not found",
            name: "contains",
            args: ["abcdef", "z"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "needle at start",
            name: "contains",
            args: ["hello world", "hello"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "needle at end",
            name: "contains",
            args: ["hello world", "world"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "repeated pattern finds first",
            name: "contains",
            args: ["abcabcabc", "cab"],
            expected: .success(true)
        ),
        // Unicode normalization: precomposed é (U+00E9) vs decomposed e + combining accent (U+0301).
        // Go does byte-level comparison with no normalization, so these must NOT match.
        BuiltinTests.TestCase(
            description: "normalization mismatch: precomposed haystack, decomposed needle",
            name: "contains",
            args: ["caf\u{00E9}", "e\u{0301}"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "normalization mismatch: decomposed haystack, precomposed needle",
            name: "contains",
            args: ["cafe\u{0301}", "\u{00E9}"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "precomposed accent matches same bytes",
            name: "contains",
            args: ["caf\u{00E9}", "\u{00E9}"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "decomposed accent matches same bytes",
            name: "contains",
            args: ["cafe\u{0301}", "e\u{0301}"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "emoji not found",
            name: "contains",
            args: ["hello world", "\u{1F600}"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "case sensitive mismatch",
            name: "contains",
            args: ["Hello World", "hello"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "multi-byte needle longer than haystack",
            name: "contains",
            args: ["\u{1F600}", "\u{1F600}\u{1F601}"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "haystack is needle repeated",
            name: "contains",
            args: ["aaa", "a"],
            expected: .success(true)
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
        BuiltinTests.TestCase(
            description: "multi-byte UTF-8 emoji suffix",
            name: "endswith",
            args: ["hello \u{1F600}", "\u{1F600}"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "multi-byte UTF-8 emoji suffix not found",
            name: "endswith",
            args: ["hello \u{1F600}", "\u{1F601}"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "multi-byte UTF-8 CJK suffix",
            name: "endswith",
            args: ["\u{4F60}\u{597D}\u{4E16}\u{754C}", "\u{4E16}\u{754C}"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "multi-byte UTF-8 CJK suffix not found",
            name: "endswith",
            args: ["\u{4F60}\u{597D}\u{4E16}\u{754C}", "\u{4E16}\u{754C}\u{FF01}"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "single character suffix found",
            name: "endswith",
            args: ["abcdef", "f"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "single character suffix not found",
            name: "endswith",
            args: ["abcdef", "a"],
            expected: .success(false)
        ),
        // Unicode normalization: precomposed é (U+00E9) vs decomposed e + combining accent (U+0301).
        // Go does byte-level comparison with no normalization, so these must NOT match.
        BuiltinTests.TestCase(
            description: "normalization mismatch: precomposed search, decomposed base",
            name: "endswith",
            args: ["caf\u{00E9}", "e\u{0301}"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "normalization mismatch: decomposed search, precomposed base",
            name: "endswith",
            args: ["cafe\u{0301}", "\u{00E9}"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "precomposed accent matches same bytes",
            name: "endswith",
            args: ["caf\u{00E9}", "f\u{00E9}"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "decomposed accent matches same bytes",
            name: "endswith",
            args: ["cafe\u{0301}", "e\u{0301}"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "case sensitive suffix mismatch",
            name: "endswith",
            args: ["Hello World", "WORLD"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "suffix is entire string with emoji",
            name: "endswith",
            args: ["\u{1F600}\u{1F601}", "\u{1F600}\u{1F601}"],
            expected: .success(true)
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
        BuiltinTests.TestCase(
            description: "too many args",
            name: "startswith",
            args: ["hello, world!", "hello", "extra"],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 3, want: 2))
        ),
        BuiltinTests.TestCase(
            description: "not enough args",
            name: "startswith",
            args: ["hello, world!"],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 1, want: 2))
        ),
        BuiltinTests.TestCase(
            description: "no args",
            name: "startswith",
            args: [],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 0, want: 2))
        ),
        BuiltinTests.TestCase(
            description: "wrong type base",
            name: "startswith",
            args: ["hello, world!", 1],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "base", got: "number", want: "string"))
        ),
        BuiltinTests.TestCase(
            description: "wrong type search",
            name: "startswith",
            args: [1, "hello, world!"],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "search", got: "number", want: "string"))
        ),
        BuiltinTests.TestCase(
            description: "multi-byte UTF-8 emoji prefix",
            name: "startswith",
            args: ["\u{1F600} hello", "\u{1F600}"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "multi-byte UTF-8 emoji prefix not found",
            name: "startswith",
            args: ["\u{1F600} hello", "\u{1F601}"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "multi-byte UTF-8 CJK prefix",
            name: "startswith",
            args: ["\u{4F60}\u{597D}\u{4E16}\u{754C}", "\u{4F60}\u{597D}"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "multi-byte UTF-8 CJK prefix not found",
            name: "startswith",
            args: ["\u{4F60}\u{597D}\u{4E16}\u{754C}", "\u{4E16}\u{754C}"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "single character prefix found",
            name: "startswith",
            args: ["abcdef", "a"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "single character prefix not found",
            name: "startswith",
            args: ["abcdef", "z"],
            expected: .success(false)
        ),
        // Unicode normalization: precomposed é (U+00E9) vs decomposed e + combining accent (U+0301).
        // Go does byte-level comparison with no normalization, so these must NOT match.
        BuiltinTests.TestCase(
            description: "normalization mismatch: precomposed search, decomposed base",
            name: "startswith",
            args: ["\u{00E9}lan", "e\u{0301}"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "normalization mismatch: decomposed search, precomposed base",
            name: "startswith",
            args: ["e\u{0301}lan", "\u{00E9}"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "precomposed accent matches same bytes",
            name: "startswith",
            args: ["\u{00E9}lan", "\u{00E9}"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "decomposed accent matches same bytes",
            name: "startswith",
            args: ["e\u{0301}lan", "e\u{0301}"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "case sensitive prefix mismatch",
            name: "startswith",
            args: ["Hello World", "hello"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "prefix is entire string with emoji",
            name: "startswith",
            args: ["\u{1F600}\u{1F601}", "\u{1F600}\u{1F601}"],
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

    static let interpolationTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "empty",
            name: "internal.template_string",
            args: [.array([])],
            expected: .success("")
        ),
        BuiltinTests.TestCase(
            description: "undefined optional",
            name: "internal.template_string",
            args: [.array([.set([])])],
            expected: .success("<undefined>")
        ),
        BuiltinTests.TestCase(
            description: "primitives",
            name: "internal.template_string",
            args: [.array(["foo ", 42, " ", 4.2, " ", false, " ", .null])],
            expected: .success("foo 42 4.2 false null")
        ),
        BuiltinTests.TestCase(
            description: "primitives, optional",
            name: "internal.template_string",
            args: [.array([.set(["foo"]), " ", .set([42]), " ", .set([4.2]), " ", .set([false]), " ", .set([.null])])],
            expected: .success("foo 42 4.2 false null")
        ),
        BuiltinTests.TestCase(
            description: "collections, optional",
            name: "internal.template_string",
            args: [
                .array([
                    .set([.array([])]), " ",
                    .set([.array(["a", "b"])]), " ",
                    .set([.set([])]), " ",
                    .set([.set(["c"])]), " ",
                    .set([.set(["d", 42, 4.2, false, .null])]), " ",
                    .set([.object([:])]), " ",
                    .set([.object(["d": "e"])]), " ",
                    .set([.object(["f": "g", "h": "i"])]),
                ])
            ],
            expected: .success(
                """
                [] ["a", "b"] set() {"c"} {null, false, 4.2, 42, "d"} {} {"d": "e"} {"f": "g", "h": "i"}
                """)
        ),
        BuiltinTests.TestCase(
            description: "nested empty array",
            name: "internal.template_string",
            args: [
                .array([
                    .set([.array([.array([])])])
                ])
            ],
            expected: .success("[[]]")
        ),
        BuiltinTests.TestCase(
            description: "nested empty set",
            name: "internal.template_string",
            args: [
                .array([
                    .set([.set([.set([])])])
                ])
            ],
            expected: .success("{set()}")
        ),
        BuiltinTests.TestCase(
            description: "multiple outputs",
            name: "internal.template_string",
            args: [
                .array([
                    .set(["foo", "bar"])
                ])
            ],
            expected: .failure(
                BuiltinError.halt(
                    reason: "template-strings must not produce multiple outputs"))
        ),
        BuiltinTests.TestCase(
            description: "illegal argument type",
            name: "internal.template_string",
            args: [
                .array([
                    .array(["foo", "bar"])
                ])
            ],
            expected: .failure(
                BuiltinError.halt(
                    reason: "illegal argument type: array"))
        ),
    ]

    // MARK: - strings.count

    static let stringsCountTests: [BuiltinTests.TestCase] = [
        // Compliance: count single character
        BuiltinTests.TestCase(
            description: "count single character occurrences",
            name: "strings.count",
            args: ["cheese", "e"],
            expected: .success(3)
        ),
        // Compliance: count multi-word substring
        BuiltinTests.TestCase(
            description: "count multi-word substring",
            name: "strings.count",
            args: ["hello hello hello world", "hello"],
            expected: .success(3)
        ),
        // Compliance: no match
        BuiltinTests.TestCase(
            description: "count no match",
            name: "strings.count",
            args: ["dummy", "x"],
            expected: .success(0)
        ),
        // Compliance: empty substring returns rune count + 1 (Go semantics)
        BuiltinTests.TestCase(
            description: "empty substring returns unicode scalar count + 1",
            name: "strings.count",
            args: ["dummy", ""],
            expected: .success(6)
        ),
        // Compliance: both empty
        BuiltinTests.TestCase(
            description: "empty search with empty substring",
            name: "strings.count",
            args: ["", ""],
            expected: .success(1)
        ),
        // Compliance: empty haystack non-empty needle
        BuiltinTests.TestCase(
            description: "empty search with non-empty substring",
            name: "strings.count",
            args: ["", "x"],
            expected: .success(0)
        ),
        // Compliance: non-overlapping count
        BuiltinTests.TestCase(
            description: "non-overlapping count",
            name: "strings.count",
            args: ["11111", "11"],
            expected: .success(2)
        ),
        // Compliance: equal strings
        BuiltinTests.TestCase(
            description: "equal strings",
            name: "strings.count",
            args: ["11111", "11111"],
            expected: .success(1)
        ),
    ]

    // MARK: - strings.any_prefix_match

    static let anyPrefixMatchTests: [BuiltinTests.TestCase] = [
        // Compliance: array search, array prefixes — match
        BuiltinTests.TestCase(
            description: "array match with multiple prefixes",
            name: "strings.any_prefix_match",
            args: [["a/b/c", "a/b/d", "e/f/g"], ["a/", "d/"]],
            expected: .success(true)
        ),
        // Compliance: no match
        BuiltinTests.TestCase(
            description: "array no match",
            name: "strings.any_prefix_match",
            args: [["a/b/c", "a/b/d", "e/f/g"], ["f/", "d/"]],
            expected: .success(false)
        ),
        // Compliance: multiple overlapping prefixes
        BuiltinTests.TestCase(
            description: "multiple overlapping prefixes",
            name: "strings.any_prefix_match",
            args: [["a/b/c", "a/b/d", "e/f/g"], ["a/b/", "a/"]],
            expected: .success(true)
        ),
        // Compliance: prefix equals full string
        BuiltinTests.TestCase(
            description: "prefix equals full string",
            name: "strings.any_prefix_match",
            args: [["a/b/c", "a/b/d", "e/f/g"], ["d/", "e/f/g"]],
            expected: .success(true)
        ),
        // Compliance: partial prefix not at boundary
        BuiltinTests.TestCase(
            description: "partial prefix match on longer strings",
            name: "strings.any_prefix_match",
            args: [["aa/bb/cc", "aa/bb/dd", "ee/ff/gg"], ["aa/b", "e/f"]],
            expected: .success(true)
        ),
        // Compliance: prefix substring but not prefix of any string
        BuiltinTests.TestCase(
            description: "non-prefix substring no match",
            name: "strings.any_prefix_match",
            args: [["aa/bb/cc", "aa/bb/dd", "ee/ff/gg"], ["a/b", "e/f"]],
            expected: .success(false)
        ),
        // Compliance: middle substring is not a prefix
        BuiltinTests.TestCase(
            description: "middle substring is not a prefix",
            name: "strings.any_prefix_match",
            args: [["aa/bb/cc", "aa/bb/dd", "ee/ff/gg"], ["b/cc"]],
            expected: .success(false)
        ),
        // Compliance: single string search with array base
        BuiltinTests.TestCase(
            description: "single string search with array base match",
            name: "strings.any_prefix_match",
            args: ["a/b/c", ["a/", "d/"]],
            expected: .success(true)
        ),
        // Compliance: single string search no match
        BuiltinTests.TestCase(
            description: "single string search no match",
            name: "strings.any_prefix_match",
            args: ["a/b/c", ["g/", "d/"]],
            expected: .success(false)
        ),
        // Compliance: array search with single string base
        BuiltinTests.TestCase(
            description: "single string base match",
            name: "strings.any_prefix_match",
            args: [["a/b/c", "a/b/d", "e/f/g"], "a/"],
            expected: .success(true)
        ),
        // Compliance: single string base no match
        BuiltinTests.TestCase(
            description: "single string base no match",
            name: "strings.any_prefix_match",
            args: [["a/b/c", "a/b/d", "e/f/g"], "d/"],
            expected: .success(false)
        ),
        // Compliance: set inputs
        BuiltinTests.TestCase(
            description: "set inputs match",
            name: "strings.any_prefix_match",
            args: [.set(["a/b/c", "a/b/d", "e/f/g"]), .set(["a/", "d/"])],
            expected: .success(true)
        ),
        // Compliance: set inputs no match
        BuiltinTests.TestCase(
            description: "set inputs no match",
            name: "strings.any_prefix_match",
            args: [.set(["a/b/c", "a/b/d", "e/f/g"]), .set(["f/", "d/"])],
            expected: .success(false)
        ),
        // Compliance: empty arrays
        BuiltinTests.TestCase(
            description: "empty search returns false",
            name: "strings.any_prefix_match",
            args: [[], ["a/b", "e/f"]],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "empty prefixes returns false",
            name: "strings.any_prefix_match",
            args: [["a/b/c", "a/b/d", "e/f/g"], []],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "both empty returns false",
            name: "strings.any_prefix_match",
            args: [[], []],
            expected: .success(false)
        ),
        // RBAC-style: API path prefixes
        BuiltinTests.TestCase(
            description: "API paths match versioned prefix",
            name: "strings.any_prefix_match",
            args: [
                ["/api/v1/users/123", "/api/v1/roles/admin", "/health"],
                ["/api/v1/", "/api/v2/"],
            ],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "API paths no match for v3 prefix",
            name: "strings.any_prefix_match",
            args: [
                ["/api/v1/users/123", "/api/v1/roles/admin"],
                ["/api/v3/", "/internal/"],
            ],
            expected: .success(false)
        ),
        // Mixed: array search with set base
        BuiltinTests.TestCase(
            description: "array paths with set prefixes",
            name: "strings.any_prefix_match",
            args: [
                ["/api/v1/users", "/api/v2/roles"],
                .set(["/api/v1/", "/admin/"]),
            ],
            expected: .success(true)
        ),
        // Mixed: set search with single string base
        BuiltinTests.TestCase(
            description: "set paths with single prefix string",
            name: "strings.any_prefix_match",
            args: [.set(["/api/v1/users", "/health/ready"]), "/health/"],
            expected: .success(true)
        ),
        // Type errors
        BuiltinTests.TestCase(
            description: "type error: array with non-string element in search",
            name: "strings.any_prefix_match",
            args: [[1, 2, 3], ["/api/"]],
            expected: .failure(
                BuiltinError.argumentTypeMismatch(
                    arg: "search", got: "array containing number", want: "any<string, array[string], set[string]>"))
        ),
        BuiltinTests.TestCase(
            description: "type error: mixed array with string and number in search",
            name: "strings.any_prefix_match",
            args: [["/api/v1/users", 1], ["/api/"]],
            expected: .failure(
                BuiltinError.argumentTypeMismatch(
                    arg: "search", got: "array containing number", want: "any<string, array[string], set[string]>"))
        ),
        BuiltinTests.TestCase(
            description: "type error: array with non-string element in base",
            name: "strings.any_prefix_match",
            args: [["/api/v1/users"], [1, 2]],
            expected: .failure(
                BuiltinError.argumentTypeMismatch(
                    arg: "base", got: "array containing number", want: "any<string, array[string], set[string]>"))
        ),
        BuiltinTests.TestCase(
            description: "type error: set with non-string element in search",
            name: "strings.any_prefix_match",
            args: [.set([1, 2, 3]), ["/api/"]],
            expected: .failure(
                BuiltinError.argumentTypeMismatch(
                    arg: "search", got: "set containing number", want: "any<string, array[string], set[string]>"))
        ),
        BuiltinTests.TestCase(
            description: "type error: set with non-string element in base",
            name: "strings.any_prefix_match",
            args: [["/api/v1/users"], .set([1, 2])],
            expected: .failure(
                BuiltinError.argumentTypeMismatch(
                    arg: "base", got: "set containing number", want: "any<string, array[string], set[string]>"))
        ),
    ]

    // MARK: - strings.any_suffix_match

    static let anySuffixMatchTests: [BuiltinTests.TestCase] = [
        // Compliance: array search, array suffixes — match
        BuiltinTests.TestCase(
            description: "array match with multiple suffixes",
            name: "strings.any_suffix_match",
            args: [["a/b/c", "a/b/d", "e/f/g"], ["/c", "/a"]],
            expected: .success(true)
        ),
        // Compliance: no match
        BuiltinTests.TestCase(
            description: "array no match",
            name: "strings.any_suffix_match",
            args: [["a/b/c", "a/b/d", "e/f/g"], ["/f", "/a"]],
            expected: .success(false)
        ),
        // Compliance: multi-level suffix
        BuiltinTests.TestCase(
            description: "multi-level suffix match",
            name: "strings.any_suffix_match",
            args: [["a/b/c", "a/b/d", "e/f/g"], ["/b/c", "/d"]],
            expected: .success(true)
        ),
        // Compliance: suffix equals full string
        BuiltinTests.TestCase(
            description: "suffix equals full string",
            name: "strings.any_suffix_match",
            args: [["a/b/c", "a/b/d", "e/f/g"], ["/a", "e/f/g"]],
            expected: .success(true)
        ),
        // Compliance: partial suffix on longer strings
        BuiltinTests.TestCase(
            description: "partial suffix match on longer strings",
            name: "strings.any_suffix_match",
            args: [["aa/bb/cc", "aa/bb/dd", "ee/ff/gg"], ["b/cc", "f/g"]],
            expected: .success(true)
        ),
        // Compliance: not a suffix
        BuiltinTests.TestCase(
            description: "non-suffix substring no match",
            name: "strings.any_suffix_match",
            args: [["aa/bb/cc", "aa/bb/dd", "ee/ff/gg"], ["b/c", "f/g"]],
            expected: .success(false)
        ),
        // Compliance: prefix is not a suffix
        BuiltinTests.TestCase(
            description: "prefix is not a suffix",
            name: "strings.any_suffix_match",
            args: [["aa/bb/cc", "aa/bb/dd", "ee/ff/gg"], ["aa/b"]],
            expected: .success(false)
        ),
        // Compliance: single string search
        BuiltinTests.TestCase(
            description: "single string search match",
            name: "strings.any_suffix_match",
            args: ["a/b/c", ["/c", "/a"]],
            expected: .success(true)
        ),
        // Compliance: single string search no match
        BuiltinTests.TestCase(
            description: "single string search no match",
            name: "strings.any_suffix_match",
            args: ["a/b/g", ["/c", "/a"]],
            expected: .success(false)
        ),
        // Compliance: single string base
        BuiltinTests.TestCase(
            description: "single string base match",
            name: "strings.any_suffix_match",
            args: [["a/b/c", "a/b/d", "e/f/g"], "/c"],
            expected: .success(true)
        ),
        // Compliance: single string base no match
        BuiltinTests.TestCase(
            description: "single string base no match",
            name: "strings.any_suffix_match",
            args: [["a/b/c", "a/b/d", "e/f/g"], "/h"],
            expected: .success(false)
        ),
        // Compliance: set inputs
        BuiltinTests.TestCase(
            description: "set inputs match",
            name: "strings.any_suffix_match",
            args: [.set(["a/b/c", "a/b/d", "e/f/g"]), .set(["/c", "/a"])],
            expected: .success(true)
        ),
        // Compliance: set inputs no match
        BuiltinTests.TestCase(
            description: "set inputs no match",
            name: "strings.any_suffix_match",
            args: [.set(["a/b/c", "a/b/d", "e/f/g"]), .set(["/f", "/a"])],
            expected: .success(false)
        ),
        // Compliance: empty arrays
        BuiltinTests.TestCase(
            description: "empty search returns false",
            name: "strings.any_suffix_match",
            args: [[], ["/c"]],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "empty suffixes returns false",
            name: "strings.any_suffix_match",
            args: [["a/b/c"], []],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "both empty returns false",
            name: "strings.any_suffix_match",
            args: [[], []],
            expected: .success(false)
        ),
        // File extension matching
        BuiltinTests.TestCase(
            description: "file extensions match",
            name: "strings.any_suffix_match",
            args: [
                ["db.prod", "cache.prod", "api.dev"],
                [".prod", ".staging"],
            ],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "file extensions no match",
            name: "strings.any_suffix_match",
            args: [
                ["db.prod", "cache.prod", "api.dev"],
                [".test", ".staging"],
            ],
            expected: .success(false)
        ),
        // Mixed: array search with set base
        BuiltinTests.TestCase(
            description: "array paths with set suffixes",
            name: "strings.any_suffix_match",
            args: [
                ["/api/v1/users/list", "/api/v2/roles/get"],
                .set(["/list", "/delete"]),
            ],
            expected: .success(true)
        ),
        // Mixed: set search with single string base
        BuiltinTests.TestCase(
            description: "set paths with single suffix string",
            name: "strings.any_suffix_match",
            args: [.set(["resource.prod", "resource.dev"]), ".dev"],
            expected: .success(true)
        ),
        // Type errors
        BuiltinTests.TestCase(
            description: "type error: array with non-string element in search",
            name: "strings.any_suffix_match",
            args: [[1, 2, 3], [".prod"]],
            expected: .failure(
                BuiltinError.argumentTypeMismatch(
                    arg: "search", got: "array containing number", want: "any<string, array[string], set[string]>"))
        ),
        BuiltinTests.TestCase(
            description: "type error: mixed array with string and number in search",
            name: "strings.any_suffix_match",
            args: [["resource.prod", 1], [".prod"]],
            expected: .failure(
                BuiltinError.argumentTypeMismatch(
                    arg: "search", got: "array containing number", want: "any<string, array[string], set[string]>"))
        ),
        BuiltinTests.TestCase(
            description: "type error: array with non-string element in base",
            name: "strings.any_suffix_match",
            args: [["resource.prod"], [1, 2]],
            expected: .failure(
                BuiltinError.argumentTypeMismatch(
                    arg: "base", got: "array containing number", want: "any<string, array[string], set[string]>"))
        ),
        BuiltinTests.TestCase(
            description: "type error: set with non-string element in search",
            name: "strings.any_suffix_match",
            args: [.set([1, 2, 3]), [".prod"]],
            expected: .failure(
                BuiltinError.argumentTypeMismatch(
                    arg: "search", got: "set containing number", want: "any<string, array[string], set[string]>"))
        ),
        BuiltinTests.TestCase(
            description: "type error: set with non-string element in base",
            name: "strings.any_suffix_match",
            args: [["resource.prod"], .set([1, 2])],
            expected: .failure(
                BuiltinError.argumentTypeMismatch(
                    arg: "base", got: "set containing number", want: "any<string, array[string], set[string]>"))
        ),
    ]

    // MARK: - strings.replace_n

    static let replaceNTests: [BuiltinTests.TestCase] = [
        // Compliance: HTML escaping
        BuiltinTests.TestCase(
            description: "replace multiple patterns (HTML escaping)",
            name: "strings.replace_n",
            args: [
                .object([.string("<"): .string("&lt;"), .string(">"): .string("&gt;")]),
                "This is <b>HTML</b>!",
            ],
            expected: .success("This is &lt;b&gt;HTML&lt;/b&gt;!")
        ),
        // Compliance: overlapping — lex-first key wins (Go strings.NewReplacer priority)
        BuiltinTests.TestCase(
            description: "overlapping patterns lex-first key wins",
            name: "strings.replace_n",
            args: [
                .object([.string("f"): .string("x"), .string("foo"): .string("xxx")]),
                "foobar",
            ],
            expected: .success("xoobar")
        ),
        // Compliance: insertion order does not matter (sorted lex)
        BuiltinTests.TestCase(
            description: "overlapping patterns same result regardless of map order",
            name: "strings.replace_n",
            args: [
                .object([.string("foo"): .string("xxx"), .string("f"): .string("x")]),
                "foo",
            ],
            expected: .success("xoo")
        ),
        // Compliance: no patterns found
        BuiltinTests.TestCase(
            description: "no patterns found",
            name: "strings.replace_n",
            args: [
                .object([.string("old1"): .string("new1"), .string("old2"): .string("new2")]),
                "Everything is new1, new2",
            ],
            expected: .success("Everything is new1, new2")
        ),
        // Empty patterns object
        BuiltinTests.TestCase(
            description: "empty patterns",
            name: "strings.replace_n",
            args: [.object([:]), "hello world"],
            expected: .success("hello world")
        ),
        // Single pattern replacement
        BuiltinTests.TestCase(
            description: "single pattern replacement",
            name: "strings.replace_n",
            args: [
                .object([.string("world"): .string("universe")]),
                "hello world",
            ],
            expected: .success("hello universe")
        ),
        // Empty value string
        BuiltinTests.TestCase(
            description: "empty value string",
            name: "strings.replace_n",
            args: [
                .object([.string("a"): .string("b")]),
                "",
            ],
            expected: .success("")
        ),
        // Replace with empty string (deletion)
        BuiltinTests.TestCase(
            description: "replace with empty string deletes pattern",
            name: "strings.replace_n",
            args: [
                .object([.string("o"): .string("")]),
                "foobar",
            ],
            expected: .success("fbar")
        ),
        // Multiple non-overlapping replacements
        BuiltinTests.TestCase(
            description: "multiple non-overlapping replacements",
            name: "strings.replace_n",
            args: [
                .object([.string("a"): .string("1"), .string("b"): .string("2"), .string("c"): .string("3")]),
                "abc abc",
            ],
            expected: .success("123 123")
        ),
        // Non-string key error
        BuiltinTests.TestCase(
            description: "non-string key in patterns",
            name: "strings.replace_n",
            args: [
                .object([.number(2): .string("x")]),
                "foo",
            ],
            expected: .failure(
                BuiltinError.argumentTypeMismatch(
                    arg: "patterns", got: "non-string key number", want: "object[string: string]"))
        ),
        // Non-string value error
        BuiltinTests.TestCase(
            description: "non-string value in patterns",
            name: "strings.replace_n",
            args: [
                .object([.string("a"): .number(1)]),
                "foo",
            ],
            expected: .failure(
                BuiltinError.argumentTypeMismatch(
                    arg: "patterns", got: "non-string value number", want: "object[string: string]"))
        ),
    ]

    // MARK: - strings.render_template

    static let renderTemplateTests: [BuiltinTests.TestCase] = [
        // Compliance: simple variable substitution
        BuiltinTests.TestCase(
            description: "simple variable substitution",
            name: "strings.render_template",
            args: [
                "{{.test}}",
                .object([.string("test"): .string("hello world")]),
            ],
            expected: .success("hello world")
        ),
        // Compliance: integer value
        BuiltinTests.TestCase(
            description: "integer value substitution",
            name: "strings.render_template",
            args: [
                "{{.test}}",
                .object([.string("test"): .number(2023)]),
            ],
            expected: .success("2023")
        ),
        // Compliance: range with if
        BuiltinTests.TestCase(
            description: "range with conditional (complex template)",
            name: "strings.render_template",
            args: [
                "{{range $i, $name := .hellonames}}{{if $i}},{{end}}hello {{$name}}{{end}}",
                .object([.string("hellonames"): .array(["rohan", "john doe"])]),
            ],
            expected: .success("hello rohan,hello john doe")
        ),
        // Compliance: missing key
        BuiltinTests.TestCase(
            description: "missing key produces undefined",
            name: "strings.render_template",
            args: [
                "{{.testvarnotprovided}}",
                .object([.string("test"): .string("hello world")]),
            ],
            expected: .success("<undefined>")
        ),
        // Compliance: multiple missing keys
        BuiltinTests.TestCase(
            description: "multiple missing keys produce undefined",
            name: "strings.render_template",
            args: [
                "test {{.foo}} {{.bar}} {{.baz}}",
                .object([.string("baz"): .number(1)]),
            ],
            expected: .success("test <undefined> <undefined> 1")
        ),
        // Template with no variables
        BuiltinTests.TestCase(
            description: "template with no variables",
            name: "strings.render_template",
            args: [
                "hello world",
                .object([:]),
            ],
            expected: .success("hello world")
        ),
        // Empty template
        BuiltinTests.TestCase(
            description: "empty template",
            name: "strings.render_template",
            args: [
                "",
                .object([:]),
            ],
            expected: .success("")
        ),
        // Multiple variables in one template
        BuiltinTests.TestCase(
            description: "multiple variables",
            name: "strings.render_template",
            args: [
                "{{.greeting}}, {{.name}}!",
                .object([.string("greeting"): .string("Hello"), .string("name"): .string("world")]),
            ],
            expected: .success("Hello, world!")
        ),
        // Boolean value
        BuiltinTests.TestCase(
            description: "boolean value substitution",
            name: "strings.render_template",
            args: [
                "flag={{.enabled}}",
                .object([.string("enabled"): .boolean(true)]),
            ],
            expected: .success("flag=true")
        ),
        // Null value produces <nil> (not <undefined> — only missing keys become <undefined>)
        BuiltinTests.TestCase(
            description: "null value produces nil not undefined",
            name: "strings.render_template",
            args: [
                "val={{.key}}",
                .object([.string("key"): .null]),
            ],
            expected: .success("val=<nil>")
        ),
        // Mix of present, null, and missing
        BuiltinTests.TestCase(
            description: "present vs null vs missing",
            name: "strings.render_template",
            args: [
                "a={{.a}} b={{.b}} c={{.c}}",
                .object([.string("a"): .string("ok"), .string("b"): .null]),
            ],
            expected: .success("a=ok b=<nil> c=<undefined>")
        ),
    ]

    static var allTests: [BuiltinTests.TestCase] {
        [
            anyPrefixMatchTests,
            anySuffixMatchTests,

            BuiltinTests.generateFailureTests(
                builtinName: "strings.any_prefix_match", sampleArgs: [["a"], ["b"]], argIndex: 0,
                argName: "search", allowedArgTypes: ["string", "array", "set"],
                wantArgs: "any<string, array[string], set[string]>",
                generateNumberOfArgsTest: true),
            BuiltinTests.generateFailureTests(
                builtinName: "strings.any_prefix_match", sampleArgs: [["a"], ["b"]], argIndex: 1,
                argName: "base", allowedArgTypes: ["string", "array", "set"],
                wantArgs: "any<string, array[string], set[string]>",
                generateNumberOfArgsTest: false),

            BuiltinTests.generateFailureTests(
                builtinName: "strings.any_suffix_match", sampleArgs: [["a"], ["b"]], argIndex: 0,
                argName: "search", allowedArgTypes: ["string", "array", "set"],
                wantArgs: "any<string, array[string], set[string]>",
                generateNumberOfArgsTest: true),
            BuiltinTests.generateFailureTests(
                builtinName: "strings.any_suffix_match", sampleArgs: [["a"], ["b"]], argIndex: 1,
                argName: "base", allowedArgTypes: ["string", "array", "set"],
                wantArgs: "any<string, array[string], set[string]>",
                generateNumberOfArgsTest: false),

            concatTests,
            containsTests,
            endsWithTests,
            indexOfTests,
            lowerTests,
            splitTests,
            sprintfBasicTests,
            trimTests,
            upperTests,
            interpolationTests,

            BuiltinTests.generateFailureTests(
                builtinName: "strings.count", sampleArgs: ["search", "substring"], argIndex: 0,
                argName: "search", allowedArgTypes: ["string"], generateNumberOfArgsTest: true),
            BuiltinTests.generateFailureTests(
                builtinName: "strings.count", sampleArgs: ["search", "substring"], argIndex: 1,
                argName: "substring", allowedArgTypes: ["string"], generateNumberOfArgsTest: false),
            stringsCountTests,

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
                builtinName: "strings.replace_n",
                sampleArgs: [.object([.string("a"): .string("b")]), "value"],
                argIndex: 0, argName: "patterns",
                allowedArgTypes: ["object"], generateNumberOfArgsTest: true),
            BuiltinTests.generateFailureTests(
                builtinName: "strings.replace_n",
                sampleArgs: [.object([.string("a"): .string("b")]), "value"],
                argIndex: 1, argName: "value",
                allowedArgTypes: ["string"], generateNumberOfArgsTest: false),
            replaceNTests,

            BuiltinTests.generateFailureTests(
                builtinName: "strings.render_template",
                sampleArgs: ["template", .object([:])],
                argIndex: 0, argName: "value",
                allowedArgTypes: ["string"], generateNumberOfArgsTest: true),
            BuiltinTests.generateFailureTests(
                builtinName: "strings.render_template",
                sampleArgs: ["template", .object([:])],
                argIndex: 1, argName: "vars",
                allowedArgTypes: ["object"], generateNumberOfArgsTest: false),
            renderTemplateTests,

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
