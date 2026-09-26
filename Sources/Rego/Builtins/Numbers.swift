import AST
import Foundation

extension BuiltinFuncs {
    static func numbersRange(ctx: BuiltinContext, args: [AST.RegoValue]) throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }

        return try generateSequence(args: args, withStep: false)
    }

    static func numbersRangeStep(ctx: BuiltinContext, args: [AST.RegoValue]) throws -> AST.RegoValue {
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
            guard case .number(let stepNum) = args[2] else {
                throw BuiltinError.argumentTypeMismatch(arg: "step", got: args[2].typeName, want: "number")
            }
            // We are okay with this argument being a float with integer value, e.g.
            // numbers.range_step(1.0, 3.0, 1.0) works just fine
            //
            // Validate number is a positive whole number directly (not via int64Value), so that
            // a whole-number step too large for Int64 is still accepted rather than being
            // mistaken for a fractional value.
            guard stepNum.isInteger else {
                throw BuiltinError.evalError(msg: "step must be integer number but got floating-point number")
            }

            guard stepNum.isPositive else {
                throw BuiltinError.evalError(msg: "step must be a positive integer")
            }

            guard let stepValue = stepNum.int64Value else {
                // The step is a positive integer too large for an Int64. The span between two
                // Int64 endpoints is below 2*Int64.max, so at most only a few elements fall in
                // the range. A step just above Int64.max can still be smaller than that span,
                // so we use a Decimal for the step size.
                return rangeWithDecimalStep(intA: intA, intB: intB, step: stepNum.decimalValue)
            }

            step = stepValue
        }

        return rangeWithInt64Step(intA: intA, intB: intB, step: step)
    }

    private static func rangeWithInt64Step(intA: Int64, intB: Int64, step: Int64) -> RegoValue {
        var result: [RegoValue] = []
        if intB > intA {
            result.reserveCapacity(Int((intB - intA) / step) + 1)

            var current = intA
            while current <= intB {
                result.append(.number(RegoNumber(value: current)))
                current += step
            }
        } else {
            result.reserveCapacity(Int((intA - intB) / step) + 1)

            var current = intA
            while current >= intB {
                result.append(.number(RegoNumber(value: current)))
                current -= step
            }
        }
        return .array(result)
    }

    /// Handle `numbers.range_step` when the step is a positive whole number too large for Int64.
    /// The endpoints still fit in Int64, so the span `|b - a|` is below 2·Int64.max and the
    /// result holds at most a handful of elements. We iterate in Decimal space (arbitrary
    /// precision) to avoid Int64 overflow while remaining correct for steps that are only
    /// slightly larger than Int64.max.
    private static func rangeWithDecimalStep(intA: Int64, intB: Int64, step: Decimal) -> RegoValue {
        let a = Decimal(intA)
        let b = Decimal(intB)

        var result: [RegoValue] = []
        var current = a
        if b >= a {
            while current <= b {
                result.append(.number(RegoNumber(current)))
                current += step
            }
        } else {
            while current >= b {
                result.append(.number(RegoNumber(current)))
                current -= step
            }
        }
        return .array(result)
    }

}
