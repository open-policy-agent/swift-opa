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
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
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
            // NOTE that we are okay with this argument being a float with integer value
            // numbers.range_step(1.0, 3.0, 1.0) works just fine
            guard let stepValue = args[2].integerValue else {
                throw BuiltinError.argumentTypeMismatch(arg: "step", got: args[0].typeName, want: "integer")
            }

            guard stepValue > 0 else {
                // Golang error is different: step must be a positive number above zero.
                // But positive number is by definition above zero...
                // so using a different error message.
                // Compliance tests still pass
                throw BuiltinError.evalError(msg: "step must be a positive integer")
            }

            step = stepValue
        }
        if intB > intA {
            return .array(
                stride(from: intA, to: intB + 1, by: Int64.Stride(step))
                    .map({ NSNumber(value: $0).toNumberRegoValue(asInt: true) }))

        }

        return .array(
            stride(from: intA, to: intB - 1, by: -Int64.Stride(step))
                .map({ NSNumber(value: $0).toNumberRegoValue(asInt: true) }))

    }

}
