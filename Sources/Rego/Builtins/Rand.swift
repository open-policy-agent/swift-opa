import AST
import Foundation

private let randNamespace: String = "rand"

extension BuiltinFuncs {
    static func numbersRandIntN(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }

        guard case .string(let str) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "str", got: args[0].typeName, want: "string")
        }

        guard case .number(_) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "n", got: args[1].typeName, want: "number")
        }

        // NOTE that we are okay with argument n being a float with integer value,
        // i.e. rand.intn("key", 100.0) is okay
        guard let n = args[1].integerValue else {
            throw BuiltinError.evalError(msg: "operand 1 must be integer number but got floating-point number")
        }

        let key: String = "\(str)-\(n)"
        let existing: RegoValue? = ctx.cache.v[key, .namespace(randNamespace)]
        guard let existing else {
            var value: UInt64 = 0

            if n != 0 {
                value = UInt64(UInt64.random(in: 0..<UInt64(Swift.abs(n)), using: &ctx.rand.v))
            }

            let result = RegoValue.number(NSNumber(value: value))
            ctx.cache.v[key, .namespace(randNamespace)] = result

            return result
        }

        return existing
    }
}
