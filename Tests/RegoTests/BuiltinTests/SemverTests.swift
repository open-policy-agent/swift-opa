import AST
import Foundation
import Testing

@testable import Rego

extension BuiltinTests {
    @Suite("BuiltinTests - SemVer", .tags(.builtins))
    struct SemverTests {}
}

extension BuiltinTests.SemverTests {
    // Pairs where the first element is greater than the second.
    static let greaterLesserFixtures: [(String, String)] = [
        ("0.0.0", "0.0.0-foo"),
        ("0.0.1", "0.0.0"),
        ("1.0.0", "0.9.9"),
        ("0.10.0", "0.9.0"),
        ("0.99.0", "0.10.0"),
        ("2.0.0", "1.2.3"),
        ("0.0.0", "0.0.0-foo"),
        ("0.0.1", "0.0.0"),
        ("1.0.0", "0.9.9"),
        ("0.10.0", "0.9.0"),
        ("0.99.0", "0.10.0"),
        ("2.0.0", "1.2.3"),
        ("0.0.0", "0.0.0-foo"),
        ("0.0.1", "0.0.0"),
        ("1.0.0", "0.9.9"),
        ("0.10.0", "0.9.0"),
        ("0.99.0", "0.10.0"),
        ("2.0.0", "1.2.3"),
        ("1.2.3", "1.2.3-asdf"),
        ("1.2.3", "1.2.3-4"),
        ("1.2.3", "1.2.3-4-foo"),
        ("1.2.3-5-foo", "1.2.3-5"),
        ("1.2.3-5", "1.2.3-4"),
        ("1.2.3-5-foo", "1.2.3-5-Foo"),
        ("3.0.0", "2.7.2+asdf"),
        ("3.0.0+foobar", "2.7.2"),
        ("1.2.3-a.10", "1.2.3-a.5"),
        ("1.2.3-a.b", "1.2.3-a.5"),
        ("1.2.3-a.b", "1.2.3-a"),
        ("1.2.3-a.b.c.10.d.5", "1.2.3-a.b.c.5.d.100"),
        ("1.0.0", "1.0.0-rc.1"),
        ("1.0.0-rc.2", "1.0.0-rc.1"),
        ("1.0.0-rc.1", "1.0.0-beta.11"),
        ("1.0.0-beta.11", "1.0.0-beta.2"),
        ("1.0.0-beta.2", "1.0.0-beta"),
        ("1.0.0-beta", "1.0.0-alpha.beta"),
        ("1.0.0-alpha.beta", "1.0.0-alpha.1"),
        ("1.0.0-alpha.1", "1.0.0-alpha"),
        ("1.2.3-rc.1-1-1hash", "1.2.3-rc.2"),
    ]

    // Versions that compare equal to themselves.
    static let equalFixtures: [String] = [
        "0.0.0",
        "1.2.3",
        "1.2.3-rc.1",
        "1.2.3+build.123",
        "1.2.3-rc.1+build.123",
        "1.2.3-rc.1+build.123.444",
    ]

    // Invalid semver strings.
    static let badInputFixtures: [String] = [
        "1.2",
        "1.2.3x",
        "0x1.3.4",
        "-1.2.3",
        "1.2.3.4",
        "0.88.0-11_e4e5dcabb",
        "0.88.0+11_e4e5dcabb",
    ]

