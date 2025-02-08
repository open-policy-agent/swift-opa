import AST
import Foundation

extension BuiltinFuncs {
    static func bitsShiftLeft(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 2)
        }

        guard let intA = args[0].integerValue else {
            throw BuiltinError.argumentTypeMismatch(arg: "a", got: args[0].typeName, want: "number[integer]")
        }

        guard let intB = args[1].integerValue else {
            throw BuiltinError.argumentTypeMismatch(arg: "b", got: args[1].typeName, want: "number[integer]")
        }

        return AST.RegoValue.number(NSNumber(value: Int(intA << intB)))
    }
}
