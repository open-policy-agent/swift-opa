import AST
import Foundation
import Testing

@testable import Rego

extension BuiltinTests {
    @Suite("BuiltinTests - Regex", .tags(.builtins))
    struct RegexTests {}
}

extension BuiltinTests.RegexTests {

    // MARK: - regex.is_valid

    static let regexIsValidTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "valid pattern: dot-plus",
            name: "regex.is_valid",
            args: [".+"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "valid pattern: anchored character class",
            name: "regex.is_valid",
            args: ["^[a-z]+$"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "valid pattern: empty string",
            name: "regex.is_valid",
            args: [""],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "invalid pattern: double plus",
            name: "regex.is_valid",
            args: ["++"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "invalid pattern: unclosed bracket",
            name: "regex.is_valid",
            args: ["["],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "invalid pattern: unclosed paren",
            name: "regex.is_valid",
            args: ["("],
            expected: .success(false)
        ),
        // Special: non-string operand returns false (not error)
        BuiltinTests.TestCase(
            description: "non-string operand returns false",
            name: "regex.is_valid",
            args: [123],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "boolean operand returns false",
            name: "regex.is_valid",
            args: [true],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "null operand returns false",
            name: "regex.is_valid",
            args: [.null],
            expected: .success(false)
        ),
    ]

    // MARK: - regex.match

    static let regexMatchTests: [BuiltinTests.TestCase] = [
        // Compliance-inspired
        BuiltinTests.TestCase(
            description: "positive: anchored pattern matches",
            name: "regex.match",
            args: ["^[a-z]+\\[[0-9]+\\]$", "foo[1]"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "empty anchored matches empty string",
            name: "regex.match",
            args: ["^$", ""],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "empty pattern matches empty string",
            name: "regex.match",
            args: ["", ""],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "empty pattern matches non-empty string",
            name: "regex.match",
            args: ["", "x"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "negative: anchored pattern does not match",
            name: "regex.match",
            args: ["^$", "something"],
            expected: .success(false)
        ),
        // Unanchored matching
        BuiltinTests.TestCase(
            description: "unanchored pattern matches substring",
            name: "regex.match",
            args: ["[0-9]+", "abc123def"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "unanchored pattern no match",
            name: "regex.match",
            args: ["[0-9]+", "abcdef"],
            expected: .success(false)
        ),
        // Invalid pattern
        BuiltinTests.TestCase(
            description: "invalid pattern throws error",
            name: "regex.match",
            args: ["$^[[[", "something"],
            expected: .failure(
                BuiltinError.evalError(msg: "invalid regex pattern: $^[[["))
        ),
    ]

    // MARK: - regex.replace

    static let regexReplaceTests: [BuiltinTests.TestCase] = [
        // Compliance-inspired
        BuiltinTests.TestCase(
            description: "pattern match and replace",
            name: "regex.replace",
            args: ["-wy-wxxy-", "w(x*)y", "0"],
            expected: .success("-0-0-")
        ),
        BuiltinTests.TestCase(
            description: "capture group expansion",
            name: "regex.replace",
            args: ["foo", "(foo)", "$1$1"],
            expected: .success("foofoo")
        ),
        BuiltinTests.TestCase(
            description: "anchored start",
            name: "regex.replace",
            args: ["foo", "^[a-z]", "F"],
            expected: .success("Foo")
        ),
        BuiltinTests.TestCase(
            description: "anchored start+end, no match",
            name: "regex.replace",
            args: ["foo", "^[a-z]$", "F"],
            expected: .success("foo")
        ),
        BuiltinTests.TestCase(
            description: "anchored start+end, match",
            name: "regex.replace",
            args: ["foo", "^[a-z]+$", "M"],
            expected: .success("M")
        ),
        BuiltinTests.TestCase(
            description: "anchored end",
            name: "regex.replace",
            args: ["foo", "[a-z]$", "F"],
            expected: .success("foF")
        ),
        BuiltinTests.TestCase(
            description: "anchored end, no match",
            name: "regex.replace",
            args: ["foo", "x[a-z]$", "F"],
            expected: .success("foo")
        ),
        BuiltinTests.TestCase(
            description: "per-character match",
            name: "regex.replace",
            args: ["foo bar", "[a-z]", "_"],
            expected: .success("___ ___")
        ),
        BuiltinTests.TestCase(
            description: "match with count 3",
            name: "regex.replace",
            args: ["foo barx", "[a-z]{3}", "_"],
            expected: .success("_ _x")
        ),
        BuiltinTests.TestCase(
            description: "match with count 2",
            name: "regex.replace",
            args: ["foo barx", "[a-z]{2}", "_"],
            expected: .success("_o __")
        ),
        // No match
        BuiltinTests.TestCase(
            description: "no match returns original",
            name: "regex.replace",
            args: ["hello world", "[0-9]+", "X"],
            expected: .success("hello world")
        ),
        // Invalid pattern
        BuiltinTests.TestCase(
            description: "invalid pattern throws error",
            name: "regex.replace",
            args: ["foo", "[", "$1"],
            expected: .failure(
                BuiltinError.evalError(msg: "invalid regex pattern: ["))
        ),
    ]

    // MARK: - regex.split

    static let regexSplitTests: [BuiltinTests.TestCase] = [
        // Compliance-inspired
        BuiltinTests.TestCase(
            description: "empty string",
            name: "regex.split",
            args: ["^[a-z]+\\[[0-9]+\\]$", ""],
            expected: .success([""])
        ),
        BuiltinTests.TestCase(
            description: "anchored start",
            name: "regex.split",
            args: ["^[a-z]+", "foobar baz"],
            expected: .success([.string(""), .string(" baz")])
        ),
        BuiltinTests.TestCase(
            description: "anchored end",
            name: "regex.split",
            args: ["[a-z]+$", "foobar baz"],
            expected: .success([.string("foobar "), .string("")])
        ),
        BuiltinTests.TestCase(
            description: "anchored start+end, no match",
            name: "regex.split",
            args: ["^[a-z]+$", "foobar baz"],
            expected: .success(["foobar baz"])
        ),
        BuiltinTests.TestCase(
            description: "anchored start+end, match",
            name: "regex.split",
            args: ["^[a-z ]+$", "foobar baz"],
            expected: .success([.string(""), .string("")])
        ),
        BuiltinTests.TestCase(
            description: "non-repeat pattern",
            name: "regex.split",
            args: ["a", "banana"],
            expected: .success([.string("b"), .string("n"), .string("n"), .string("")])
        ),
        BuiltinTests.TestCase(
            description: "repeat pattern",
            name: "regex.split",
            args: ["z+", "pizza"],
            expected: .success([.string("pi"), .string("a")])
        ),
        // No match
        BuiltinTests.TestCase(
            description: "no match returns original in array",
            name: "regex.split",
            args: ["[0-9]+", "hello"],
            expected: .success(["hello"])
        ),
    ]

    // MARK: - All tests

    static var allTests: [BuiltinTests.TestCase] {
        [
            // regex.is_valid - arg count only (wrong types return false, not error)
            BuiltinTests.generateNumberOfArgumentsFailureTests(
                builtinName: "regex.is_valid", sampleArgs: [".+"]),
            regexIsValidTests,

            // regex.match
            BuiltinTests.generateFailureTests(
                builtinName: "regex.match", sampleArgs: ["pattern", "value"], argIndex: 0,
                argName: "pattern", allowedArgTypes: ["string"], generateNumberOfArgsTest: true),
            BuiltinTests.generateFailureTests(
                builtinName: "regex.match", sampleArgs: ["pattern", "value"], argIndex: 1,
                argName: "value", allowedArgTypes: ["string"], generateNumberOfArgsTest: false),
            regexMatchTests,

            // regex.replace
            BuiltinTests.generateFailureTests(
                builtinName: "regex.replace", sampleArgs: ["base", "pattern", "value"], argIndex: 0,
                argName: "s", allowedArgTypes: ["string"], generateNumberOfArgsTest: true),
            BuiltinTests.generateFailureTests(
                builtinName: "regex.replace", sampleArgs: ["base", "pattern", "value"], argIndex: 1,
                argName: "pattern", allowedArgTypes: ["string"], generateNumberOfArgsTest: false),
            BuiltinTests.generateFailureTests(
                builtinName: "regex.replace", sampleArgs: ["base", "pattern", "value"], argIndex: 2,
                argName: "value", allowedArgTypes: ["string"], generateNumberOfArgsTest: false),
            regexReplaceTests,

            // regex.split
            BuiltinTests.generateFailureTests(
                builtinName: "regex.split", sampleArgs: ["pattern", "value"], argIndex: 0,
                argName: "pattern", allowedArgTypes: ["string"], generateNumberOfArgsTest: true),
            BuiltinTests.generateFailureTests(
                builtinName: "regex.split", sampleArgs: ["pattern", "value"], argIndex: 1,
                argName: "value", allowedArgTypes: ["string"], generateNumberOfArgsTest: false),
            regexSplitTests,
        ].flatMap { $0 }
    }

    @Test(arguments: allTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await BuiltinTests.testBuiltin(tc: tc)
    }
}
