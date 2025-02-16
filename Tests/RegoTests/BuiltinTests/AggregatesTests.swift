import AST
import Foundation
import Testing

@testable import Rego

extension BuiltinTests {
    @Suite("BuiltinTests - Aggregates", .tags(.builtins))
    struct AggregatesTests {}
}

extension BuiltinTests.AggregatesTests {
    static let countTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "string count",
            name: "count",
            args: ["abc"],
            expected: .success(3)
        ),
        BuiltinTests.TestCase(
            description: "string empty",
            name: "count",
            args: [""],
            expected: .success(0)
        ),
        BuiltinTests.TestCase(
            description: "array count",
            name: "count",
            args: [[1, 2, 3]],
            expected: .success(3)
        ),
        BuiltinTests.TestCase(
            description: "array empty",
            name: "count",
            args: [[]],
            expected: .success(0)
        ),
        BuiltinTests.TestCase(
            description: "set count",
            name: "count",
            args: [.set([1, 2, 3])],
            expected: .success(3)
        ),
        BuiltinTests.TestCase(
            description: "set empty",
            name: "count",
            args: [.set([])],
            expected: .success(0)
        ),
        BuiltinTests.TestCase(
            description: "object count",
            name: "count",
            args: [
                ["a": 1, "b": 2, "c": 3]
            ],
            expected: .success(3)
        ),
        BuiltinTests.TestCase(
            description: "object empty",
            name: "count",
            args: [
                [:]
            ],
            expected: .success(0)
        ),
    ]

    static let maxTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "array",
            name: "max",
            args: [[1, 100, 2]],
            expected: .success(100)
        ),
        BuiltinTests.TestCase(
            description: "string array",
            name: "max",
            args: [["a", "b"]],
            expected: .success("b")
        ),
        BuiltinTests.TestCase(
            description: "empty array",
            name: "max",
            args: [[]],
            expected: .success(.undefined)
        ),
        BuiltinTests.TestCase(
            description: "array of objects",
            name: "max",
            args: [
                [["a": 1], ["a": 100], ["a": 3]]
            ],
            // 2nd object has largest value
            expected: .success(["a": 100])
        ),
        BuiltinTests.TestCase(
            description: "array of objects with different keys",
            name: "max",
            args: [
                [["a": 100], ["c": 3, "d": 4], ["b": 101]]
            ],
            // 2nd object has largest key
            expected: .success(["c": 3, "d": 4])
        ),
        BuiltinTests.TestCase(
            description: "set",
            name: "max",
            args: [.set([1, 100, 2])],
            expected: .success(100)
        ),
        BuiltinTests.TestCase(
            description: "string set",
            name: "max",
            args: [.set(["a", "b"])],
            expected: .success("b")
        ),
        BuiltinTests.TestCase(
            description: "empty set",
            name: "max",
            args: [.set([])],
            expected: .success(.undefined)
        ),
        BuiltinTests.TestCase(
            description: "set of objects",
            name: "max",
            args: [
                .set([["a": 1], ["a": 100], ["a": 3]])
            ],
            // 2nd element has largest value
            expected: .success(["a": 100])
        ),
        BuiltinTests.TestCase(
            description: "set of objects with different keys",
            name: "max",
            args: [
                .set([["a": 100], ["c": 3, "d": 4], ["b": 101]])
            ],
            // 2nd element has largest key
            expected: .success(["c": 3, "d": 4])
        ),
        BuiltinTests.TestCase(
            description: "array of different types",
            name: "max",
            args: [
                [[1, 100, 0], .object(["z": 999]), .set([0]), [999], "10000"]
            ],
            // Set's sortOrder is the largest
            expected: .success(.set([0]))
        ),
    ]

    static let minTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "array",
            name: "min",
            args: [[1, 0, 2]],
            expected: .success(0)
        ),
        BuiltinTests.TestCase(
            description: "string array",
            name: "min",
            args: [["a", "b"]],
            expected: .success("a")
        ),
        BuiltinTests.TestCase(
            description: "empty array",
            name: "min",
            args: [[]],
            expected: .success(.undefined)
        ),
        BuiltinTests.TestCase(
            description: "array of objects",
            name: "min",
            args: [
                [["a": 1], ["a": 0], ["a": 3]]
            ],
            // 2nd object has smallest value
            expected: .success(["a": 0])
        ),
        BuiltinTests.TestCase(
            description: "array of objects with different keys",
            name: "min",
            args: [
                [["a": 999], ["c": 3, "d": 4], ["b": 101]]
            ],
            // 1st object has smallest key
            expected: .success(["a": 999])
        ),
        BuiltinTests.TestCase(
            description: "set",
            name: "min",
            args: [.set([1, 0, 2])],
            expected: .success(0)
        ),
        BuiltinTests.TestCase(
            description: "string set",
            name: "min",
            args: [.set(["a", "b"])],
            expected: .success("a")
        ),
        BuiltinTests.TestCase(
            description: "empty set",
            name: "min",
            args: [.set([])],
            expected: .success(.undefined)
        ),
        BuiltinTests.TestCase(
            description: "set of objects",
            name: "min",
            args: [
                .set([["a": 1], ["a": 0], ["a": 3]])
            ],
            // 2nd element has smallest value
            expected: .success(["a": 0])
        ),
        BuiltinTests.TestCase(
            description: "set of objects with different keys",
            name: "min",
            args: [
                .set([["a": 999], ["c": 3, "d": 4], ["b": 101]])
            ],
            // 1st element has smallest key
            expected: .success(["a": 999])
        ),
        BuiltinTests.TestCase(
            description: "array of different types",
            name: "min",
            args: [
                [[1, 100, 0], .object(["z": 999]), .set([0]), [999], "10000"]

            ],
            // string's sortOrder is the smallest
            expected: .success("10000")
        ),
    ]

    static var allTests: [BuiltinTests.TestCase] {
        [
            BuiltinTests.generateFailureTests(
                builtinName: "count", sampleArgs: [[]],
                argIndex: 0, argName: "collection",
                allowedArgTypes: ["string", "array", "object", "set"],
                generateNumberOfArgsTest: true),
            countTests,

            BuiltinTests.generateFailureTests(
                builtinName: "max", sampleArgs: [[]],
                argIndex: 0, argName: "collection",
                allowedArgTypes: ["array", "set"],
                generateNumberOfArgsTest: true),
            maxTests,

            BuiltinTests.generateFailureTests(
                builtinName: "min", sampleArgs: [[]],
                argIndex: 0, argName: "collection",
                allowedArgTypes: ["array", "set"],
                generateNumberOfArgsTest: true),
            minTests,
        ].flatMap { $0 }
    }

    @Test(arguments: allTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await BuiltinTests.testBuiltin(tc: tc)
    }
}
