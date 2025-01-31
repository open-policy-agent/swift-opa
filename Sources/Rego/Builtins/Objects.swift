import AST
import Foundation

extension BuiltinFuncs {

    static func objectGet(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 3 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 3)
        }

        guard case .object(let object) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "object")
        }

        let key = args[1]
        let defaultValue = args[2]

        switch key {
        case .array(let keyPath):
            // For an array "key" we treat it as a path into the object..
            // Copying behavior from upstream OPA, an empty array should return the whole object
            var current: AST.RegoValue = .object(object)
            for key in keyPath {
                guard case .object(let currentObj) = current else {
                    return defaultValue
                }
                guard let next = currentObj[key] else {
                    return defaultValue
                }
                current = next
            }
            return current
        default:
            guard let value = object[key] else {
                return defaultValue
            }
            return value
        }
    }

    static func objectKeys(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 2)
        }

        guard case .object(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "object")
        }

        return .set(Set(x.keys))
    }
}
