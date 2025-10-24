import AST
import Foundation

extension BuiltinFuncs {
    static func count(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        guard let len = args[0].count else {
            throw BuiltinError.argumentTypeMismatch(
                arg: "collection", got: args[0].typeName, want: "any<array, object, set, string>")
        }

        return .number(NSNumber(value: len))
    }

    static func max(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        switch args[0] {
        case .array(let a):
            return a.max() ?? .undefined
        case .set(let s):
            return s.max() ?? .undefined
        default:
            throw BuiltinError.argumentTypeMismatch(
                arg: "collection", got: args[0].typeName, want: "any<array[any], set[any]>")
        }
    }

    static func min(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        switch args[0] {
        case .array(let a):
            return a.min() ?? .undefined
        case .set(let s):
            return s.min() ?? .undefined
        default:
            throw BuiltinError.argumentTypeMismatch(
                arg: "collection", got: args[0].typeName, want: "any<array[any], set[any]>")
        }
    }

    static func sort(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        switch args[0] {
        case .array(let a):
            return .array(a.sorted())
        case .set(let s):
            return .array(s.sorted())
        default:
            throw BuiltinError.argumentTypeMismatch(
                arg: "collection", got: args[0].typeName, want: "any<array[any], set[any]>")
        }
    }

    static func sum(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        return try await doReduce(ctx: ctx, args: args, initialValue: .number(0), op: BuiltinFuncs.plus)
    }

    static func product(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        return try await doReduce(ctx: ctx, args: args, initialValue: .number(1), op: BuiltinFuncs.mul)
    }

    /// Returns reduction over an array or set of RegoValues with a given async Builtin being used as an reducer operation.
    /// Returns the normalized metric unit symbol for a given symbol.
    /// - Parameters:
    ///   - ctx: The builtin context.
    ///   - args: The arguments to reduce.
    ///   - initialValue: The initial value to start with.
    ///   - op: The Arithmetic builtin operation to be applied to the partial result an the next value in the sequence to produce the next result.
    private static func doReduce(
        ctx: BuiltinContext, args: [AST.RegoValue],
        initialValue: AST.RegoValue,
        op: (BuiltinContext, [AST.RegoValue]) async throws -> AST.RegoValue
    ) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        // We will iterate over this sequence
        var sequence: any Sequence<RegoValue>
        switch args[0] {
        case .array(let a):
            sequence = a
        case .set(let s):
            sequence = s
        default:
            throw BuiltinError.argumentTypeMismatch(
                arg: "collection", got: args[0].typeName, want: "any<array[number], set[number]>")
        }

        do {
            // Can't use synchronous reduce here
            var result = initialValue
            for element in sequence {
                result = try await op(ctx, [result, element])
            }
            return result
        } catch is RegoError {
            let receivedTypes = Set(sequence.map({ $0.typeName })).sorted().joined(separator: ", ")
            throw BuiltinError.argumentTypeMismatch(
                arg: "collection", got: "\(args[0].typeName)[any<\(receivedTypes)>]",
                want: "any<array[number], set[number]>")
        }
    }
}
