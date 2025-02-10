import AST
import Foundation

extension BuiltinFuncs {
    static func isArray(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 1)
        }

        guard case .array(_) = args[0] else {
            return .boolean(false)
        }

        return .boolean(true)
    }

    static func isBoolean(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 1)
        }

        guard case .boolean(_) = args[0] else {
            return .boolean(false)
        }

        return .boolean(true)
    }

    static func isNull(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 1)
        }

        return .boolean(args[0] == .null)
    }

    static func isNumber(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 1)
        }

        guard case .number(_) = args[0] else {
            return .boolean(false)
        }

        return .boolean(true)
    }

    static func isObject(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 1)
        }

        guard case .object(_) = args[0] else {
            return .boolean(false)
        }

        return .boolean(true)
    }

    static func isSet(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 1)
        }

        guard case .set(_) = args[0] else {
            return .boolean(false)
        }

        return .boolean(true)
    }

    static func isString(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 1)
        }

        guard case .string(_) = args[0] else {
            return .boolean(false)
        }

        return .boolean(true)
    }

    static func typeName(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 1)
        }

        return .string(args[0].typeName)
    }
}
