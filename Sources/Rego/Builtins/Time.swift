import AST
import Foundation

private let weekdayNames = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

// The whole-second floor of Int64.min nanoseconds, matching Go's minDateAllowedForNs = time.Unix(0, math.MinInt64).
// Int64.min / 1_000_000_000 truncates toward zero (-9_223_372_036); subtract 1 for floor toward -∞.
private let minTimestampWholeSeconds: Int64 = Int64.min / 1_000_000_000 - 1
// The minimum sub-second nanoseconds required to "rescue" the overflow case back to Int64.min:
//   minTimestampWholeSeconds * 1e9 underflows Int64, but adding this offset yields exactly Int64.min.
//   Any sub-second value below this offset would produce a result below Int64.min — invalid.
// Computed with wrapping arithmetic because the product itself overflows Int64.
private let minTimestampSubSecondNanosOffset: Int64 = Int64.min &- (minTimestampWholeSeconds &* 1_000_000_000)

// Widest Date bounds whose nanosecond results fit in Int64.
// Mirrors Go's minDateAllowedForNs / maxDateAllowedForNs = time.Unix(0, math.MinInt64/MaxInt64).
private let minDateAllowedForNsConversion = Date(timeIntervalSince1970: TimeInterval(minTimestampWholeSeconds))
private let maxDateAllowedForNsConversion = Date(timeIntervalSince1970: TimeInterval(Int64.max / 1_000_000_000))

// Named Go-compatible time-format aliases accepted by time.parse_ns — mirrors OPA's acceptedTimeFormats in time.go.
private let timeFormatAliases: [String: String] = [
    "ANSIC": "Mon Jan _2 15:04:05 2006",
    "UnixDate": "Mon Jan _2 15:04:05 MST 2006",
    "RubyDate": "Mon Jan 02 15:04:05 -0700 2006",
    "RFC822": "02 Jan 06 15:04 MST",
    "RFC822Z": "02 Jan 06 15:04 -0700",
    "RFC850": "Monday, 02-Jan-06 15:04:05 MST",
    "RFC1123": "Mon, 02 Jan 2006 15:04:05 MST",
    "RFC1123Z": "Mon, 02 Jan 2006 15:04:05 -0700",
    "RFC3339": "2006-01-02T15:04:05Z07:00",
    "RFC3339Nano": "2006-01-02T15:04:05.999999999Z07:00",
]

// Go referenced-time tokens mapped to their ICU/DateFormatter equivalents.
// Ordered longest-first so that greedy matching picks the right token
// (e.g. "January" before "Jan", "Z07:00" before "Z07").
private let timeFormatTokens: [(String, String)] = [
    ("January", "MMMM"),  // full month name
    ("Monday", "EEEE"),  // full weekday name
    ("2006", "yyyy"),  // 4-digit year
    ("Z07:00", "XXX"),  // ±HH:mm or Z (e.g. +05:30 or Z)
    ("-07:00", "xxx"),  // ±HH:mm (e.g. +05:30 or -08:00)
    ("Z0700", "XX"),  // ±HHmm or Z
    ("-0700", "xx"),  // ±HHmm
    ("Jan", "MMM"),  // abbreviated month name
    ("Mon", "EEE"),  // abbreviated weekday name
    ("MST", "zzz"),  // timezone abbreviation (e.g. EST, UTC)
    ("Z07", "X"),  // ±HH or Z
    ("-07", "x"),  // ±HH
    ("15", "HH"),  // 24-hour (00-23)
    ("06", "yy"),  // 2-digit year
    ("01", "MM"),  // month (01-12)
    ("02", "dd"),  // day (01-31)
    ("03", "hh"),  // 12-hour (01-12)
    ("04", "mm"),  // minute (00-59)
    ("05", "ss"),  // second (00-59)
    ("_2", "d"),  // space-padded day; DateFormatter uses 'd' (no padding)
    ("PM", "a"),  // AM/PM
    ("pm", "a"),  // am/pm
]

