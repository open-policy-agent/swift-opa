import AST
import Foundation

// A bunch of these rego builtins shadow global functions
// this probably isn't the best idea... but we'll alias them here
let _round = round
let _ceil = ceil
let _floor = floor

extension BuiltinFuncs {
    static func plus(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        return try doPlus(args: args)
    }

    static func doPlus(args: [AST.RegoValue]) throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }

        guard case .number(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "number")
        }

        guard case .number(let y) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "y", got: args[1].typeName, want: "number")
        }

        return .number(x + y)
    }

    static func minus(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }

        switch args[0] {
        case .number(let x):
            guard case .number(let y) = args[1] else {
                throw BuiltinError.argumentTypeMismatch(arg: "y", got: args[1].typeName, want: "number")
            }
            return .number(x - y)
        case .set(let x):
            guard case .set(let y) = args[1] else {
                throw BuiltinError.argumentTypeMismatch(arg: "y", got: args[1].typeName, want: "set")
            }
            return .set(x.subtracting(y))
        default:
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "number|set")
        }
    }

    // Multiplies two numbers.
    // Returns: the product of `x` and `y`
    static func mul(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        return try doMul(args: args)
    }

    static func doMul(args: [AST.RegoValue]) throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }

        guard case .number(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "number")
        }

        guard case .number(let y) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "y", got: args[1].typeName, want: "number")
        }

        return .number(x * y)
    }

    // Divides the first number by the second number.
    // Returns: the result of `x` divided by `y`
    static func div(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }

        guard case .number(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "number")
        }

        guard case .number(let y) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "y", got: args[1].typeName, want: "number")
        }

        guard y != RegoNumber(value: 0) else {
            throw BuiltinError.evalError(msg: "division by zero")
        }

        return .number(x / y)
    }

    static func round(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        guard case .number(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "number")
        }

        if args[0].integerValue != nil {
            return args[0]
        }

        return .number(RegoNumber(value: _round(x.doubleValue)))
    }

    static func ceil(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        guard case .number(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "number")
        }

        if args[0].integerValue != nil {
            return args[0]
        }

        return .number(RegoNumber(value: _ceil(x.doubleValue)))
    }

    static func floor(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        guard case .number(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "number")
        }

        if args[0].integerValue != nil {
            return args[0]
        }

        return .number(RegoNumber(value: _floor(x.doubleValue)))
    }

    static func abs(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        guard case .number(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "number")
        }

        return .number(RegoNumber(x.decimalValue.magnitude))
    }

    // Returns the remainder for of `x` divided by `y`, for `y != 0`.
    static func rem(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }

        guard case .number = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "number")
        }

        guard case .number = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "y", got: args[1].typeName, want: "number")
        }

        // Matching upstream behavior
        guard let x = args[0].integerValue, let y = args[1].integerValue else {
            throw BuiltinError.evalError(msg: "modulo on floating-point number")
        }

        // No divide-by-zero
        guard y != 0 else {
            throw BuiltinError.evalError(msg: "modulo by zero")
        }

        return .number(RegoNumber(value: x % y))
    }
}
