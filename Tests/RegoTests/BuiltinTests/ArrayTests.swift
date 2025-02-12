import AST
import Foundation
import Testing

@testable import Rego

@Suite("BuiltinTests - Array")
struct ArrayTests {
    static let arrayConcatTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "simple concat",
            name: "array.concat",
            args: [
                ["a", "b"],
                ["c", "d"],
            ],
            expected: .success(["a", "b", "c", "d"])
        ),
        BuiltinTests.TestCase(
            description: "lhs empty",
            name: "array.concat",
            args: [
                [],
                ["c", "d"],
            ],
            expected: .success(["c", "d"])
        ),
        BuiltinTests.TestCase(
            description: "rhs empty",
            name: "array.concat",
            args: [
                ["a", "b"],
                [],
            ],
            expected: .success(["a", "b"])
        ),
        BuiltinTests.TestCase(
            description: "both empty",
            name: "array.concat",
            args: [
                [],
                [],
            ],
            expected: .success([])
        ),
        BuiltinTests.TestCase(
            description: "mixed types",
            name: "array.concat",
            args: [
                ["a", "b"],
                [1, 2],
            ],
            expected: .success(["a", "b", 1, 2])
        ),
        BuiltinTests.TestCase(
            description: "lhs null (fail)",
            name: "array.concat",
            args: [
                .null,
                ["c", "d"],
            ],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "x"))
        ),
    ]

    static let arrayReverseTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "simple reverse",
            name: "array.reverse",
            args: [["a", "b"]],
            expected: .success(["b", "a"])
        ),
        BuiltinTests.TestCase(
            description: "empty reverse",
            name: "array.reverse",
            args: [[]],
            expected: .success([])
        ),
    ]

    static let arraySliceTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "slice in the middle",
            name: "array.slice",
            args: [["a", "b", "c", "d"], 1, 3],
            expected: .success(["b", "c"])
        ),
        BuiltinTests.TestCase(
            description: "start index out of bounds",
            name: "array.slice",
            args: [["a", "b", "c", "d"], -1, 3],
            expected: .success(["a", "b", "c"])
        ),
        BuiltinTests.TestCase(
            description: "stop index out of bounds",
            name: "array.slice",
            args: [["a", "b", "c", "d"], 0, 10],
            expected: .success(["a", "b", "c", "d"])
        ),
        BuiltinTests.TestCase(
            description: "start = stop and in bounds",
            name: "array.slice",
            args: [["a", "b", "c", "d"], 1, 1],
            expected: .success([])
        ),
        BuiltinTests.TestCase(
            description: "start = stop and out of bounds",
            name: "array.slice",
            args: [["a", "b", "c", "d"], -1, -1],
            expected: .success([])
        ),
        BuiltinTests.TestCase(
            description: "start > stop",
            name: "array.slice",
            args: [["a", "b", "c", "d"], 2, 1],
            expected: .success([])
        ),
        BuiltinTests.TestCase(
            description: "start is not an integer (undefined)",
            name: "array.slice",
            args: [["a", "b", "c", "d"], 1.1, 3],
            expected: .success(.undefined)
        ),
        BuiltinTests.TestCase(
            description: "stop is not an integer (undefined)",
            name: "array.slice",
            args: [["a", "b", "c", "d"], 1, 3.1],
            expected: .success(.undefined)
        ),
    ]

    static var allTests: [BuiltinTests.TestCase] {
        [
            BuiltinTests.generateFailureTests(
                builtinName: "array.concat", sampleArgs: [[1, 2], [3, 4]],
                argIndex: 0, argName: "x", allowedArgTypes: ["array"],
                generateNumberOfArgsTest: true),
            BuiltinTests.generateFailureTests(
                builtinName: "array.concat", sampleArgs: [[1, 2], [3, 4]],
                argIndex: 1, argName: "y", allowedArgTypes: ["array"],
                generateNumberOfArgsTest: false),
            arrayConcatTests,
            
            BuiltinTests.generateFailureTests(
                builtinName: "array.reverse", sampleArgs: [[1, 2]],
                argIndex: 0, argName: "x", allowedArgTypes: ["array"],
                generateNumberOfArgsTest: true),
            arrayReverseTests,
            
            BuiltinTests.generateFailureTests(
                builtinName: "array.slice", sampleArgs: [[1, 2], 0, 1],
                argIndex: 0, argName: "x", allowedArgTypes: ["array"],
                generateNumberOfArgsTest: true),
            BuiltinTests.generateFailureTests(
                builtinName: "array.slice", sampleArgs: [[1, 2], 0, 1],
                argIndex: 1, argName: "start", allowedArgTypes: ["number"],
                generateNumberOfArgsTest: false),
            BuiltinTests.generateFailureTests(
                builtinName: "array.slice", sampleArgs: [[1, 2], 0, 1],
                argIndex: 2, argName: "stop", allowedArgTypes: ["number"],
                generateNumberOfArgsTest: false),
            arraySliceTests,
        ].flatMap { $0 }
    }

    @Test(arguments: allTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await BuiltinTests.testBuiltin(tc: tc)
    }
}
