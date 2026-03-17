import AST
import Foundation

private let minDateAllowedForNsConversion = Date(timeIntervalSince1970: TimeInterval(Int64.min) / 1_000_000_000)
private let maxDateAllowedForNsConversion = Date(timeIntervalSince1970: TimeInterval(Int64.max) / 1_000_000_000)
private let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

extension BuiltinFuncs {
    // MARK: - time.now_ns
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

    // MARK: - time.add_date
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

    // MARK: - time.clock
    static func timeClock(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }
        let (date, cal) = try dateWithCalendar(args[0])
        let comps = cal.dateComponents([.hour, .minute, .second], from: date)
        return .array([
            .number(RegoNumber(int: Int64(comps.hour ?? 0))),
            .number(RegoNumber(int: Int64(comps.minute ?? 0))),
            .number(RegoNumber(int: Int64(comps.second ?? 0))),
        ])
    }

    // MARK: - time.date
    static func timeDate(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }
        let (date, cal) = try dateWithCalendar(args[0])
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        return .array([
            .number(RegoNumber(int: Int64(comps.year ?? 0))),
            .number(RegoNumber(int: Int64(comps.month ?? 0))),
            .number(RegoNumber(int: Int64(comps.day ?? 0))),
        ])
    }

    // MARK: - time.weekday
    static func timeWeekday(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }
        let (date, cal) = try dateWithCalendar(args[0])
        return .string(weekdayNames[cal.component(.weekday, from: date) - 1])
    }

    // MARK: - private utilities
    /// Parses `nanoseconds` or `[nanoseconds, timezone]` argument and returns the corresponding `Date` and
    /// a UTC-based Gregorian `Calendar` configured with the specified timezone.
    private static func dateWithCalendar(_ arg: AST.RegoValue) throws -> (Date, Calendar) {
        let (ns, timeZone) = try parseNanosWithTimezone(arg)
        // Use floor division rather than truncation.
        // Without this, negative timestamps with sub-second nanos land in the wrong second,
        // e.g. ns=-900_000_000 (-0.9s) would truncate to 0 (epoch) instead of -1 (1969-12-31 23:59:59).
        let wholeSeconds = ns / 1_000_000_000 - (ns % 1_000_000_000 < 0 ? 1 : 0)
        let date = Date(timeIntervalSince1970: TimeInterval(wholeSeconds))
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = timeZone
        return (date, cal)
    }

    /// Parses a time.clock/time.date argument which is either ns (number) or [ns, timezone] (array).
    /// Mirrors golang's OPA: throws "timestamp too big" if ns does not fit in Int64.
    private static func parseNanosWithTimezone(_ arg: AST.RegoValue) throws -> (Int64, TimeZone) {
        let floatNsError = "timestamp must be an integer, but got a floating-point number"
        switch arg {
        case .number(let x):
            guard let ns = x.int64Value else {
                if x.clampedUint64Value > Int64.max {
                    throw BuiltinError.evalError(msg: "timestamp too big")
                }
                throw BuiltinError.evalError(msg: floatNsError)
            }
            return (ns, TimeZone(identifier: "UTC")!)
        case .array(let a) where a.count == 2:
            guard case .number(let x) = a[0] else {
                throw BuiltinError.argumentTypeMismatch(arg: "nanoseconds", got: arg.typeName, want: "number[integer]")
            }
            guard let ns = x.int64Value else {
                if x.clampedUint64Value > Int64.max {
                    throw BuiltinError.evalError(msg: "timestamp too big")
                }
                throw BuiltinError.evalError(msg: floatNsError)
            }
            guard case .string(let timeZoneName) = a[1] else {
                throw BuiltinError.argumentTypeMismatch(arg: "timeZone", got: arg.typeName, want: "string")
            }
            guard !timeZoneName.isEmpty else {
                return (ns, TimeZone(identifier: "UTC")!)
            }
            if timeZoneName.lowercased() == "local" {
                return (ns, TimeZone.current)
            }
            guard let tz = TimeZone(identifier: String(timeZoneName)) else {
                throw BuiltinError.evalError(msg: "unknown timezone: \(timeZoneName)")
            }
            return (ns, tz)
        default:
            throw BuiltinError.argumentTypeMismatch(
                arg: "x", got: arg.typeName, want: "any<number[integer], array<number[integer], string>>")
        }
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
