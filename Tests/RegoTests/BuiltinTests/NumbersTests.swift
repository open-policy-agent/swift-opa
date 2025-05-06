import AST
import Foundation
import Testing

@testable import Rego

extension BuiltinTests {
    @Suite("BuiltinTests - Numbers", .tags(.builtins))
    struct NumbersTests {}
}

extension BuiltinTests.NumbersTests {
    static let rangeTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "when a = b",
            name: "numbers.range",
            args: [1, 1],
            expected: .success([1])
        ),
        BuiltinTests.TestCase(
            description: "when a < b",
            name: "numbers.range",
            args: [1, 3],
            expected: .success([1, 2, 3])
        ),
        BuiltinTests.TestCase(
            description: "when a > b",
            name: "numbers.range",
            args: [3, 1],
            expected: .success([3, 2, 1])
        ),
        BuiltinTests.TestCase(
            description: "with a is not an integer",
            name: "numbers.range",
            args: [1.2, 3],
            expected: .failure(
                BuiltinError.evalError(
                    msg: "operand 1 must be integer number but got floating-point number"))
        ),
        BuiltinTests.TestCase(
            description: "when b is not an integer",
            name: "numbers.range",
            args: [1, 3.14],
            expected: .failure(
                BuiltinError.evalError(
                    msg: "operand 2 must be integer number but got floating-point number"))
        ),
        BuiltinTests.TestCase(
            description: "when a and b are floats with integer value",
            name: "numbers.range",
            args: [1.0000, 3.0000],
            expected: .success([1, 2, 3])
        ),
    ]

    static let rangeStepTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "when a = b",
            name: "numbers.range_step",
            args: [1, 1, 5],
            expected: .success([1])
        ),
        BuiltinTests.TestCase(
            description: "when a < b",
            name: "numbers.range_step",
            args: [1, 10, 3],
            expected: .success([1, 4, 7, 10])
        ),
        BuiltinTests.TestCase(
            description: "when a < b with large step",
            name: "numbers.range_step",
            args: [1, 10, 200],
            expected: .success([1])
        ),
        BuiltinTests.TestCase(
            description: "when a > b",
            name: "numbers.range_step",
            args: [4, -4, 2],
            expected: .success([4, 2, 0, -2, -4])
        ),
        BuiltinTests.TestCase(
            description: "when a > b with large step",
            name: "numbers.range_step",
            args: [2, 0, 100],
            expected: .success([2])
        ),
        BuiltinTests.TestCase(
            description: "with a is not an integer",
            name: "numbers.range_step",
            args: [1.2, 3, 1],
            expected: .failure(
                BuiltinError.evalError(
                    msg: "operand 1 must be integer number but got floating-point number"))
        ),
        BuiltinTests.TestCase(
            description: "when b is not an integer",
            name: "numbers.range_step",
            args: [1, 3.14, 1],
            expected: .failure(
                BuiltinError.evalError(
                    msg: "operand 2 must be integer number but got floating-point number"))
        ),
        BuiltinTests.TestCase(
            description: "when step < 0",
            name: "numbers.range_step",
            args: [3, 1, -1],
            expected: .failure(
                BuiltinError.evalError(
                    msg: "step must be a positive integer"))
        ),
        BuiltinTests.TestCase(
            description: "when step is not an integer",
            name: "numbers.range_step",
            args: [1, 3, 1.5],
            expected: .failure(
                BuiltinError.evalError(
                    msg: "step must be integer number but got floating-point number"))
        ),
        BuiltinTests.TestCase(
            description: "when a, b and step are floats with integer value",
            name: "numbers.range_step",
            args: [1.0000, 10.000, 3.00],
            expected: .success([1, 4, 7, 10])
        ),
    ]

    static var allTests: [BuiltinTests.TestCase] {
        [
            BuiltinTests.generateFailureTests(
                builtinName: "numbers.range", sampleArgs: [1, 1], argIndex: 0, argName: "a",
                allowedArgTypes: ["number"],
                generateNumberOfArgsTest: true),
            BuiltinTests.generateFailureTests(
                builtinName: "numbers.range", sampleArgs: [1, 1], argIndex: 1, argName: "b",
                allowedArgTypes: ["number"],
                generateNumberOfArgsTest: false),
            rangeTests,

            BuiltinTests.generateFailureTests(
                builtinName: "numbers.range_step", sampleArgs: [1, 1, 1], argIndex: 0, argName: "a",
                allowedArgTypes: ["number"],
                generateNumberOfArgsTest: true),
            BuiltinTests.generateFailureTests(
                builtinName: "numbers.range_step", sampleArgs: [1, 1, 1], argIndex: 1, argName: "b",
                allowedArgTypes: ["number"],
                generateNumberOfArgsTest: false),
            BuiltinTests.generateFailureTests(
                builtinName: "numbers.range_step", sampleArgs: [1, 1, 1], argIndex: 2, argName: "step",
                allowedArgTypes: ["number"],
                generateNumberOfArgsTest: false),
            rangeStepTests,
        ].flatMap { $0 }
    }

    @Test(arguments: allTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await BuiltinTests.testBuiltin(tc: tc)
    }

}
