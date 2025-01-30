import AST
import Foundation

extension BuiltinFuncs {
    static func bitsShiftLeft(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 1)
        }

        guard let intA = args[0].integerValue else {
            throw BuiltinError.argumentTypeMismatch(arg: "a")
        }

        guard let intB = args[1].integerValue else {
            throw BuiltinError.argumentTypeMismatch(arg: "b")
        }

        return AST.RegoValue.number(NSNumber(value: Int(intA << intB)))
    }
}
