import AST
import Foundation
import Testing

@testable import Rego

@Suite("BuiltinRegistry")
struct BuiltinRegistryTests {

    enum TestError: Error {
        case invalidArg(String)
    }

    static func testBuiltin(_ ctx: BuiltinContext, _ args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw TestError.invalidArg("testBuiltin expects one argument, got \(args.count)")
        }
        guard case .string(let errType) = args[0] else {
            throw TestError.invalidArg("testBuiltin expects one string argument, got \(args[0].typeName))")
        }

        switch errType {
        case "haltErr":
            throw BuiltinFuncs.BuiltinError.halt(reason: "test")
        case "evalErr":
            throw BuiltinFuncs.BuiltinError.evalError(msg: "test")
        case "argTypeErr":
            throw BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "test", got: "test", want: "test")
        case "argCountErr":
            throw BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 1, expected: 2)
        case "undefined":
            return .undefined
        default:
            throw TestError.invalidArg("testBuiltin got an unexpected argument value '\(errType)')")
        }
    }

    static var testRegistry: BuiltinRegistry {
        return BuiltinRegistry(builtins: [
            "__error_throwing_builtin": testBuiltin
        ])
    }

    @Test func haltPropagatesOnInvoke() async throws {
        await #expect(throws: BuiltinFuncs.BuiltinError.halt(reason: "test"), "must throw in strict mode") {
            _ = try await BuiltinRegistryTests.testRegistry.invoke(
                withCtx: .init(),
                name: "__error_throwing_builtin",
                args: [.string("haltErr")],
                strict: true
            )
        }
        await #expect(throws: BuiltinFuncs.BuiltinError.halt(reason: "test"), "must throw in non-strict mode") {
            _ = try await BuiltinRegistryTests.testRegistry.invoke(
                withCtx: .init(),
                name: "__error_throwing_builtin",
                args: [.string("haltErr")],
                strict: false
            )
        }
    }

    @Test func evalErrorDoesntPropagateWithoutStrict() async throws {
        await #expect(throws: BuiltinFuncs.BuiltinError.evalError(msg: "test"), "must throw in strict mode") {
            _ = try await BuiltinRegistryTests.testRegistry.invoke(
                withCtx: .init(),
                name: "__error_throwing_builtin",
                args: [.string("evalErr")],
                strict: true
            )
        }
        let r = try await BuiltinRegistryTests.testRegistry.invoke(
            withCtx: .init(),
            name: "__error_throwing_builtin",
            args: [.string("evalErr")],
            strict: false
        )
        #expect(r == .undefined, "must not throw in non-strict mode")
    }

    @Test func argErrorsDontPropagateWithoutStrict() async throws {
        await #expect(
            throws: BuiltinFuncs.BuiltinError.argumentCountMismatch(got: 1, expected: 2), "must throw in strict mode"
        ) {
            _ = try await BuiltinRegistryTests.testRegistry.invoke(
                withCtx: .init(),
                name: "__error_throwing_builtin",
                args: [.string("argCountErr")],
                strict: true
            )
        }
        let r = try await BuiltinRegistryTests.testRegistry.invoke(
            withCtx: .init(),
            name: "__error_throwing_builtin",
            args: [.string("argCountErr")],
            strict: false
        )
        #expect(r == .undefined, "must not throw in non-strict mode")

        await #expect(
            throws: BuiltinFuncs.BuiltinError.argumentTypeMismatch(arg: "test", got: "test", want: "test"),
            "must throw in strict mode"
        ) {
            _ = try await BuiltinRegistryTests.testRegistry.invoke(
                withCtx: .init(),
                name: "__error_throwing_builtin",
                args: [.string("argTypeErr")],
                strict: true
            )
        }
        let r2 = try await BuiltinRegistryTests.testRegistry.invoke(
            withCtx: .init(),
            name: "__error_throwing_builtin",
            args: [.string("argTypeErr")],
            strict: false
        )
        #expect(r2 == .undefined, "must not throw in non-strict mode")
    }

    @Test func undefinedAlwaysPropagates() async throws {
        var r = try await BuiltinRegistryTests.testRegistry.invoke(
            withCtx: .init(),
            name: "__error_throwing_builtin",
            args: [.string("undefined")],
            strict: true
        )
        #expect(r == .undefined, "must not throw in strict mode")

        r = try await BuiltinRegistryTests.testRegistry.invoke(
            withCtx: .init(),
            name: "__error_throwing_builtin",
            args: [.string("undefined")],
            strict: false
        )
        #expect(r == .undefined, "must not throw in non-strict mode")
    }
}
