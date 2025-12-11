import AST
import Foundation

extension BuiltinFuncs {
    static func bitsShiftLeft(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }

        // NOTE that we are okay with this argument being a float with integer value
        // bits.lsh(1.0, 2.0) works just fine
        guard let intA = args[0].integerValue else {
            throw BuiltinError.argumentTypeMismatch(arg: "a", got: args[0].typeName, want: "number[integer]")
        }

        // NOTE that we are okay with this argument being a float with integer value
        // bits.lsh(1.0, 2.0) works just fine
        guard let intB = args[1].integerValue else {
            throw BuiltinError.argumentTypeMismatch(arg: "b", got: args[1].typeName, want: "number[integer]")
        }

        guard intB >= 0 else {
            throw BuiltinError.argumentTypeMismatch(arg: "b", got: "negative integer", want: "unsigned integer")
        }
        // Shifts >= 64 bits return 0
        guard intB < 64 else {
            return AST.RegoValue.number(NSNumber(value: 0))
        }

        // For positive numbers, use unsigned arithmetic to handle cases
        // where shifting would move bits into the sign bit position
        if intA > 0 {
            return AST.RegoValue.number(NSNumber(value: UInt64(intA) << intB))
        }

        // For negative numbers or zero, use signed arithmetic with wrapping
        return AST.RegoValue.number(NSNumber(value: intA &<< intB))
    }

    static func bitsShiftRight(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }

        // NOTE that we are okay with this argument being a float with integer value
        // bits.rsh(8.0, 2.0) works just fine
        guard let intA = args[0].integerValue else {
            throw BuiltinError.argumentTypeMismatch(arg: "a", got: args[0].typeName, want: "number[integer]")
        }

        // NOTE that we are okay with this argument being a float with integer value
        // bits.rsh(8.0, 2.0) works just fine
        guard let intB = args[1].integerValue else {
            throw BuiltinError.argumentTypeMismatch(arg: "b", got: args[1].typeName, want: "number[integer]")
        }

        guard intB >= 0 else {
            throw BuiltinError.argumentTypeMismatch(arg: "b", got: "negative integer", want: "unsigned integer")
        }

        // Shifts >= 64 bits result in 0 or sign bit
        guard intB < 64 else {
            return AST.RegoValue.number(NSNumber(value: intA >= 0 ? 0 : -1))
        }

        return AST.RegoValue.number(NSNumber(value: intA >> intB))
    }

    static func bitsNegate(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        // NOTE that we are okay with this argument being a float with integer value
        // bits.negate(9.0) works just fine
        guard let intX = args[0].integerValue else {
            throw BuiltinError.argumentTypeMismatch(arg: "a", got: args[0].typeName, want: "number[integer]")
        }

        return AST.RegoValue.number(NSNumber(value: Int64(~intX)))
    }

    static func bitsAnd(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        return try bitwiseOperation(ctx: ctx, args: args, op: &)
    }

    static func bitsOr(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        return try bitwiseOperation(ctx: ctx, args: args, op: |)
    }

    static func bitsXor(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        return try bitwiseOperation(ctx: ctx, args: args, op: ^)
    }

    // Common implementation of all bitwise operators
    private static func bitwiseOperation(
        ctx: BuiltinContext, args: [AST.RegoValue],
        op: (Int64, Int64) -> Int64
    ) throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }

        // NOTE that we are okay with this argument being a float with integer value
        // bits.and(1.0, 2.0) works just fine
        guard let intX = args[0].integerValue else {
            throw BuiltinError.argumentTypeMismatch(arg: "a", got: args[0].typeName, want: "number[integer]")
        }

        // NOTE that we are okay with this argument being a float with integer value
        // bits.and(1.0, 2.0) works just fine
        guard let intY = args[1].integerValue else {
            throw BuiltinError.argumentTypeMismatch(arg: "b", got: args[1].typeName, want: "number[integer]")
        }

        return AST.RegoValue.number(NSNumber(value: op(intX, intY)))
    }
}
