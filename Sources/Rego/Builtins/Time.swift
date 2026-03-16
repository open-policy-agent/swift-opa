import AST
import Foundation

private let minDateAllowedForNsConversion = Date(timeIntervalSince1970: TimeInterval(Int64.min) / 1_000_000_000)
private let maxDateAllowedForNsConversion = Date(timeIntervalSince1970: TimeInterval(Int64.max) / 1_000_000_000)

extension BuiltinFuncs {
    static func timeNowNanos(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 0 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 0)
        }
        // Note that the value of the "now" is pinned to the value in the BuiltinContext.
        // This is done so that multiple calls to this built-in function within a single policy evaluation query
        // will always return the same value.
        // This is by design and is documented in https://www.openpolicyagent.org/docs/policy-reference/builtins/time
        let nanos = UInt64(ctx.timestamp.timeIntervalSince1970 * 1_000_000_000)
        return .number(RegoNumber(value: Int64(bitPattern: nanos)))
    }

    static func timeAddDate(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 4 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 4)
        }

        guard case .number(let ns) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "ns", got: args[0].typeName, want: "number[integer]")
        }

        guard case .number(let years) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "years", got: args[1].typeName, want: "number[integer]")
        }

        guard case .number(let months) = args[2] else {
            throw BuiltinError.argumentTypeMismatch(arg: "months", got: args[2].typeName, want: "number[integer]")
        }

        guard case .number(let days) = args[3] else {
            throw BuiltinError.argumentTypeMismatch(arg: "days", got: args[3].typeName, want: "number[integer]")
        }

        guard let nsInt64 = ns.int64Value else {
            throw BuiltinError.evalError(msg: "operand 0 must be integer number but got floating-point number")
        }

        guard let yearsInt64 = years.int64Value else {
            throw BuiltinError.evalError(msg: "operand 1 must be integer number but got floating-point number")
        }

        guard let monthsInt64 = months.int64Value else {
            throw BuiltinError.evalError(msg: "operand 2 must be integer number but got floating-point number")
        }

        guard let daysInt64 = days.int64Value else {
            throw BuiltinError.evalError(msg: "operand 3 must be integer number but got floating-point number")
        }

        // Use whole seconds only for Date to avoid floating-point precision loss on sub-second nanos.
        let date = Date(timeIntervalSince1970: TimeInterval(nsInt64 / 1_000_000_000))
        let components = DateComponents(
            year: Int(clamping: yearsInt64), month: Int(clamping: monthsInt64), day: Int(clamping: daysInt64))

        // Use UTC
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        guard let newDate = cal.date(byAdding: components, to: date) else {
            throw BuiltinError.evalError(msg: "time.add_date: failed to compute resulting date")
        }

        // Reconstruct back to nanoseconds by preserving the sub-second part of the input.
        let subSecondNanos = nsInt64 % 1_000_000_000
        return .number(RegoNumber(int: try toSafeUnixNanos(newDate, subSecondNanos: subSecondNanos)))
    }

    /// Returns the nanoseconds since epoch as Int64,
    /// or throws if the date falls outside the representable range
    /// (1677-09-21T00:12:43Z to 2262-04-11T23:47:16Z).
    /// See https://github.com/open-policy-agent/opa/blob/1ac64ef1a57a531c2723c59848890b88e816d777/v1/topdown/time.go#L30
    private static func toSafeUnixNanos(_ date: Date, subSecondNanos: Int64 = 0) throws -> Int64 {
        guard date >= minDateAllowedForNsConversion && date <= maxDateAllowedForNsConversion else {
            throw BuiltinError.evalError(msg: "time outside of valid range")
        }
        /// Note that Go's time.Time stores nanoseconds internally and the min and max bounds are defined in terms of nanoseconds.
        /// In our case, Date only has microsecond precision and so the overflow-reporting arithmetic approach is used to go from microseconds to nanos
        let (wholeSecondsInNanos, overflow1) = Int64(date.timeIntervalSince1970).multipliedReportingOverflow(
            by: 1_000_000_000)
        let (result, overflow2) = wholeSecondsInNanos.addingReportingOverflow(subSecondNanos)
        guard !overflow1 && !overflow2 else {
            throw BuiltinError.evalError(msg: "time outside of valid range")
        }
        return result
    }
}
