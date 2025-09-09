import AST
import Foundation
import Testing

@testable import Rego

extension BuiltinTests {
    @Suite("BuiltinTests - Casts", .tags(.builtins))
    struct CastsTests {}
}

extension BuiltinTests.CastsTests {
    static let toNumberTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "NaN is not allowed",
            name: "to_number",
            args: [.string("NaN")],
            expected: .failure(
                BuiltinError.evalError(
                    msg: "operand 0 must be valid number string, got NaN"))
        ),
        BuiltinTests.TestCase(
            description: "Infinity is not allowed",
            name: "to_number",
            args: [.string("Infinity")],
            expected: .failure(
                BuiltinError.evalError(
                    msg: "operand 0 must be valid number string, got Infinity"))
        ),
        BuiltinTests.TestCase(
            description: "Inf is not allowed",
            name: "to_number",
            args: [.string("Inf")],
            expected: .failure(
                BuiltinError.evalError(
                    msg: "operand 0 must be valid number string, got Inf"))
        ),
        BuiltinTests.TestCase(
            description: "leading whitespace not allowed",
            name: "to_number",
            args: [.string("  123")],
            expected: .failure(
                BuiltinError.evalError(
                    msg: "operand 0 must be valid number string, got   123"))
        ),
        BuiltinTests.TestCase(
            description: "trailing whitespace not allowed",
            name: "to_number",
            args: [.string("123  ")],
            expected: .failure(
                BuiltinError.evalError(
                    msg: "operand 0 must be valid number string, got 123  "))
        ),
        BuiltinTests.TestCase(
            description: "simple integer",
            name: "to_number",
            args: [.string("42")],
            expected: .success(.number(42))
        ),
        BuiltinTests.TestCase(
            description: "scientific notation",
            name: "to_number",
            args: [.string("2.998e8")],
            expected: .success(.number(2.998e8))
        ),
        BuiltinTests.TestCase(
            description: "leading minus is allowed",
            name: "to_number",
            args: [.string("-123")],
            expected: .success(.number(-123))
        ),
        BuiltinTests.TestCase(
            description: "floating point",
            name: "to_number",
            args: [.string("3.141592657")],
            expected: .success(.number(3.141592657))
        ),
        BuiltinTests.TestCase(
            description: "negative floating point",
            name: "to_number",
            args: [.string("-3.141592657")],
            expected: .success(.number(-3.141592657))
        ),
        BuiltinTests.TestCase(
            description: "null",
            name: "to_number",
            args: [.null],
            expected: .success(0)
        ),
        BuiltinTests.TestCase(
            description: "false",
            name: "to_number",
            args: [false],
            expected: .success(0)
        ),
        BuiltinTests.TestCase(
            description: "true",
            name: "to_number",
            args: [true],
            expected: .success(1)
        ),
        BuiltinTests.TestCase(
            description: "leading plus not allowed",
            name: "to_number",
            args: [.string("+123")],
            expected: .failure(
                BuiltinError.evalError(
                    msg: "operand 0 must be valid number string NOT starting with + sign, got +123"))
        ),
        BuiltinTests.TestCase(
            description: "double leading plus not allowed",
            name: "to_number",
            args: [.string("++123")],
            expected: .failure(
                BuiltinError.evalError(
                    msg: "operand 0 must be valid number string NOT starting with + sign, got ++123"))
        ),
        BuiltinTests.TestCase(
            description: "leading minus plus is not allowed",
            name: "to_number",
            args: [.string("-+123")],
            expected: .failure(
                BuiltinError.evalError(
                    msg: "operand 0 must be valid number string, got -+123"))
        ),
        BuiltinTests.TestCase(
            description: "leading plus with non-digit is not allowed",
            name: "to_number",
            args: [.string("+1a")],
            expected: .failure(
                BuiltinError.evalError(
                    msg: "operand 0 must be valid number string NOT starting with + sign, got +1a"))
        ),
    ]

    static var allTests: [BuiltinTests.TestCase] {
        [
            BuiltinTests.generateFailureTests(
                builtinName: "to_number", sampleArgs: ["0"], argIndex: 0, argName: "x",
                allowedArgTypes: ["boolean", "null", "number", "string"],
                generateNumberOfArgsTest: true),
            toNumberTests,
        ].flatMap { $0 }
    }

    @Test(arguments: allTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await BuiltinTests.testBuiltin(tc: tc)
    }
}
