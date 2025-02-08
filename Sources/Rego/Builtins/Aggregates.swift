import AST
import Foundation

extension BuiltinFuncs {
    static func count(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 1)
        }

        switch args[0] {
        case .string(let s):
            return .number(NSNumber(value: s.count))
        case .array(let a):
            return .number(NSNumber(value: a.count))
        case .object(let o):
            return .number(NSNumber(value: o.keys.count))
        case .set(let s):
            return .number(NSNumber(value: s.count))
        default:
            throw BuiltinError.argumentTypeMismatch(arg: "a", got: args[0].typeName, want: "string|array|object|set")
        }
    }
}
