import AST
import Foundation

extension BuiltinFuncs {
    static func and(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 2)
        }

        guard case .set(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x")
        }

        guard case .set(let y) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "y")
        }

        return .set(x.intersection(y))
    }

    static func intersection(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 1)
        }

        guard case .set(let inputSet) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "xs")
        }

        guard !inputSet.isEmpty else {
            return .set([])
        }

        var result: Set<AST.RegoValue>? = nil
        for x in inputSet {
            guard case .set(let s) = x else {
                throw BuiltinError.argumentTypeMismatch(arg: "xs")
            }
            result = result?.intersection(s) ?? s
        }

        guard let result = result else {
            return .undefined
        }

        return .set(result)
    }

    static func or(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 2)
        }

        guard case .set(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x")
        }

        guard case .set(let y) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "y")
        }

        return .set(x.union(y))
    }

    static func union(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 1)
        }

        guard case .set(let inputSet) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "xs")
        }

        guard !inputSet.isEmpty else {
            return .set([])
        }

        var result: Set<AST.RegoValue>? = nil
        for x in inputSet {
            guard case .set(let s) = x else {
                throw BuiltinError.argumentTypeMismatch(arg: "xs")
            }
            result = result?.union(s) ?? s
        }

        guard let result = result else {
            return .undefined
        }

        return .set(result)
    }
}
