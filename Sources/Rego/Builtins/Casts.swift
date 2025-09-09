import AST
import Foundation

extension BuiltinFuncs {
    static func toNumber(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
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

            // Check for NaN and Inf and Infinity
            let unsigned = s.trimmingCharacters(in: CharacterSet(charactersIn: "+-")).lowercased()
            guard unsigned != "inf", unsigned != "nan", unsigned != "infinity" else {
                throw BuiltinError.evalError(msg: "operand 0 must be valid number string, got \(s)")
            }

            // Now try to parse the amount value into a Double
            guard let x = Double(s) else {
                throw BuiltinError.evalError(msg: "operand 0 must be valid number string, got \(s)")
            }

            return .number(NSNumber(value: x))
        default:
            throw BuiltinError.argumentTypeMismatch(
                arg: "x", got: args[0].typeName, want: "boolean|null|number|string")
        }
    }

}
