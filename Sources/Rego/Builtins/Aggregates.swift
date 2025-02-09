import AST
import Foundation

extension BuiltinFuncs {
    static func count(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 1)
        }

        guard let len = args[0].count else {
            throw BuiltinError.argumentTypeMismatch(arg: "a", got: args[0].typeName, want: "string|array|object|set")
        }

        return .number(NSNumber(value: len))
    }
}
