import AST
import Foundation
import Testing

@testable import Rego

@Suite("BuiltinRegistry")
struct BuiltinRegistryTests {

    enum TestError: Error {
        case invalidArg(String)
    }

    // testBuiltin is a builtin invoked from registry tests for modeling
    // different error handling scenarios.
    // It accepts a single string argument for controlling which errors
    // to throw.
    static func testBuiltin(_ ctx: BuiltinContext, _ args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw TestError.invalidArg("testBuiltin expects one argument, got \(args.count)")
        }
        guard case .string(let errType) = args[0] else {
            throw TestError.invalidArg("testBuiltin expects one string argument, got \(args[0].typeName))")
        }

        switch errType {
        case "haltErr":
            throw BuiltinError.halt(reason: "test")
        case "evalErr":
            throw BuiltinError.evalError(msg: "test")
        case "argTypeErr":
            throw BuiltinError.argumentTypeMismatch(arg: "test", got: "test", want: "test")
        case "argCountErr":
            throw BuiltinError.argumentCountMismatch(got: 1, want: 2)
        case "undefined":
            return .undefined
        default:
            throw TestError.invalidArg("testBuiltin got an unexpected argument value '\(errType)')")
        }
    }

    // testRegistry is a registry for testing builtin error handling
    static var testRegistry: BuiltinRegistry {
        return BuiltinRegistry(builtins: [
            "__error_throwing_builtin": testBuiltin
        ])
    }

    // Verify that a halt error propagates out as an error to the caller (strict mode)
    @Test func haltPropagatesOnInvoke() async throws {
        await #expect("must throw in strict mode") {
            _ = try await BuiltinRegistryTests.testRegistry.invoke(
                withContext: .init(),
                name: "__error_throwing_builtin",
                args: [.string("haltErr")],
                strict: true
            )
        } throws: { error in
            return BuiltinError.isHaltError(error)
        }
    }

    // Verify that a halt error propagates out as an error to the caller (non-strict mode)
    @Test func haltPropagatesOnInvokeNonStrict() async throws {
        await #expect("must throw in non-strict mode") {
            _ = try await BuiltinRegistryTests.testRegistry.invoke(
                withContext: .init(),
                name: "__error_throwing_builtin",
                args: [.string("haltErr")],
                strict: false
            )
        } throws: { error in
            return BuiltinError.isHaltError(error)
        }
    }

    @Test func evalErrorDoesntPropagateWithoutStrict() async throws {
        await #expect("must throw in strict mode") {
            _ = try await BuiltinRegistryTests.testRegistry.invoke(
                withContext: .init(),
                name: "__error_throwing_builtin",
                args: [.string("evalErr")],
                strict: true
            )
        } throws: { error in
            // Sanity: it should not be a halting error
            return !BuiltinError.isHaltError(error)
        }

        // Try again, with non-strict mode
        let r = try await BuiltinRegistryTests.testRegistry.invoke(
            withContext: .init(),
            name: "__error_throwing_builtin",
            args: [.string("evalErr")],
            strict: false
        )
        #expect(r == .undefined, "must not throw in non-strict mode")
    }

    @Test func argErrorsDontPropagateWithoutStrict() async throws {
        await #expect(throws: RegoError.self, "must throw in strict mode") {
            _ = try await BuiltinRegistryTests.testRegistry.invoke(
                withContext: .init(),
                name: "__error_throwing_builtin",
                args: [.string("argCountErr")],
                strict: true
            )
        }

        let r = try await BuiltinRegistryTests.testRegistry.invoke(
            withContext: .init(),
            name: "__error_throwing_builtin",
            args: [.string("argCountErr")],
            strict: false
        )
        #expect(r == .undefined, "must not throw in non-strict mode")

        await #expect(throws: RegoError.self, "must throw in strict mode") {
            _ = try await BuiltinRegistryTests.testRegistry.invoke(
                withContext: .init(),
                name: "__error_throwing_builtin",
                args: [.string("argTypeErr")],
                strict: true
            )
        }
        let r2 = try await BuiltinRegistryTests.testRegistry.invoke(
            withContext: .init(),
            name: "__error_throwing_builtin",
            args: [.string("argTypeErr")],
            strict: false
        )
        #expect(r2 == .undefined, "must not throw in non-strict mode")
    }

    @Test func undefinedAlwaysPropagates() async throws {
        var r = try await BuiltinRegistryTests.testRegistry.invoke(
            withContext: .init(),
            name: "__error_throwing_builtin",
            args: [.string("undefined")],
            strict: true
        )
        #expect(r == .undefined, "must not throw in strict mode")

        r = try await BuiltinRegistryTests.testRegistry.invoke(
            withContext: .init(),
            name: "__error_throwing_builtin",
            args: [.string("undefined")],
            strict: false
        )
        #expect(r == .undefined, "must not throw in non-strict mode")
    }
}
