import AST
import Foundation

extension BuiltinFuncs {
    static func count(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        guard let len = args[0].count else {
            throw BuiltinError.argumentTypeMismatch(
                arg: "collection", got: args[0].typeName, want: "string|array|object|set")
        }

        return .number(NSNumber(value: len))
    }

    static func max(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        switch args[0] {
        case .array(let a):
            return a.max() ?? .undefined
        case .set(let s):
            return s.max() ?? .undefined
        default:
            throw BuiltinError.argumentTypeMismatch(
                arg: "collection", got: args[0].typeName, want: "array|set")
        }
    }

    static func min(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        switch args[0] {
        case .array(let a):
            return a.min() ?? .undefined
        case .set(let s):
            return s.min() ?? .undefined
        default:
            throw BuiltinError.argumentTypeMismatch(
                arg: "collection", got: args[0].typeName, want: "array|set")
        }
    }
}
