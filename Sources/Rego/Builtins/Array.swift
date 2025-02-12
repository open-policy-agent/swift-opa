import AST
import Foundation

extension BuiltinFuncs {
    static func arrayConcat(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        // x: array - the first array
        // y: array - the second array
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 2)
        }
        guard case .array(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "array")
        }
        guard case .array(let y) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "y", got: args[1].typeName, want: "array")
        }

        return .array(x + y)
    }

    static func arrayReverse(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        // x: array
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 1)
        }
        guard case .array(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "array")
        }

        return .array(x.reversed())
    }

    static func arraySlice(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        // x: array, start, stop: number
        guard args.count == 3 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, expected: 3)
        }

        guard case .array(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "array")
        }

        guard case .number(var start) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "start", got: args[1].typeName, want: "number")
        }

        guard case .number(var stop) = args[2] else {
            throw BuiltinError.argumentTypeMismatch(arg: "stop", got: args[2].typeName, want: "number")
        }

        // We expect start and stop to be integers, otherwise undefined should be returned
        guard start is Int, stop is Int else {
            return .undefined
        }

        // Bring start within array bounds
        if start.isLessThan(0) {
            start = 0 as NSNumber
        }

        // Bring stop within array bounds
        if stop.isGreaterThan(x.count) {
            stop = x.count as NSNumber
        }

        // When start > stop, immediately return an empty array
        guard stop.isGreaterThanOrEqual(to: start) else {
            return .array([])
        }

        return .array(Array(x[start.intValue..<stop.intValue]))
    }
}
