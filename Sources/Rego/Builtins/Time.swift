import AST
import Foundation

extension BuiltinFuncs {
    static func timeNowNanos(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 0 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 0)
        }
        // Note that the value of the "now" is pinned to the value in the BuiltinContext.
        // This is done so that multiple calls to this built-in function within a single policy evaluation query
        // will always return the same value.
        // This is by design and is documented in https://www.openpolicyagent.org/docs/latest/policy-reference/#time
        let nanos = UInt64(ctx.timestamp.timeIntervalSince1970 * 1_000_000_000)
        return .number(RegoNumber(value: Int64(bitPattern: nanos)))
    }
}
