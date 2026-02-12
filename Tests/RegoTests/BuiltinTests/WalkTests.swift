import AST
import Foundation
import Testing

@testable import Rego

extension BuiltinTests {
    @Suite("BuiltinTests - Walk", .tags(.builtins))
    struct WalkTests {}
}

extension BuiltinTests.WalkTests {
    static let walkTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "undefined",
            name: "walk",
            args: [
                .undefined
            ],
            expected: .success(.undefined)
        ),
        BuiltinTests.TestCase(
            description: "scalar - number",
            name: "walk",
            args: [
                .number(1)
            ],
            expected: .success(.array([[[], 1]]))
        ),
        BuiltinTests.TestCase(
            description: "flat array of strings",
            name: "walk",
            args: [
                [
                    "A",
                    "B",
                    "C",
                ]
            ],
            expected: .success(
                .array([
                    [[], ["A", "B", "C"]],
                    [[0], "A"],
                    [[1], "B"],
                    [[2], "C"],
                ])
            )
        ),
        BuiltinTests.TestCase(
            description: "nested object",
            name: "walk",
            args: [
                ["b": ["v1": "hello", "v2": "goodbye"]]
            ],
            expected: .success(
                .array([
                    [[], ["b": ["v1": "hello", "v2": "goodbye"]]],
                    [["b"], ["v1": "hello", "v2": "goodbye"]],
                    [["b", "v1"], "hello"],
                    [["b", "v2"], "goodbye"],
                ])
            )
        ),
        BuiltinTests.TestCase(
            description: "nested array",
            name: "walk",
            args: [
                [
                    ["A", "B", "C"],
                    ["D", "E", "F"],
                ]
            ],
            expected: .success(
                .array([
                    [[], [["A", "B", "C"], ["D", "E", "F"]]],
                    [[0], ["A", "B", "C"]],
                    [[0, 0], "A"],
                    [[0, 1], "B"],
                    [[0, 2], "C"],
                    [[1], ["D", "E", "F"]],
                    [[1, 0], "D"],
                    [[1, 1], "E"],
                    [[1, 2], "F"],
                ])
            )
        ),
        BuiltinTests.TestCase(
            description: "nested sets",
            name: "walk",
            args: [
                .set([1, .set([2, 3])])
            ],
            expected: .success(
                .array([
                    [[], .set([1, .set([2, 3])])],
                    [[1], 1],
                    [[.set([2, 3])], .set([2, 3])],
                    [[.set([2, 3]), 2], 2],
                    [[.set([2, 3]), 3], 3],
                ])
            )
        ),
    ]
    static var allTests: [BuiltinTests.TestCase] {
        [
            BuiltinTests.generateFailureTests(
                builtinName: "walk", sampleArgs: [[1, 2, 3]],
                argIndex: 0, argName: "x",
                allowedArgTypes: ["undefined", "boolean", "null", "number", "string", "array", "object", "set"],
                generateNumberOfArgsTest: true),
            walkTests,
        ].flatMap { $0 }
    }

    @Test(arguments: allTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await BuiltinTests.testBuiltin(tc: tc)
    }
}
