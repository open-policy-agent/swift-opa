import AST
import Foundation
import Testing

@testable import Rego

extension BuiltinTests {
    @Suite("BuiltinTests - Bits", .tags(.builtins))
    struct BitsTests {}
}

extension BuiltinTests.BitsTests {
    static let bitsShiftLeftTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "0 << 0",
            name: "bits.lsh",
            args: [0, 0],
            expected: .success(.number(0))
        ),
        BuiltinTests.TestCase(
            description: "1 << 1",
            name: "bits.lsh",
            args: [1, 1],
            expected: .success(.number(2))
        ),
        BuiltinTests.TestCase(
            description: "1 << 7",
            name: "bits.lsh",
            args: [1, 7],
            expected: .success(.number(NSNumber(value: Int(1 << 7))))
        ),
        BuiltinTests.TestCase(
            description: "1 << 33",
            name: "bits.lsh",
            args: [1, 33],
            expected: .success(.number(NSNumber(value: Int(1 << 33))))
        ),
        BuiltinTests.TestCase(
            description: "1 << 64",
            name: "bits.lsh",
            args: [1, 64],
            expected: .success(.number(NSNumber(value: Int(1 << 64))))
        ),
        BuiltinTests.TestCase(
            description: "1 << 65",
            name: "bits.lsh",
            args: [1, 65],
            expected: .success(.number(NSNumber(value: 0)))
        ),
        BuiltinTests.TestCase(
            description: "-255 << 2",
            name: "bits.lsh",
            args: [-255, 2],
            expected: .success(.number(NSNumber(value: -1020)))
        ),
        BuiltinTests.TestCase(
            description: "9_223_372_036_854_775_807 << 1",
            name: "bits.lsh",
            args: [9_223_372_036_854_775_807, 1],
            expected: .success(.number(NSNumber(value: UInt64(18_446_744_073_709_551_614))))
        ),
        BuiltinTests.TestCase(
            description: "second argument cannot be negative",
            name: "bits.lsh",
            args: [1, -1],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "b"))
        ),
        BuiltinTests.TestCase(
            description: "second argument cannot be non-integer",
            name: "bits.lsh",
            args: [100, 1.5],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "b"))
        ),
    ]

    static let bitsShiftRightTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "0 >> 0",
            name: "bits.rsh",
            args: [0, 0],
            expected: .success(.number(0))
        ),
        BuiltinTests.TestCase(
            description: "8 >> 3",
            name: "bits.rsh",
            args: [8, 3],
            expected: .success(.number(NSNumber(value: Int(8 >> 3))))
        ),
        BuiltinTests.TestCase(
            description: "7 >> 1",
            name: "bits.rsh",
            args: [7, 1],
            expected: .success(.number(NSNumber(value: Int(7 >> 1))))
        ),
        BuiltinTests.TestCase(
            description: "5 >> 33",
            name: "bits.rsh",
            args: [5, 33],
            expected: .success(.number(NSNumber(value: Int(5 >> 33))))
        ),
        BuiltinTests.TestCase(
            description: "-1020 >> 2",
            name: "bits.rsh",
            args: [-1020, 2],
            expected: .success(.number(NSNumber(value: -255)))
        ),
        BuiltinTests.TestCase(
            description: "second argument cannot be negative",
            name: "bits.rsh",
            args: [1, -1],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "b"))
        ),
        BuiltinTests.TestCase(
            description: "second argument cannot be non-integer",
            name: "bits.rsh",
            args: [100, 1.5],
            expected: .failure(BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "b"))
        ),
    ]

    static let bitsAndTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "42 & 28",
            name: "bits.and",
            args: [42, 28],
            expected: .success(.number(NSNumber(value: 42 & 28)))
        ),
        BuiltinTests.TestCase(
            description: "a must be an integer",
            name: "bits.and",
            args: [42.5, 28],
            expected: .failure(
                BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "a", got: "number", want: "number[integer]"))
        ),
        BuiltinTests.TestCase(
            description: "b must be an integer",
            name: "bits.and",
            args: [42, 28.3],
            expected: .failure(
                BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "b", got: "number", want: "number[integer]"))
        ),
    ]

    static let bitsOrTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "42 | 28",
            name: "bits.or",
            args: [42, 28],
            expected: .success(.number(NSNumber(value: 42 | 28)))
        ),
        BuiltinTests.TestCase(
            description: "a must be an integer",
            name: "bits.or",
            args: [42.5, 28],
            expected: .failure(
                BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "a", got: "number", want: "number[integer]"))
        ),
        BuiltinTests.TestCase(
            description: "b must be an integer",
            name: "bits.or",
            args: [42, 28.3],
            expected: .failure(
                BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "b", got: "number", want: "number[integer]"))
        ),
    ]

    static let bitsXorTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "42 ^ 28",
            name: "bits.xor",
            args: [42, 28],
            expected: .success(.number(NSNumber(value: 42 ^ 28)))
        ),
        BuiltinTests.TestCase(
            description: "a must be an integer",
            name: "bits.xor",
            args: [42.5, 28],
            expected: .failure(
                BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "a", got: "number", want: "number[integer]"))
        ),
        BuiltinTests.TestCase(
            description: "b must be an integer",
            name: "bits.xor",
            args: [42, 28.3],
            expected: .failure(
                BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "b", got: "number", want: "number[integer]"))
        ),
    ]

    static let bitsNegateTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "~42",
            name: "bits.negate",
            args: [42],
            expected: .success(.number(NSNumber(value: ~42)))
        ),
        BuiltinTests.TestCase(
            description: "a must be an integer",
            name: "bits.negate",
            args: [42.5],
            expected: .failure(
                BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "a", got: "number", want: "number[integer]"))
        ),
    ]

    static var allTests: [BuiltinTests.TestCase] {
        [
            BuiltinTests.generateFailureTests(
                builtinName: "bits.lsh", sampleArgs: [1, 1], argIndex: 0, argName: "a", allowedArgTypes: ["number"],
                generateNumberOfArgsTest: true),
            BuiltinTests.generateFailureTests(
                builtinName: "bits.lsh", sampleArgs: [1, 1], argIndex: 1, argName: "b", allowedArgTypes: ["number"],
                generateNumberOfArgsTest: false),
            bitsShiftLeftTests,

            BuiltinTests.generateFailureTests(
                builtinName: "bits.rsh", sampleArgs: [1, 1], argIndex: 0, argName: "a", allowedArgTypes: ["number"],
                generateNumberOfArgsTest: true),
            BuiltinTests.generateFailureTests(
                builtinName: "bits.rsh", sampleArgs: [1, 1], argIndex: 1, argName: "b", allowedArgTypes: ["number"],
                generateNumberOfArgsTest: false),
            bitsShiftRightTests,

            BuiltinTests.generateFailureTests(
                builtinName: "bits.and", sampleArgs: [1, 1], argIndex: 0, argName: "a", allowedArgTypes: ["number"],
                generateNumberOfArgsTest: true),
            BuiltinTests.generateFailureTests(
                builtinName: "bits.and", sampleArgs: [1, 1], argIndex: 1, argName: "b", allowedArgTypes: ["number"],
                generateNumberOfArgsTest: false),
            bitsAndTests,

            BuiltinTests.generateFailureTests(
                builtinName: "bits.or", sampleArgs: [1, 1], argIndex: 0, argName: "a", allowedArgTypes: ["number"],
                generateNumberOfArgsTest: true),
            BuiltinTests.generateFailureTests(
                builtinName: "bits.or", sampleArgs: [1, 1], argIndex: 1, argName: "b", allowedArgTypes: ["number"],
                generateNumberOfArgsTest: false),
            bitsOrTests,

            BuiltinTests.generateFailureTests(
                builtinName: "bits.xor", sampleArgs: [1, 1], argIndex: 0, argName: "a", allowedArgTypes: ["number"],
                generateNumberOfArgsTest: true),
            BuiltinTests.generateFailureTests(
                builtinName: "bits.xor", sampleArgs: [1, 1], argIndex: 1, argName: "b", allowedArgTypes: ["number"],
                generateNumberOfArgsTest: false),
            bitsXorTests,

            BuiltinTests.generateFailureTests(
                builtinName: "bits.negate", sampleArgs: [1], argIndex: 0, argName: "a", allowedArgTypes: ["number"],
                generateNumberOfArgsTest: true),
            bitsNegateTests,
        ].flatMap { $0 }
    }

    @Test(arguments: allTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await BuiltinTests.testBuiltin(tc: tc)
    }

}
