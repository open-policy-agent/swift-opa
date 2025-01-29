import AST
import Foundation

enum BuiltinFuncs {
    enum BuiltinError: Error {
        case argumentCountMismatch(got: Int, expected: Int)
        case argumentTypeMismatch(arg: String)
    }

    static func arrayConcat(args: [AST.RegoValue]) async throws -> AST.RegoValue {
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

    // memberOf is a membership check - memberOf(x: any, y: any) checks if y in x
    // For objects, we are checking the values, not the keys.
    static func isMemberOf(args: [AST.RegoValue]) async throws -> AST.RegoValue {
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
