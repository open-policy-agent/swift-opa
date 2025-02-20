import AST
import Foundation

extension BuiltinFuncs {
    static func and(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 2)
        }

        guard case .set(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "set")
        }

        guard case .set(let y) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "y", got: args[1].typeName, want: "set")
        }

        return .set(x.intersection(y))
    }

    // intersection returns the intersection of the given input sets
    // args
    // xs: set of sets to intersect
    // returns: the intersection of all `xs` sets
    static func intersection(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 1)
        }

        guard case .set(let inputSet) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "xs", got: args[0].typeName, want: "set")
        }

        guard !inputSet.isEmpty else {
            return .set([])
        }

        var result: Set<AST.RegoValue>? = nil
        for (i, x) in inputSet.enumerated() {
            guard case .set(let s) = x else {
                throw BuiltinError.argumentTypeMismatch(arg: "xs[\(i)]", got: x.typeName, want: "set")
            }
            result = result?.intersection(s) ?? s
        }

        guard let result = result else {
            // This shouldn't happen, we checked earlier to ensure inputSet wasn't empty,
            // but just in case we somehow make it down here we'll bail out with an empty
            // set (again).
            return .set([])
        }

        return .set(result)
    }

    static func or(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 2)
        }

        guard case .set(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "set")
        }

        guard case .set(let y) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "y", got: args[1].typeName, want: "set")
        }

        return .set(x.union(y))
    }

    // union returns the union of the given input sets
    // args
    // xs: set of sets to merge
    // returns: the union of all `xs` sets
    static func union(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 1)
        }

        guard case .set(let inputSet) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "xs", got: args[0].typeName, want: "set")
        }

        guard !inputSet.isEmpty else {
            return .set([])
        }

        var result: Set<AST.RegoValue> = []
        for (i, x) in inputSet.enumerated() {
            guard case .set(let s) = x else {
                throw BuiltinError.argumentTypeMismatch(arg: "xs[\(i)]", got: x.typeName, want: "set")
            }
            result = result.union(s)
        }

        return .set(result)
    }
}
