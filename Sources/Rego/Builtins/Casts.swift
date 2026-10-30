import AST
import Foundation

extension BuiltinFuncs {
    static func toNumber(ctx: BuiltinContext, args: [AST.RegoValue]) throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }
        switch args[0] {
        case .boolean(let v):
            return v ? 1 : 0
        case .null:
            return 0
        case .number(_):
            return args[0]
        case .string(let s):
            // For compatibility with Go, we do not allow leading pluses
            guard !s.hasPrefix("+") else {
                throw BuiltinError.evalError(
                    msg: "operand 0 must be valid number string NOT starting with + sign, got \(s)")
            }

            // Reject embedded NULs (Double stops parsing at the first one), and values
            // RegoNumber maps to Decimal.nan (non-finite, or unrepresentable as Decimal).
            guard !s.utf8.contains(0), let n = Double(s).map(RegoNumber.init(value:)), !n.decimalValue.isNaN else {
                throw BuiltinError.evalError(msg: "operand 0 must be valid number string, got \(s)")
            }

            return .number(n)
        default:
            throw BuiltinError.argumentTypeMismatch(
                arg: "x", got: args[0].typeName, want: "any<boolean, null, number, string>")
        }
    }

}