    // MARK: - semver.compare test cases
    static var compareTests: [BuiltinTests.TestCase] {
        var cases: [BuiltinTests.TestCase] = []
        for (greater, lesser) in greaterLesserFixtures {
            cases.append(
                BuiltinTests.TestCase(
                    description: "compare: \(greater) > \(lesser)",
                    name: "semver.compare",
                    args: [.string(greater), .string(lesser)],
                    expected: .success(1)
                ))
            cases.append(
                BuiltinTests.TestCase(
                    description: "compare: \(lesser) < \(greater)",
                    name: "semver.compare",
                    args: [.string(lesser), .string(greater)],
                    expected: .success(-1)
                ))
            cases.append(
                BuiltinTests.TestCase(
                    description: "compare: v\(lesser) < \(greater)",
                    name: "semver.compare",
                    args: [.string("v" + lesser), .string(greater)],
                    expected: .success(-1)
                ))
            cases.append(
                BuiltinTests.TestCase(
                    description: "compare: \(lesser) < v\(greater)",
                    name: "semver.compare",
                    args: [.string(lesser), .string("v" + greater)],
                    expected: .success(-1)
                ))
        }
        for v in equalFixtures {
            cases.append(
                BuiltinTests.TestCase(
                    description: "compare: \(v) == \(v)",
                    name: "semver.compare",
                    args: [.string(v), .string(v)],
                    expected: .success(0)
                ))
            cases.append(
                BuiltinTests.TestCase(
                    description: "compare: \(v) == v\(v)",
                    name: "semver.compare",
                    args: [.string(v), .string("v" + v)],
                    expected: .success(0)
                ))
        }
        return cases
    }

    static let otherCompareTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "compare: a must be valid semver",
            name: "semver.compare",
            args: ["not-a-semver", "1.0.0"],
            expected: .failure(
                BuiltinError.evalError(msg: "operand 1: string not-a-semver is not a valid SemVer"))
        ),
        BuiltinTests.TestCase(
            description: "compare: b must be valid semver",
            name: "semver.compare",
            args: ["1.0.0", "not-a-semver"],
            expected: .failure(
                BuiltinError.evalError(msg: "operand 2: string not-a-semver is not a valid SemVer"))
        ),
    ]

    // MARK: - semver.is_valid test cases
    static var isValidTests: [BuiltinTests.TestCase] {
        var cases: [BuiltinTests.TestCase] = []
        for v in equalFixtures {
            cases.append(
                BuiltinTests.TestCase(
                    description: "is_valid: \(v) is valid",
                    name: "semver.is_valid",
                    args: [.string(v)],
                    expected: .success(true)
                ))
            cases.append(
                BuiltinTests.TestCase(
                    description: "is_valid: v\(v) is valid",
                    name: "semver.is_valid",
                    args: [.string("v" + v)],
                    expected: .success(true)
                ))
        }
        for v in badInputFixtures {
            cases.append(
                BuiltinTests.TestCase(
                    description: "is_valid: \(v) is invalid",
                    name: "semver.is_valid",
                    args: [.string(v)],
                    expected: .success(false)
                ))
        }
        // Non-string inputs return false rather than a type error
        for (typeName, value): (String, AST.RegoValue) in [
            ("number", 123), ("boolean", false), ("null", .null),
            ("array", [1, 2, 3]), ("object", ["a": 1]), ("set", .set([1])),
        ] {
            cases.append(
                BuiltinTests.TestCase(
                    description: "is_valid: false for \(typeName)",
                    name: "semver.is_valid",
                    args: [value],
                    expected: .success(false)
                ))
        }
        return cases
    }

    // MARK: - All Tests
    static var allTests: [BuiltinTests.TestCase] {
        [
            BuiltinTests.generateNumberOfArgumentsFailureTests(
                builtinName: "semver.is_valid", sampleArgs: ["1.0.0"]),
            BuiltinTests.generateFailureTests(
                builtinName: "semver.compare", sampleArgs: ["1.0.0", "2.0.0"], argIndex: 0,
                argName: "a", allowedArgTypes: ["string"],
                generateNumberOfArgsTest: true, numberAsInteger: false),
            BuiltinTests.generateFailureTests(
                builtinName: "semver.compare", sampleArgs: ["1.0.0", "2.0.0"], argIndex: 1,
                argName: "b", allowedArgTypes: ["string"],
                generateNumberOfArgsTest: false, numberAsInteger: false),
            otherCompareTests,
            isValidTests,
            compareTests,
        ].flatMap { $0 }
    }

    @Test(arguments: allTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await BuiltinTests.testBuiltin(tc: tc)
    }
}
