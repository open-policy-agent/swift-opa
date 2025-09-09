import AST
import Foundation

extension BuiltinFuncs {

    static func objectGet(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 3 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 3)
        }

        guard case .object(let object) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "object", got: args[0].typeName, want: "object")
        }

        let key = args[1]
        let defaultValue = args[2]

        switch key {
        case .array(let keyPath):
            // For an array "key" we treat it as a path into the object..
            // Copying behavior from upstream OPA, an empty array should return the whole object
            var current: AST.RegoValue = .object(object)
            for key in keyPath {
                switch current {
                case .array(let arr):
                    guard case .number(let idx) = key else {
                        return defaultValue
                    }
                    guard !key.isFloat else {
                        return defaultValue
                    }
                    let i = idx.intValue
                    // Bounds check
                    guard i >= 0 && i < arr.count else {
                        return defaultValue
                    }
                    current = arr[i]
                case .object(let currentObj):
                    guard let next = currentObj[key] else {
                        return defaultValue
                    }
                    current = next
                case .set(let set):
                    guard set.contains(key) else {
                        return defaultValue
                    }
                    current = key
                default:
                    return defaultValue
                }
            }
            return current

        default:
            // Scalar keys - simple lookup
            guard let value = object[key] else {
                return defaultValue
            }
            return value
        }
    }

    static func objectKeys(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        guard case .object(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "object", got: args[0].typeName, want: "object")
        }

        return .set(Set(x.keys))
    }
}
