import AST
import Foundation

extension BuiltinFuncs {
    // memberOf is a membership check - memberOf(x: any, y: any) checks if y in x
    // For objects, we are checking the values, not the keys.
    static func isMemberOf(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 2)
        }

        switch args[1] {
        case .set(let set):
            return .boolean(set.contains(args[0]))
        case .array(let arr):
            return .boolean(arr.contains(args[0]))
        case .object(let obj):
            return .boolean(obj.values.contains(args[0]))
        default:
            return .boolean(false)
        }
    }
}