/// Metadata extracted from a Go fractional-seconds format token (.999… or .000…)
/// used to render nanosecond-precision digits when formatting a timestamp.
private struct FractionalSecondsInfo {
    let suffixFormat: String  // ICU format for the portion after the fractional-seconds token
    let digitCount: Int  // number of fractional digits in the Go token (e.g. 9 for .999999999)
    let trimTrailingZeros: Bool  // Go time format token .999… trims trailing zeros; .000… preserves them
}

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

    // MARK: - time.diff
    static func timeDiff(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }

        let (ns1, tz1) = try parseNanosWithTimezone(args[0])
        let (ns2, _) = try parseNanosWithTimezone(args[1])

        // Use tz1 for both, matching OPA behaviour (t2.In(t1.Location()))
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz1

        // Floor-divide to whole seconds, then sort so date1 <= date2
        let ws1 = ns1 / 1_000_000_000 - (ns1 % 1_000_000_000 < 0 ? 1 : 0)
        let ws2 = ns2 / 1_000_000_000 - (ns2 % 1_000_000_000 < 0 ? 1 : 0)
        let date1 = Date(timeIntervalSince1970: TimeInterval(Swift.min(ws1, ws2)))
        let date2 = Date(timeIntervalSince1970: TimeInterval(Swift.max(ws1, ws2)))

        let c1 = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date1)
        let c2 = cal.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date2)

        var year = (c2.year ?? 0) - (c1.year ?? 0)
        var month = (c2.month ?? 0) - (c1.month ?? 0)
        var day = (c2.day ?? 0) - (c1.day ?? 0)
        var hour = (c2.hour ?? 0) - (c1.hour ?? 0)
        var min = (c2.minute ?? 0) - (c1.minute ?? 0)
        var sec = (c2.second ?? 0) - (c1.second ?? 0)

        // Normalize negative values — mirrors the icza/gox algorithm used in OPA
        if sec < 0 {
            sec += 60
            min -= 1
        }
        if min < 0 {
            min += 60
            hour -= 1
        }
        if hour < 0 {
            hour += 24
            day -= 1
        }
        if day < 0 {
            // Number of days in month M1 of year Y1
            let daysInMonth = cal.range(of: .day, in: .month, for: date1)?.count ?? 30
            day += daysInMonth
            month -= 1
        }
        if month < 0 {
            month += 12
            year -= 1
        }

        return .array([
            .number(RegoNumber(int: Int64(year))),
            .number(RegoNumber(int: Int64(month))),
            .number(RegoNumber(int: Int64(day))),
            .number(RegoNumber(int: Int64(hour))),
            .number(RegoNumber(int: Int64(min))),
            .number(RegoNumber(int: Int64(sec))),
        ])
    }

    // MARK: - time.format
    static func timeFormat(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }
        let (ns, tz, layout) = try parseFormatArgs(args[0])

        // Default layout is RFC3339Nano; expand named aliases.
        let goFormat: String
        if layout.isEmpty {
            goFormat = timeFormatAliases["RFC3339Nano"]!
        } else if let expanded = timeFormatAliases[layout] {
            goFormat = expanded
        } else {
            goFormat = layout
        }

        let (icuFormat, fracInfo) = icuDateFormat(from: goFormat, preserveFractionalSeconds: true)

        // Floor-divide to whole seconds (same logic as dateWithCalendar).
        let wholeSeconds = ns / 1_000_000_000 - (ns % 1_000_000_000 < 0 ? 1 : 0)
        let date = Date(timeIntervalSince1970: TimeInterval(wholeSeconds))

        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = tz

        // When the Go format contained a fractional-seconds token, icuFormat is just the
        // prefix (everything before it) and fracInfo carries the suffix format.  We format
        // each half independently and splice the real nanosecond digits in between.
        df.dateFormat = icuFormat
        var result = df.string(from: date)

        if let info = fracInfo {
            var subNanos = ns % 1_000_000_000
            if subNanos < 0 { subNanos += 1_000_000_000 }
            let nanosStr = String(format: "%09d", subNanos)
            var fracStr = String(nanosStr.prefix(info.digitCount))

            if info.trimTrailingZeros {
                while fracStr.hasSuffix("0") {
                    fracStr = String(fracStr.dropLast())
                }
            }
            result += fracStr.isEmpty ? "" : ".\(fracStr)"

            df.dateFormat = info.suffixFormat
            result += df.string(from: date)
        }

        return .string(result)
    }

    // MARK: - time.parse_duration_ns
    static func timeParseDurationNanos(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }
        guard case .string(let duration) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "duration", got: args[0].typeName, want: "string")
        }
        let ns: Int64
        do {
            ns = try parseDurationNanoseconds(duration)
        } catch is DurationParseError {
            throw BuiltinError.evalError(msg: "invalid duration \"\(duration)\"")
        }
        return .number(RegoNumber(int: ns))
    }

    // MARK: - time.parse_ns
    static func timeParseNanos(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 2 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 2)
        }
        guard case .string(let format) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "format", got: args[0].typeName, want: "string")
        }
        guard case .string(let value) = args[1] else {
            throw BuiltinError.argumentTypeMismatch(arg: "value", got: args[1].typeName, want: "string")
        }

        // Expand named format aliases — mirrors OPA's acceptedTimeFormats in time.go.
        let namedFormat = timeFormatAliases[String(format)] ?? String(format)

        // Go's time.Parse always accepts fractional seconds after the seconds field even
        // when the layout omits them. Extract them manually for nanosecond precision.
        let (strippedValue, subSecondNanos) = extractSubSecondNanoseconds(from: String(value))

        let formatter = icuDateFormat(from: namedFormat).0
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = formatter
        // Default to UTC when the format carries no timezone information.
        if !namedFormat.contains("Z07") && !namedFormat.contains("-07") && !namedFormat.contains("MST") {
            df.timeZone = TimeZone(identifier: "UTC")
        }

        guard let date = df.date(from: strippedValue) else {
            throw BuiltinError.evalError(
                msg: "time.parse_ns: failed to parse \"\(value)\" with format \"\(format)\"")
        }
        return .number(RegoNumber(int: try toSafeUnixNanos(date, subSecondNanos: subSecondNanos)))
    }

    // MARK: - time.parse_rfc3339_ns
    static func timeParseRFC3339Nanos(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }
        guard case .string(let value) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "value", got: args[0].typeName, want: "string")
        }

        let df = ISO8601DateFormatter()
        // Extract fractional seconds manually for nanosecond precision before parsing.
        // ISO8601DateFormatter only handles up to microseconds, and DateFormatter even less.
        // Go's builtinTimeParseRFC3339Nanos uses time.Parse(time.RFC3339, ...) which
        // always accepts fractional seconds regardless of the layout.
        let (strippedValue, subSecondNanos) = extractSubSecondNanoseconds(from: String(value))
        df.formatOptions = [.withInternetDateTime]
        guard let date = df.date(from: strippedValue) else {
            throw BuiltinError.evalError(msg: "time.parse_rfc3339_ns: failed to parse \"\(value)\"")
        }
        return .number(RegoNumber(int: try toSafeUnixNanos(date, subSecondNanos: subSecondNanos)))
    }

    // MARK: - time.weekday
    static func timeWeekday(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }
        let (date, cal) = try dateWithCalendar(args[0])
        return .string(weekdayNames[cal.component(.weekday, from: date) - 1])
    }

    // MARK: - Duration parsing

    enum DurationParseError: Error {
        case invalidFormat
    }

    /// Parses a duration string and returns the equivalent duration in nanoseconds.
    ///
    /// - Parameters:
    ///   - duration: A string representing a duration with parts in the format of numeric values followed by a unit (e.g., "10m", "1s", "10ms").
    ///
    /// - Returns: The duration represented as an `Int64` in nanoseconds.
    ///
    /// - Throws: `DurationParseError.invalidFormat` if the input string doesn't conform to the expected format.
    ///
    /// - Note: Supports units such as nanoseconds (ns), microseconds (us, µs),
    ///        milliseconds (ms), seconds (s), minutes (m), and hours (h).
    static func parseDurationNanoseconds(_ duration: String) throws -> Int64 {
        var isNegative = false
        var durationValue = duration.trimmingCharacters(in: .whitespaces)

        // Check for negative sign at the start
        if durationValue.hasPrefix("-") {
            isNegative = true
            durationValue = String(durationValue.dropFirst())
        }

        let regex = /(?<value>\d+)(?<unit>ns|us|µs|ms|s|m|h)/
        let results = durationValue.matches(of: regex)

        guard !results.isEmpty else {
            throw DurationParseError.invalidFormat
        }
        var totalNanoseconds: Int64 = 0

        // Keep matching the string accumulating nanoseconds
        var expectedIndex = durationValue.startIndex
        for match in results {
            // We want to make sure the match starts where we expect it to start
            // If it does not, we skipped over some parts of the string that
            // did not match the regex, and we have to fail
            guard match.range.lowerBound == expectedIndex else {
                throw DurationParseError.invalidFormat
            }
            let valuePart = match.value
            let unitPart = match.unit

            guard let value = Int64(valuePart) else {
                throw DurationParseError.invalidFormat
            }

            switch unitPart {
            case "ns":
                totalNanoseconds += value
            case "us", "µs":
                totalNanoseconds += value * 1_000
            case "ms":
                totalNanoseconds += value * 1_000_000
            case "s":
                totalNanoseconds += value * 1_000_000_000
            case "m":
                totalNanoseconds += value * 60 * 1_000_000_000
            case "h":
                totalNanoseconds += value * 60 * 60 * 1_000_000_000
            default:
                throw DurationParseError.invalidFormat
            }
            // The next match is expected to start right after this match ends
            expectedIndex = match.range.upperBound
        }
        // Now, we MUST reach the end of the string
        // if we didn't it means that there are other parts that don't match our regex
        guard expectedIndex == durationValue.endIndex else {
            throw DurationParseError.invalidFormat
        }

        // Adjust for negative
        totalNanoseconds = isNegative ? -totalNanoseconds : totalNanoseconds

        return totalNanoseconds
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

    /// Converts a Go reference-time format string to an ICU/DateFormatter format string.
    ///
    /// Go's `time` package uses a reference time ("Mon Jan 2 15:04:05 MST 2006") as a
    /// format template, while Foundation's `DateFormatter` uses ICU pattern syntax.
    /// Both `time.parse_ns` and `time.format` accept arbitrary Go-style layout strings
    /// (not just the named aliases in `timeFormatAliases`), so we need this conversion
    /// for any user-provided layout.
    ///
    /// Examples:
    ///   Go `"2006-01-02T15:04:05Z07:00"` → ICU `"yyyy-MM-dd'T'HH:mm:ssXXX"`
    ///   Go `"Mon, 02 Jan 2006 15:04:05 -0700"` → ICU `"EEE, dd MMM yyyy HH:mm:ss xx"`
    ///
    /// Tokens are matched longest-first to prevent partial matches (e.g. "January" before "Jan").
    ///
    /// When `preserveFractionalSeconds` is false (the default, used for parsing),
    /// fractional-seconds tokens (.999…/.000…) are stripped as we assume that we already extracted
    /// the sub-second nanos from the value string, separately.
    /// When true (used for formatting), the returned string contains only the ICU format for
    /// the portion *before* the fractional-seconds token, and `FractionalSecondsInfo` carries
    /// the suffix format along with digit-count/trim metadata.  The caller formats each half
    /// independently and splices the real nanosecond digits in between.
    private static func icuDateFormat(
        from input: String, preserveFractionalSeconds: Bool = false
    ) -> (String, FractionalSecondsInfo?) {
        var result = ""
        var fracSplitIndex: String.Index? = nil
        var fracDigitCount = 0
        var fracTrimZeros = false
        var i = input.startIndex

        while i < input.endIndex {
            // Handle fractional seconds: .999...9 or .000...0
            if input[i] == "." {
                let afterDot = input.index(after: i)
                if afterDot < input.endIndex {
                    let next = input[afterDot]
                    if next == "9" || next == "0" {
                        var j = afterDot
                        while j < input.endIndex && input[j] == next {
                            j = input.index(after: j)
                        }
                        if preserveFractionalSeconds {
                            fracSplitIndex = result.endIndex
                            fracDigitCount = input.distance(from: afterDot, to: j)
                            fracTrimZeros = next == "9"
                        }
                        i = j
                        continue
                    }
                }
            }

            // Try each token in longest-first order
            let remaining = input[i...]
            var matched = false
            for (goToken, dfToken) in timeFormatTokens {
                if remaining.hasPrefix(goToken) {
                    result += dfToken
                    i = input.index(i, offsetBy: goToken.count)
                    matched = true
                    break
                }
            }
            if matched { continue }

            // Literal character: letters must be quoted so DateFormatter doesn't interpret them.
            // Non-letter characters pass through, except "'" which is DateFormatter's quoting
            // character and must be doubled to represent a literal apostrophe.
            let c = input[i]
            i = input.index(after: i)
            if c.isLetter {
                let escaped = c == "'" ? "''" : String(c)
                result += "'\(escaped)'"
            } else if c == "'" {
                result += "''"
            } else {
                result += String(c)
            }
        }

        if let splitIdx = fracSplitIndex {
            let prefix = String(result[result.startIndex..<splitIdx])
            let suffix = String(result[splitIdx...])
            let info = FractionalSecondsInfo(
                suffixFormat: suffix,
                digitCount: fracDigitCount,
                trimTrailingZeros: fracTrimZeros
            )
            return (prefix, info)
        }
        return (result, nil)
    }

    /// Parses a time.format argument: `ns` (number), `[ns, timezone]`, or `[ns, timezone, layout]`.
    private static func parseFormatArgs(_ arg: AST.RegoValue) throws -> (Int64, TimeZone, String) {
        let floatNsError = "timestamp must be an integer, but got a floating-point number"

        func extractNs(_ x: RegoNumber) throws -> Int64 {
            guard let ns = x.int64Value else {
                if x.clampedUint64Value > Int64.max {
                    throw BuiltinError.evalError(msg: "timestamp too big")
                }
                throw BuiltinError.evalError(msg: floatNsError)
            }
            return ns
        }

        func resolveTimezone(_ name: String) throws -> TimeZone {
            if name.isEmpty { return TimeZone(identifier: "UTC")! }
            if name.lowercased() == "local" { return TimeZone.current }
            guard let tz = TimeZone(identifier: name) else {
                throw BuiltinError.evalError(msg: "unknown timezone: \(name)")
            }
            return tz
        }

        switch arg {
        case .number(let x):
            return (try extractNs(x), TimeZone(identifier: "UTC")!, "")
        case .array(let a) where a.count == 2:
            guard case .number(let x) = a[0] else {
                throw BuiltinError.argumentTypeMismatch(
                    arg: "nanoseconds", got: a[0].typeName, want: "number[integer]")
            }
            guard case .string(let tzName) = a[1] else {
                throw BuiltinError.argumentTypeMismatch(
                    arg: "timezone", got: a[1].typeName, want: "string")
            }
            return (try extractNs(x), try resolveTimezone(String(tzName)), "")
        case .array(let a) where a.count == 3:
            guard case .number(let x) = a[0] else {
                throw BuiltinError.argumentTypeMismatch(
                    arg: "nanoseconds", got: a[0].typeName, want: "number[integer]")
            }
            guard case .string(let tzName) = a[1] else {
                throw BuiltinError.argumentTypeMismatch(
                    arg: "timezone", got: a[1].typeName, want: "string")
            }
            guard case .string(let layout) = a[2] else {
                throw BuiltinError.argumentTypeMismatch(
                    arg: "layout", got: a[2].typeName, want: "string")
            }
            return (try extractNs(x), try resolveTimezone(String(tzName)), String(layout))
        default:
            throw BuiltinError.argumentTypeMismatch(
                arg: "x", got: arg.typeName,
                want: "any<number[integer], array<number[integer], string>, array<number[integer], string, string>>")
        }
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

    /// Extracts a fractional-seconds field from a datetime string, returning the string
    /// with that field removed and its value in nanoseconds.
    ///
    /// Matches the first occurrence of `.<digits>` in the string, which corresponds to
    /// fractional seconds in any of the supported datetime formats. The digits are padded
    /// or truncated to exactly 9 places before conversion so the result is always in
    /// [0, 999_999_999]. This mirrors Go's `time.Parse` behaviour of accepting fractional
    /// seconds after the seconds field even when the layout does not include them.
    private static func extractSubSecondNanoseconds(from s: String) -> (String, Int64) {
        var i = s.startIndex
        while i < s.endIndex {
            if s[i] == "." {
                let afterDot = s.index(after: i)
                if afterDot < s.endIndex && s[afterDot].isNumber {
                    var j = afterDot
                    while j < s.endIndex && s[j].isNumber {
                        j = s.index(after: j)
                    }
                    let digits = String(s[afterDot..<j])
                    // Pad right to 9 digits (truncate if longer)
                    let padded: String
                    if digits.count >= 9 {
                        padded = String(digits.prefix(9))
                    } else {
                        padded = digits + String(repeating: "0", count: 9 - digits.count)
                    }
                    let nanos = Int64(padded) ?? 0
                    let stripped = String(s[s.startIndex..<i]) + String(s[j...])
                    return (stripped, nanos)
                }
            }
            i = s.index(after: i)
        }
        return (s, 0)
    }

    /// Returns the nanoseconds since epoch as Int64,
    /// or throws if the result falls outside the representable range
    /// (1677-09-21T00:12:43.145224192Z to 2262-04-11T23:47:16.854775807Z).
    /// See https://github.com/open-policy-agent/opa/blob/1ac64ef1a57a531c2723c59848890b88e816d777/v1/topdown/time.go#L30
    private static func toSafeUnixNanos(_ date: Date, subSecondNanos: Int64 = 0) throws -> Int64 {
        // Our input is a floor-divided whole-second Date plus the sub-second nanoseconds
        // separately. Guard against out-of-range dates, then rely on arithmetic overflow detection.
        let ti = date.timeIntervalSince1970
        guard date >= minDateAllowedForNsConversion && date <= maxDateAllowedForNsConversion else {
            throw BuiltinError.evalError(msg: "time outside of valid range")
        }
        let wholeSeconds = Int64(ti)
        let (wholeSecondsInNanos, mulOverflow) = wholeSeconds.multipliedReportingOverflow(by: 1_000_000_000)
        if mulOverflow {
            // The only representable case: wholeSeconds == minTimestampWholeSeconds
            // with enough sub-second nanos to land exactly at Int64.min.
            guard wholeSeconds == minTimestampWholeSeconds, subSecondNanos >= minTimestampSubSecondNanosOffset else {
                throw BuiltinError.evalError(msg: "time outside of valid range")
            }
            // The &+ is safe here; it's just necessary because Int64.min + 0 triggers overflow trap even though the math is fine
            return Int64.min &+ (subSecondNanos - minTimestampSubSecondNanosOffset)
        }
        let (result, addOverflow) = wholeSecondsInNanos.addingReportingOverflow(subSecondNanos)
        guard !addOverflow else {
            throw BuiltinError.evalError(msg: "time outside of valid range")
        }
        return result
    }
}
