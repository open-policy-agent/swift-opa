import AST
import Foundation

extension BuiltinFuncs {
    static func concat(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 2)
        }

        guard case .string(let delimiter) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "delimiter")
        }

        switch args[1] {
        case .array(let a):
            return try .string(
                a.map {
                    guard case .string(let s) = $0 else {
                        throw BuiltinError.argumentTypeMismatch(arg: "collection element: \($0)")
                    }
                    return s
                }.joined(separator: String(delimiter)))
        case .set(let s):
            return try .string(
                s.sorted().map {
                    guard case .string(let s) = $0 else {
                        throw BuiltinError.argumentTypeMismatch(arg: "collection element: \($0)")
                    }
                    return s
                }.joined(separator: String(delimiter)))
        default:
            throw BuiltinError.argumentTypeMismatch(arg: "collection")
        }
    }

    static func contains(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 2)
        }

        guard case .string(let haystack) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "haystack")
        }

        guard case .string(let needle) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "needle")
        }

        // Special logic to mimic the Go strings.Contains() behavior for empty strings..
        if needle.isEmpty {
            return .boolean(true)
        }
        return .boolean(haystack.contains(needle))
    }

    static func endsWith(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 2)
        }

        guard case .string(let search) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "search")
        }

        guard case .string(let base) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "base")
        }

        return .boolean(search.hasSuffix(base))
    }
}
