import AST
import Foundation

extension BuiltinFuncs {
    static func greaterThan(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }
        return .boolean(AST.RegoValue.compare(args[0], args[1]) == .orderedDescending)
    }

    static func greaterThanEq(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }
        let cmpResult = AST.RegoValue.compare(args[0], args[1])
        return .boolean(cmpResult == .orderedSame || cmpResult == .orderedDescending)
    }

    static func lessThan(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }
        return .boolean(AST.RegoValue.compare(args[0], args[1]) == .orderedAscending)
    }

    static func lessThanEq(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }
        let cmpResult = AST.RegoValue.compare(args[0], args[1])
        return .boolean(cmpResult == .orderedSame || cmpResult == .orderedAscending)
    }

    static func notEq(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }
        return .boolean(AST.RegoValue.compare(args[0], args[1]) != .orderedSame)
    }

    static func equal(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }
        return .boolean(AST.RegoValue.compare(args[0], args[1]) == .orderedSame)
    }
}
