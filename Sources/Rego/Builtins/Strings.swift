import AST
import Foundation

extension BuiltinFuncs {
    static func concat(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 2)
        }

        guard case .string(let delimiter) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "delimiter")
        }

        switch args[1] {
        case .array(let a):
            return try .string(
                a.map {
                    guard case .string(let s) = $0 else {
                        throw BuiltinError.argumentTypeMismatch(arg: "collection element: \($0)")
                    }
                    return s
                }.joined(separator: String(delimiter)))
        case .set(let s):
            return try .string(
                s.sorted().map {
                    guard case .string(let s) = $0 else {
                        throw BuiltinError.argumentTypeMismatch(arg: "collection element: \($0)")
                    }
                    return s
                }.joined(separator: String(delimiter)))
        default:
            throw BuiltinError.argumentTypeMismatch(arg: "collection")
        }
    }
}
