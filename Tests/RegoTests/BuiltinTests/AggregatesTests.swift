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

    static let sumTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "empty array",
            name: "sum",
            args: [[]],
            expected: .success(0)
        ),
        BuiltinTests.TestCase(
            description: "array",
            name: "sum",
            args: [[1, 2, 3.14, 4]],
            expected: .success(.number(NSDecimalNumber(decimal: 1 + 2 + 3.14 + 4)))
        ),
        BuiltinTests.TestCase(
            description: "array of various objects",
            name: "sum",
            args: [[1, "a", "b"]],
            expected: .failure(
                BuiltinError.argumentTypeMismatch(
                    arg: "collection", got: "array[any<number, string>]", want: "any<array[number], set[number]>"))
        ),
        BuiltinTests.TestCase(
            description: "empty set",
            name: "sum",
            args: [.set([])],
            expected: .success(0)
        ),
        BuiltinTests.TestCase(
            description: "set",
            name: "sum",
            args: [.set([1, 5, 8.65])],
            expected: .success(.number(NSDecimalNumber(decimal: 1 + 5 + 8.65)))
        ),
        BuiltinTests.TestCase(
            description: "set of various objects",
            name: "sum",
            args: [.set([1, "a", "b"])],
            expected: .failure(
                BuiltinError.argumentTypeMismatch(
                    arg: "collection", got: "set[any<number, string>]", want: "any<array[number], set[number]>"))
        ),
    ]

    static let productTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "empty array",
            name: "product",
            args: [[]],
            expected: .success(1)
        ),
        BuiltinTests.TestCase(
            description: "array",
            name: "product",
            args: [[1, 2, 3.14, 4]],
            expected: .success(.number(NSDecimalNumber(decimal: 1 * 2 * 3.14 * 4)))
        ),
        BuiltinTests.TestCase(
            description: "array of various objects",
            name: "product",
            args: [[1, "a"]],
            expected: .failure(
                BuiltinError.argumentTypeMismatch(
                    arg: "collection", got: "array[any<number, string>]", want: "any<array[number], set[number]>"))
        ),
        BuiltinTests.TestCase(
            description: "empty set",
            name: "product",
            args: [.set([])],
            expected: .success(1)
        ),
        BuiltinTests.TestCase(
            description: "set",
            name: "product",
            args: [.set([1, 5, 8.65])],
            expected: .success(.number(NSDecimalNumber(decimal: 1 * 5 * 8.65)))
        ),
        BuiltinTests.TestCase(
            description: "set of various objects",
            name: "product",
            args: [.set([1, "a"])],
            expected: .failure(
                BuiltinError.argumentTypeMismatch(
                    arg: "collection", got: "set[any<number, string>]", want: "any<array[number], set[number]>"))
        ),
    ]

    static let sortTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "array",
            name: "sort",
            args: [[1, 100, 2]],
            expected: .success([1, 2, 100])
        ),
        BuiltinTests.TestCase(
            description: "string array",
            name: "sort",
            args: [["b", "a"]],
            expected: .success(["a", "b"])
        ),
        BuiltinTests.TestCase(
            description: "empty array",
            name: "sort",
            args: [[]],
            expected: .success([])
        ),
        BuiltinTests.TestCase(
            description: "array of objects",
            name: "sort",
            args: [
                [["a": 1], ["a": 100], ["a": 3]]
            ],
            expected: .success([["a": 1], ["a": 3], ["a": 100]])
        ),
        BuiltinTests.TestCase(
            description: "array of objects with different keys",
            name: "sort",
            args: [
                [["a": 100], ["c": 3, "d": 4], ["b": 101]]
            ],
            expected: .success([["a": 100], ["b": 101], ["c": 3, "d": 4]])
        ),
        BuiltinTests.TestCase(
            description: "set",
            name: "sort",
            args: [.set([1, 100, 2])],
            expected: .success([1, 2, 100])
        ),
        BuiltinTests.TestCase(
            description: "string set",
            name: "sort",
            args: [.set(["b", "a"])],
            expected: .success(["a", "b"])
        ),
        BuiltinTests.TestCase(
            description: "empty set",
            name: "sort",
            args: [.set([])],
            expected: .success([])
        ),
        BuiltinTests.TestCase(
            description: "set of objects",
            name: "sort",
            args: [
                .set([["a": 1], ["a": 100], ["a": 3]])
            ],
            expected: .success([["a": 1], ["a": 3], ["a": 100]])
        ),
        BuiltinTests.TestCase(
            description: "set of objects with different keys",
            name: "sort",
            args: [
                .set([["a": 100], ["c": 3, "d": 4], ["b": 101]])
            ],
            // 2nd element has largest key
            expected: .success([["a": 100], ["b": 101], ["c": 3, "d": 4]])
        ),
        BuiltinTests.TestCase(
            description: "array of different types",
            name: "sort",
            args: [
                [[1, 100, 0], .object(["z": 999]), .set([0]), [999], "10000"]
            ],
            expected: .success(["10000", [1, 100, 0], [999], .object(["z": 999]), .set([0])])
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
                wantArgs: "any<array[any], set[any]>",
                generateNumberOfArgsTest: true),
            maxTests,

            BuiltinTests.generateFailureTests(
                builtinName: "min", sampleArgs: [[]],
                argIndex: 0, argName: "collection",
                allowedArgTypes: ["array", "set"],
                wantArgs: "any<array[any], set[any]>",
                generateNumberOfArgsTest: true),
            minTests,

            BuiltinTests.generateFailureTests(
                builtinName: "sum", sampleArgs: [[]],
                argIndex: 0, argName: "collection",
                allowedArgTypes: ["array", "set"],
                wantArgs: "any<array[number], set[number]>",
                generateNumberOfArgsTest: true),
            sumTests,

            BuiltinTests.generateFailureTests(
                builtinName: "product", sampleArgs: [[]],
                argIndex: 0, argName: "collection",
                allowedArgTypes: ["array", "set"],
                wantArgs: "any<array[number], set[number]>",
                generateNumberOfArgsTest: true),
            productTests,

            BuiltinTests.generateFailureTests(
                builtinName: "sort", sampleArgs: [[]],
                argIndex: 0, argName: "collection",
                allowedArgTypes: ["array", "set"],
                wantArgs: "any<array[any], set[any]>",
                generateNumberOfArgsTest: true),
            sortTests,

        ].flatMap { $0 }
    }

    @Test(arguments: allTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await BuiltinTests.testBuiltin(tc: tc)
    }
}
