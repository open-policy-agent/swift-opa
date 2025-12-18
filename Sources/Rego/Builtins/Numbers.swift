import AST
import Foundation

extension BuiltinFuncs {
    static func numbersRange(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }

        return try generateSequence(args: args, withStep: false)
    }

    static func numbersRangeStep(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 3 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 3)
        }

        return try generateSequence(args: args, withStep: true)
    }

    private static func generateSequence(args: [AST.RegoValue], withStep: Bool) throws -> RegoValue {
        guard case .number(_) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "a", got: args[0].typeName, want: "number")
        }

        guard case .number(_) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "b", got: args[1].typeName, want: "number")
        }

        // NOTE that we are okay with this argument being a float with integer value
        // numbers.range_step(1.0, 3.0, 1.0) works just fine
        guard let intA = args[0].integerValue else {
            throw BuiltinError.evalError(msg: "operand 1 must be integer number but got floating-point number")
        }

        // NOTE that we are okay with this argument being a float with integer value
        // numbers.range_step(1.0, 3.0, 1.0) works just fine
        guard let intB = args[1].integerValue else {
            throw BuiltinError.evalError(msg: "operand 2 must be integer number but got floating-point number")
        }

        var step: Int64 = 1
        if withStep {
            guard case .number(_) = args[2] else {
                throw BuiltinError.argumentTypeMismatch(arg: "step", got: args[2].typeName, want: "number")
            }
            // NOTE that we are okay with this argument being a float with integer value
            // numbers.range_step(1.0, 3.0, 1.0) works just fine
            guard let stepValue = args[2].integerValue else {
                throw BuiltinError.evalError(msg: "step must be integer number but got floating-point number")
            }

            guard stepValue > 0 else {
                throw BuiltinError.evalError(msg: "step must be a positive integer")
            }

            step = stepValue
        }

        var result: [RegoValue] = []

        if intB > intA {
            result.reserveCapacity(Int((intB - intA) / step) + 1)

            var current = intA
            while current <= intB {
                result.append(.number(NSNumber(value: current)))
                current += step
            }
        } else {
            result.reserveCapacity(Int((intA - intB) / step) + 1)

            var current = intA
            while current >= intB {
                result.append(.number(NSNumber(value: current)))
                current -= step
            }
        }

        return .array(result)
    }

}
