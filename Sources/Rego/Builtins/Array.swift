import AST
import Foundation

extension BuiltinFuncs {
    static func arrayConcat(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        // x: array - the first array
        // y: array - the second array
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 2)
        }
        guard case .array(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x")
        }
        guard case .array(let y) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "y")
        }

        return .array(x + y)
    }
}
