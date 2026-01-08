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
            description: "Custom Builtin - not enough args",
            name: "custom_plus",
            args: [1],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 1, want: 2)),
            builtinRegistry: Self.customPlusBuiltinRegistry
        ),
        BuiltinTests.TestCase(
            description: "Custom Builtin - too many args",
            name: "custom_plus",
            args: [1, 1, 1],
            expected: .failure(BuiltinError.argumentCountMismatch(got: 3, want: 2)),
            builtinRegistry: Self.customPlusBuiltinRegistry
        ),
        BuiltinTests.TestCase(
            description: "Custom Builtin - wrong lhs arg type",
            name: "custom_plus",
            args: ["1", 1],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "x", got: "string", want: "number")),
            builtinRegistry: Self.customPlusBuiltinRegistry
        ),
        BuiltinTests.TestCase(
            description: "Custom Builtin - wrong rhs arg type",
            name: "custom_plus",
            args: [1, "1"],
            expected: .failure(BuiltinError.argumentTypeMismatch(arg: "y", got: "string", want: "number")),
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

    @Test(arguments: Self.customBuiltinTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await BuiltinTests.testBuiltin(tc: tc, builtinRegistry: tc.builtinRegistry)
    }
}
