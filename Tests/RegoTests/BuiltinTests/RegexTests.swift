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
        // $0 whole match reference
        BuiltinTests.TestCase(
            description: "$0 expands to whole match",
            name: "regex.replace",
            args: ["foo", "[a-z]+", "[$0]"],
            expected: .success("[foo]")
        ),
        // $$ literal dollar sign
        BuiltinTests.TestCase(
            description: "$$ produces literal dollar sign",
            name: "regex.replace",
            args: ["100", "[0-9]+", "$$$$"],
            expected: .success("$$")
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
        // Invalid pattern
        BuiltinTests.TestCase(
            description: "invalid pattern throws error",
            name: "regex.split",
            args: ["[", "hello"],
            expected: .failure(
                BuiltinError.evalError(msg: "invalid regex pattern: ["))
        ),
    ]

    // MARK: - regex.find_n

    static let regexFindNTests: [BuiltinTests.TestCase] = [
        // Compliance-inspired
        BuiltinTests.TestCase(
            description: "find all matches (n=-1)",
            name: "regex.find_n",
            args: ["a.", "paranormal", -1],
            expected: .success([.string("ar"), .string("an"), .string("al")])
        ),
        BuiltinTests.TestCase(
            description: "find 2 matches",
            name: "regex.find_n",
            args: ["a.", "paranormal", 2],
            expected: .success([.string("ar"), .string("an")])
        ),
        BuiltinTests.TestCase(
            description: "find 0 matches",
            name: "regex.find_n",
            args: ["a.", "paranormal", 0],
            expected: .success(.array([]))
        ),
        BuiltinTests.TestCase(
            description: "anchored start",
            name: "regex.find_n",
            args: ["^a.", "abacadaeaf", -1],
            expected: .success([.string("ab")])
        ),
        BuiltinTests.TestCase(
            description: "anchored end",
            name: "regex.find_n",
            args: [".$", "abacadaeaf", -1],
            expected: .success([.string("f")])
        ),
        BuiltinTests.TestCase(
            description: "non-overlapping character class matches",
            name: "regex.find_n",
            args: ["[abcdef]{2}", "abacadaeaf", -1],
            expected: .success([.string("ab"), .string("ac"), .string("ad"), .string("ae"), .string("af")])
        ),
        BuiltinTests.TestCase(
            description: "no matches returns empty array",
            name: "regex.find_n",
            args: ["[0-9]+", "hello", -1],
            expected: .success(.array([]))
        ),
        BuiltinTests.TestCase(
            description: "n=1 returns first match only",
            name: "regex.find_n",
            args: ["a.", "paranormal", 1],
            expected: .success([.string("ar")])
        ),
        BuiltinTests.TestCase(
            description: "n larger than matches returns all",
            name: "regex.find_n",
            args: ["a.", "paranormal", 100],
            expected: .success([.string("ar"), .string("an"), .string("al")])
        ),
        BuiltinTests.TestCase(
            description: "empty string input",
            name: "regex.find_n",
            args: ["a.", "", -1],
            expected: .success(.array([]))
        ),
        BuiltinTests.TestCase(
            description: "invalid pattern throws error",
            name: "regex.find_n",
            args: ["[", "hello", -1],
            expected: .failure(
                BuiltinError.evalError(msg: "invalid regex pattern: ["))
        ),
    ]

    // MARK: - regex.find_all_string_submatch_n

    static let regexFindAllStringSubmatchNTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "single match without captures",
            name: "regex.find_all_string_submatch_n",
            args: ["a(x*)b", "ab", -1],
            expected: .success([.array([.string("ab"), .string("")])])
        ),
        BuiltinTests.TestCase(
            description: "single match with capture",
            name: "regex.find_all_string_submatch_n",
            args: ["a(x*)b", "axxb", -1],
            expected: .success([.array([.string("axxb"), .string("xx")])])
        ),
        BuiltinTests.TestCase(
            description: "multiple matches with captures",
            name: "regex.find_all_string_submatch_n",
            args: ["a(x*)b", "axxb ab", -1],
            expected: .success([
                .array([.string("axxb"), .string("xx")]),
                .array([.string("ab"), .string("")]),
            ])
        ),
        BuiltinTests.TestCase(
            description: "no matches returns empty array",
            name: "regex.find_all_string_submatch_n",
            args: ["a(x*)b", "zzz", -1],
            expected: .success(.array([]))
        ),
        BuiltinTests.TestCase(
            description: "limited to n=1 match",
            name: "regex.find_all_string_submatch_n",
            args: ["a(x*)b", "axxb ab", 1],
            expected: .success([.array([.string("axxb"), .string("xx")])])
        ),
        BuiltinTests.TestCase(
            description: "n=0 returns empty array",
            name: "regex.find_all_string_submatch_n",
            args: ["a(x*)b", "axxb ab", 0],
            expected: .success(.array([]))
        ),
        // Multiple capture groups (compliance: s(.)(.) → ["som", "o", "m"])
        BuiltinTests.TestCase(
            description: "multiple capture groups",
            name: "regex.find_all_string_submatch_n",
            args: ["s(.)(.*?)", "something", -1],
            expected: .success([.array([.string("so"), .string("o"), .string("")])])
        ),
        BuiltinTests.TestCase(
            description: "empty string input",
            name: "regex.find_all_string_submatch_n",
            args: ["a(x*)b", "", -1],
            expected: .success(.array([]))
        ),
        BuiltinTests.TestCase(
            description: "invalid pattern throws error",
            name: "regex.find_all_string_submatch_n",
            args: ["[", "hello", -1],
            expected: .failure(
                BuiltinError.evalError(msg: "invalid regex pattern: ["))
        ),
    ]

    // MARK: - regex.template_match

    static let regexTemplateMatchTests: [BuiltinTests.TestCase] = [
        // Compliance-inspired
        BuiltinTests.TestCase(
            description: "matches wildcard with curly braces",
            name: "regex.template_match",
            args: ["urn:foo:{.*}", "urn:foo:bar:baz", "{", "}"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "matches wildcard with angle brackets",
            name: "regex.template_match",
            args: ["urn:foo:<.*>", "urn:foo:bar:baz", "<", ">"],
            expected: .success(true)
        ),
        // Additional coverage
        BuiltinTests.TestCase(
            description: "no match",
            name: "regex.template_match",
            args: ["urn:foo:{[0-9]+}", "urn:foo:bar", "{", "}"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "literal pattern without delimiters",
            name: "regex.template_match",
            args: ["exact", "exact", "{", "}"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "literal pattern no match",
            name: "regex.template_match",
            args: ["exact", "other", "{", "}"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "multiple template segments",
            name: "regex.template_match",
            args: ["{[a-z]+}:{[0-9]+}", "foo:123", "{", "}"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "special regex chars in literal parts are escaped",
            name: "regex.template_match",
            args: ["foo.bar:{.*}", "foo.bar:baz", "{", "}"],
            expected: .success(true)
        ),
        BuiltinTests.TestCase(
            description: "dot in literal is not a wildcard",
            name: "regex.template_match",
            args: ["foo.bar:{.*}", "fooXbar:baz", "{", "}"],
            expected: .success(false)
        ),
        BuiltinTests.TestCase(
            description: "unbalanced delimiters",
            name: "regex.template_match",
            args: ["urn:{foo", "urn:foo", "{", "}"],
            expected: .failure(
                BuiltinError.evalError(msg: "unbalanced delimiters in \"urn:{foo\""))
        ),
        BuiltinTests.TestCase(
            description: "start delimiter must be one character",
            name: "regex.template_match",
            args: ["pattern", "value", "{{", "}"],
            expected: .failure(
                BuiltinError.evalError(
                    msg: "start delimiter must be exactly one character, got 2"))
        ),
        BuiltinTests.TestCase(
            description: "end delimiter must be one character",
            name: "regex.template_match",
            args: ["pattern", "value", "{", "}}"],
            expected: .failure(
                BuiltinError.evalError(
                    msg: "end delimiter must be exactly one character, got 2"))
        ),
        BuiltinTests.TestCase(
            description: "invalid regex inside delimiters",
            name: "regex.template_match",
            args: ["urn:{[}", "urn:x", "{", "}"],
            expected: .failure(
                BuiltinError.evalError(msg: "invalid regex in template: urn:{[}"))
        ),
        BuiltinTests.TestCase(
            description: "nested delimiters",
            name: "regex.template_match",
            args: ["urn:{{.*}}", "urn:{foo}", "{", "}"],
            expected: .success(true)
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

            // regex.find_n
            BuiltinTests.generateFailureTests(
                builtinName: "regex.find_n", sampleArgs: ["pattern", "value", 1], argIndex: 0,
                argName: "pattern", allowedArgTypes: ["string"], generateNumberOfArgsTest: true),
            BuiltinTests.generateFailureTests(
                builtinName: "regex.find_n", sampleArgs: ["pattern", "value", 1], argIndex: 1,
                argName: "value", allowedArgTypes: ["string"], generateNumberOfArgsTest: false),
            BuiltinTests.generateFailureTests(
                builtinName: "regex.find_n", sampleArgs: ["pattern", "value", 1], argIndex: 2,
                argName: "number", allowedArgTypes: ["number"], generateNumberOfArgsTest: false),
            regexFindNTests,

            // regex.find_all_string_submatch_n
            BuiltinTests.generateFailureTests(
                builtinName: "regex.find_all_string_submatch_n", sampleArgs: ["pattern", "value", 1], argIndex: 0,
                argName: "pattern", allowedArgTypes: ["string"], generateNumberOfArgsTest: true),
            BuiltinTests.generateFailureTests(
                builtinName: "regex.find_all_string_submatch_n", sampleArgs: ["pattern", "value", 1], argIndex: 1,
                argName: "value", allowedArgTypes: ["string"], generateNumberOfArgsTest: false),
            BuiltinTests.generateFailureTests(
                builtinName: "regex.find_all_string_submatch_n", sampleArgs: ["pattern", "value", 1], argIndex: 2,
                argName: "number", allowedArgTypes: ["number"], generateNumberOfArgsTest: false),
            regexFindAllStringSubmatchNTests,

            // regex.template_match
            BuiltinTests.generateFailureTests(
                builtinName: "regex.template_match",
                sampleArgs: ["pattern", "value", "{", "}"], argIndex: 0,
                argName: "pattern", allowedArgTypes: ["string"], generateNumberOfArgsTest: true),
            BuiltinTests.generateFailureTests(
                builtinName: "regex.template_match",
                sampleArgs: ["pattern", "value", "{", "}"], argIndex: 1,
                argName: "value", allowedArgTypes: ["string"], generateNumberOfArgsTest: false),
            BuiltinTests.generateFailureTests(
                builtinName: "regex.template_match",
                sampleArgs: ["pattern", "value", "{", "}"], argIndex: 2,
                argName: "delimiter_start", allowedArgTypes: ["string"],
                generateNumberOfArgsTest: false),
            BuiltinTests.generateFailureTests(
                builtinName: "regex.template_match",
                sampleArgs: ["pattern", "value", "{", "}"], argIndex: 3,
                argName: "delimiter_end", allowedArgTypes: ["string"],
                generateNumberOfArgsTest: false),
            regexTemplateMatchTests,
        ].flatMap { $0 }
    }

    @Test(arguments: allTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await BuiltinTests.testBuiltin(tc: tc)
    }

    // MARK: - Template/regex cache namespace isolation

    /// Verify that the same string used as both a raw regex and a template
    /// produces different results. "foo.*" as a regex matches "fooXXX"
    /// (unanchored wildcard), but as a template it becomes "^foo\.\*$"
    /// (literal dots and stars, anchored) and does NOT match "fooXXX".
    @Test func templateAndRegexCacheDoNotCollide() async throws {
        let registry = BuiltinRegistry.defaultRegistry
        let ctx = BuiltinContext()

        // First: use "foo.*" as a raw regex — matches "fooXXX"
        let matchResult = try await registry.invoke(
            withContext: ctx, name: "regex.match",
            args: [.string("foo.*"), .string("fooXXX")], strict: true)
        #expect(matchResult == .boolean(true))

        // Then: use the same "foo.*" as a template with { } delimiters.
        // No delimiters in the string, so the entire thing is literal.
        // "^foo\.\*$" should NOT match "fooXXX".
        let templateResult = try await registry.invoke(
            withContext: ctx, name: "regex.template_match",
            args: [.string("foo.*"), .string("fooXXX"), .string("{"), .string("}")],
            strict: true)
        #expect(templateResult == .boolean(false))

        // But it should match the literal string "foo.*"
        let templateLiteral = try await registry.invoke(
            withContext: ctx, name: "regex.template_match",
            args: [.string("foo.*"), .string("foo.*"), .string("{"), .string("}")],
            strict: true)
        #expect(templateLiteral == .boolean(true))
    }
}
