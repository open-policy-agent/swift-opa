import AST
import Foundation
import Testing

@testable import Rego

extension BuiltinTests {
    @Suite("CustomBuiltinTests", .tags(.builtins))
    struct CustomBuiltinTests {}
}

extension BuiltinTests.CustomBuiltinTests {
    static let customPlusBuiltinRegistry: BuiltinRegistry =
        .init(
            builtins: [
                "custom_plus": { ctx, args in
                    guard args.count == 2 else {
                        throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
                    }

                    guard case .number(let x) = args[0] else {
                        throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "number")
                    }

                    guard case .number(let y) = args[1] else {
                        throw BuiltinError.argumentTypeMismatch(arg: "y", got: args[1].typeName, want: "number")
                    }

                    return .number(NSDecimalNumber(decimal: x.decimalValue + y.decimalValue))
                }
            ]
        )

    // The testcases for too many/too few arguments, and for checking
    // failures for wrong-typed arguments use the generateFailureTests
    // infrastructure, using the custom registry providing this builtin.
    // All other cases of interest are covered here.
    static let customBuiltinTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "Custom Builtin - 1 + 1",
            name: "custom_plus",
            args: [1, 1],
            expected: .success(2),
            builtinRegistry: Self.customPlusBuiltinRegistry
        ),
        BuiltinTests.TestCase(
            description: "Custom Builtin - 1.33333 + 1.33333",
            name: "custom_plus",
            args: [1.33333, 1.33333],
            expected: .success(2.66666),
            builtinRegistry: Self.customPlusBuiltinRegistry
        ),
        BuiltinTests.TestCase(
            description: "Custom Builtin - not existent",
            name: "custom_plus2",  // does not exist
            args: [1, 1],
            expected: .failure(BuiltinRegistry.RegistryError.builtinNotFound(name: "custom_plus2")),
            builtinRegistry: Self.customPlusBuiltinRegistry
        ),

    ]

    static var allTests: [BuiltinTests.TestCase] {
        [
            BuiltinTests.generateFailureTests(
                builtinName: "custom_plus", sampleArgs: [1, 1],
                argIndex: 0, argName: "x",
                allowedArgTypes: ["number"],
                wantArgs: "number",
                generateNumberOfArgsTest: true,
                builtinRegistry: Self.customPlusBuiltinRegistry),
            BuiltinTests.generateFailureTests(
                builtinName: "custom_plus", sampleArgs: [1, 1],
                argIndex: 1, argName: "y",
                allowedArgTypes: ["number"],
                wantArgs: "number",
                generateNumberOfArgsTest: false,
                builtinRegistry: Self.customPlusBuiltinRegistry),
            customBuiltinTests,
        ].flatMap { $0 }
    }

    @Test(arguments: Self.allTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await BuiltinTests.testBuiltin(tc: tc, builtinRegistry: tc.builtinRegistry)
    }
}
