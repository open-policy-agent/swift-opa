import AST
import Foundation

extension BuiltinFuncs {
    static func arrayConcat(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        // x: array - the first array
        // y: array - the second array
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
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
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }
        guard case .array(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "array")
        }

        return .array(x.reversed())
    }

    static func arraySlice(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        // x: array, start, stop: number
        guard args.count == 3 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 3)
        }

        guard case .array(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "array")
        }

        guard case .number(let start) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "start", got: args[1].typeName, want: "number")
        }

        guard case .number(let stop) = args[2] else {
            throw BuiltinError.argumentTypeMismatch(arg: "stop", got: args[2].typeName, want: "number")
        }

        // We expect start and stop to be integers, otherwise undefined should be returned
        guard start is Int, stop is Int else {
            throw BuiltinError.evalError(msg: "start and stop must be integers")
        }

        var startInt = start.intValue
        var stopInt = stop.intValue

        // Bring start within array bounds
        if startInt < 0 {
            startInt = 0
        }

        // Bring stop within array bounds
        if stopInt > x.count {
            stopInt = x.count
        }

        // When start > stop, immediately return an empty array
        guard stopInt >= startInt else {
            return .array([])
        }

        return .array(Array(x[startInt..<stopInt]))
    }
}
