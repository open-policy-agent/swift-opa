import AST
import Foundation
import Testing

@testable import Rego

extension BuiltinTests {
    @Suite("BuiltinTests - Time", .tags(.builtins))
    struct TimeTests {}
}

extension BuiltinTests.TimeTests {
    // MARK: - time.add_date Tests
    static let addDateTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "ns must be an integer",
            name: "time.add_date",
            args: [42.5, 0, 0, 0],
            expected: .failure(
                BuiltinError.evalError(msg: "operand 0 must be integer number but got floating-point number"))
        ),
        BuiltinTests.TestCase(
            description: "years must be an integer",
            name: "time.add_date",
            args: [12345, 0.75, 0, 0],
            expected: .failure(
                BuiltinError.evalError(msg: "operand 1 must be integer number but got floating-point number"))
        ),
        BuiltinTests.TestCase(
            description: "months must be an integer",
            name: "time.add_date",
            args: [12345, 0, 0.75, 0],
            expected: .failure(
                BuiltinError.evalError(msg: "operand 2 must be integer number but got floating-point number"))
        ),
        BuiltinTests.TestCase(
            description: "days must be an integer",
            name: "time.add_date",
            args: [12345, 0, 0, 0.75],
            expected: .failure(
                BuiltinError.evalError(msg: "operand 3 must be integer number but got floating-point number"))
        ),
        BuiltinTests.TestCase(
            description: "adds year month day",
            name: "time.add_date",
            args: [1_585_852_421_593_912_000, 3, 9, 12],
            expected: .success(1_705_257_221_593_912_000)
        ),
        BuiltinTests.TestCase(
            description: "adds negative values",
            name: "time.add_date",
            args: [1_585_852_421_593_912_000, -1, -1, -1],
            expected: .success(1_551_465_221_593_912_000)
        ),
        BuiltinTests.TestCase(
            description: "time outside of valid range: too large",
            name: "time.add_date",
            args: [0, 2262, 1, 1],
            expected: .failure(
                BuiltinError.evalError(msg: "time outside of valid range")
            )
        ),
        BuiltinTests.TestCase(
            description: "time outside of valid range: too small",
            name: "time.add_date",
            args: [-9_223_372_036_854_775_808, 0, 0, -1],
            expected: .failure(
                BuiltinError.evalError(msg: "time outside of valid range"))
        ),
        // February has 28 days
        // 2025-02-01 + 1 year = 2026-02-01, + 2 months = 2026-04-01, + 5 days = 2026-04-06
        BuiltinTests.TestCase(
            description: "adding 1 year 2 months 5 days to 2025-02-01",
            name: "time.add_date",
            args: [1_738_368_000_000_000_000, 1, 2, 5],
            expected: .success(1_775_433_600_000_000_000)
        ),
    ]

    // MARK: - time.clock Tests
    static let clockTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "x must be an integer",
            name: "time.clock",
            args: [42.5],
            expected: .failure(
                BuiltinError.evalError(msg: "timestamp must be an integer, but got a floating-point number"))
        ),
        BuiltinTests.TestCase(
            description: "timestamp too big",
            name: "time.clock",
            args: [.number(RegoNumber(nsNumber: UInt64.max as NSNumber))],
            expected: .failure(
                BuiltinError.evalError(msg: "timestamp too big"))
        ),
        BuiltinTests.TestCase(
            description: "x[0] must be an integer when array is used",
            name: "time.clock",
            args: [[42.5, "UTC"]],
            expected: .failure(
                BuiltinError.evalError(msg: "timestamp must be an integer, but got a floating-point number"))
        ),
        BuiltinTests.TestCase(
            description: "x[0] timestamp too big when array is used",
            name: "time.clock",
            args: [[.number(RegoNumber(nsNumber: UInt64.max as NSNumber)), "UTC"]],
            expected: .failure(
                BuiltinError.evalError(msg: "timestamp too big"))
        ),
        BuiltinTests.TestCase(
            description: "empty array",
            name: "time.clock",
            args: [[]],
            expected: .failure(
                BuiltinError.argumentTypeMismatch(
                    arg: "x",
                    got: "array",
                    want: "any<number[integer], array<number[integer], string>>")
            )
        ),
        BuiltinTests.TestCase(
            description: "single element array",
            name: "time.clock",
            args: [[123]],
            expected: .failure(
                BuiltinError.argumentTypeMismatch(
                    arg: "x",
                    got: "array",
                    want: "any<number[integer], array<number[integer], string>>")
            )
        ),
        BuiltinTests.TestCase(
            description: "long array",
            name: "time.clock",
            args: [[123, "UTC", 0]],
            expected: .failure(
                BuiltinError.argumentTypeMismatch(
                    arg: "x",
                    got: "array",
                    want: "any<number[integer], array<number[integer], string>>")
            )
        ),
        BuiltinTests.TestCase(
            description: "12:01:02 (defaults to UTC tz)",
            name: "time.clock",
            args: [1_517_832_062_000_000_000],
            expected: .success([12, 1, 2])
        ),
        BuiltinTests.TestCase(
            description: "12:01:02 in UTC tz",
            name: "time.clock",
            args: [[1_517_832_062_000_000_000, "UTC"]],
            expected: .success([12, 1, 2])
        ),
        BuiltinTests.TestCase(
            description: "7:01:02 in NYC tz",
            name: "time.clock",
            args: [[1_517_832_062_000_000_000, "America/New_York"]],
            expected: .success([7, 1, 2])
        ),
        BuiltinTests.TestCase(
            description: "12:00:00 in a leap day",
            name: "time.clock",
            args: [1_582_977_600_000_000_000],
            expected: .success([12, 0, 0])
        ),
        // Sub-second into new year: 2020-01-01 00:00:00.9 UTC — clock must be 00:00:00
        BuiltinTests.TestCase(
            description: "1ns truncation does not affect clock",
            name: "time.clock",
            args: [1_577_836_800_000_000_001],
            expected: .success([0, 0, 0])
        ),
        // Negative ns: -900_000_000 = 1969-12-31 23:59:59.1 UTC
        BuiltinTests.TestCase(
            description: "negative sub-second ns returns correct clock (pre-epoch)",
            name: "time.clock",
            args: [-900_000_000],
            expected: .success([23, 59, 59])
        ),
        BuiltinTests.TestCase(
            description: "unknown timezone",
            name: "time.clock",
            args: [[1_517_814_000_000_000_000, "foo/bar"]],
            expected: .failure(
                BuiltinError.evalError(msg: "unknown timezone: foo/bar"))
        ),
    ]

    // MARK: - time.date Tests
    static let dateTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "x must be an integer",
            name: "time.date",
            args: [42.5],
            expected: .failure(
                BuiltinError.evalError(msg: "timestamp must be an integer, but got a floating-point number"))
        ),
        BuiltinTests.TestCase(
            description: "timestamp too big",
            name: "time.date",
            args: [.number(RegoNumber(nsNumber: UInt64.max as NSNumber))],
            expected: .failure(
                BuiltinError.evalError(msg: "timestamp too big"))
        ),
        BuiltinTests.TestCase(
            description: "x[0] must be an integer when array is used",
            name: "time.date",
            args: [[42.5, "UTC"]],
            expected: .failure(
                BuiltinError.evalError(msg: "timestamp must be an integer, but got a floating-point number"))
        ),
        BuiltinTests.TestCase(
            description: "x[0] timestamp too big when array is used",
            name: "time.date",
            args: [[.number(RegoNumber(nsNumber: UInt64.max as NSNumber)), "UTC"]],
            expected: .failure(
                BuiltinError.evalError(msg: "timestamp too big"))
        ),
        BuiltinTests.TestCase(
            description: "empty array",
            name: "time.date",
            args: [[]],
            expected: .failure(
                BuiltinError.argumentTypeMismatch(
                    arg: "x",
                    got: "array",
                    want: "any<number[integer], array<number[integer], string>>")
            )
        ),
        BuiltinTests.TestCase(
            description: "single element array",
            name: "time.date",
            args: [[123]],
            expected: .failure(
                BuiltinError.argumentTypeMismatch(
                    arg: "x",
                    got: "array",
                    want: "any<number[integer], array<number[integer], string>>")
            )
        ),
        BuiltinTests.TestCase(
            description: "long array",
            name: "time.date",
            args: [[123, "UTC", 0]],
            expected: .failure(
                BuiltinError.argumentTypeMismatch(
                    arg: "x",
                    got: "array",
                    want: "any<number[integer], array<number[integer], string>>")
            )
        ),
        BuiltinTests.TestCase(
            description: "2018-02-05 (defaults to UTC tz)",
            name: "time.date",
            args: [1_517_814_000_000_000_000],
            expected: .success([2018, 2, 5])
        ),
        BuiltinTests.TestCase(
            description: "2018-02-05 in UTC tz",
            name: "time.date",
            args: [[1_517_814_000_000_000_000, "UTC"]],
            expected: .success([2018, 2, 5])
        ),
        BuiltinTests.TestCase(
            description: "2018-02-04 in LA tz",
            name: "time.date",
            args: [[1_517_814_000_000_000_000, "America/Los_Angeles"]],
            expected: .success([2018, 2, 4])
        ),
        BuiltinTests.TestCase(
            description: "2020-02-29 is a leap day",
            name: "time.date",
            args: [1_582_977_600_000_000_000],
            expected: .success([2020, 2, 29])
        ),
        // Sub-second into new year: 2020-01-01 00:00:00.9 UTC — date must be Jan 1
        BuiltinTests.TestCase(
            description: "1ns truncation does not affect date",
            name: "time.date",
            args: [1_577_836_800_000_000_001],
            expected: .success([2020, 1, 1])
        ),
        // Negative ns: -900_000_000 = 1969-12-31 23:59:59.1 UTC
        BuiltinTests.TestCase(
            description: "negative sub-second ns returns correct date (pre-epoch)",
            name: "time.date",
            args: [-900_000_000],
            expected: .success([1969, 12, 31])
        ),
        BuiltinTests.TestCase(
            description: "unknown timezone",
            name: "time.date",
            args: [[1_517_814_000_000_000_000, "foo/bar"]],
            expected: .failure(
                BuiltinError.evalError(msg: "unknown timezone: foo/bar"))
        ),
    ]

    // MARK: - time.weekday Tests
    static let weekdayTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "x must be an integer",
            name: "time.weekday",
            args: [42.5],
            expected: .failure(
                BuiltinError.evalError(msg: "timestamp must be an integer, but got a floating-point number"))
        ),
        BuiltinTests.TestCase(
            description: "timestamp too big",
            name: "time.weekday",
            args: [[.number(RegoNumber(nsNumber: UInt64.max as NSNumber)), "UTC"]],
            expected: .failure(
                BuiltinError.evalError(msg: "timestamp too big"))
        ),
        BuiltinTests.TestCase(
            description: "x[0] must be an integer when array is used",
            name: "time.weekday",
            args: [[42.5, "UTC"]],
            expected: .failure(
                BuiltinError.evalError(msg: "timestamp must be an integer, but got a floating-point number"))
        ),
        BuiltinTests.TestCase(
            description: "x[0] timestamp too big when array is used",
            name: "time.weekday",
            args: [[.number(RegoNumber(nsNumber: UInt64.max as NSNumber)), "UTC"]],
            expected: .failure(
                BuiltinError.evalError(msg: "timestamp too big"))
        ),
        BuiltinTests.TestCase(
            description: "empty array",
            name: "time.weekday",
            args: [[]],
            expected: .failure(
                BuiltinError.argumentTypeMismatch(
                    arg: "x",
                    got: "array",
                    want: "any<number[integer], array<number[integer], string>>")
            )
        ),
        BuiltinTests.TestCase(
            description: "single element array",
            name: "time.weekday",
            args: [[123]],
            expected: .failure(
                BuiltinError.argumentTypeMismatch(
                    arg: "x",
                    got: "array",
                    want: "any<number[integer], array<number[integer], string>>")
            )
        ),
        BuiltinTests.TestCase(
            description: "long array",
            name: "time.weekday",
            args: [[123, "UTC", 0]],
            expected: .failure(
                BuiltinError.argumentTypeMismatch(
                    arg: "x",
                    got: "array",
                    want: "any<number[integer], array<number[integer], string>>")
            )
        ),
        BuiltinTests.TestCase(
            description: "Monday",
            name: "time.weekday",
            args: [1_517_832_000_000_000_000],
            expected: .success("Monday")
        ),
        BuiltinTests.TestCase(
            description: "Tuesday",
            name: "time.weekday",
            args: [1_517_918_400_000_000_000],
            expected: .success("Tuesday")
        ),
        BuiltinTests.TestCase(
            description: "Wednesday",
            name: "time.weekday",
            args: [1_518_004_800_000_000_000],
            expected: .success("Wednesday")
        ),
        BuiltinTests.TestCase(
            description: "Thursday",
            name: "time.weekday",
            args: [1_518_091_200_000_000_000],
            expected: .success("Thursday")
        ),
        BuiltinTests.TestCase(
            description: "Friday",
            name: "time.weekday",
            args: [1_518_177_600_000_000_000],
            expected: .success("Friday")
        ),
        BuiltinTests.TestCase(
            description: "Saturday",
            name: "time.weekday",
            args: [1_518_264_000_000_000_000],
            expected: .success("Saturday")
        ),
        BuiltinTests.TestCase(
            description: "Sunday",
            name: "time.weekday",
            args: [1_518_350_400_000_000_000],
            expected: .success("Sunday")
        ),
        BuiltinTests.TestCase(
            description: "unknown timezone",
            name: "time.weekday",
            args: [[1_517_814_000_000_000_000, "foo/bar"]],
            expected: .failure(
                BuiltinError.evalError(msg: "unknown timezone: foo/bar"))
        ),
        // Negative ns: -900_000_000 = 1969-12-31 23:59:59.1 UTC (Wednesday)
        BuiltinTests.TestCase(
            description: "negative sub-second ns returns correct weekday (pre-epoch)",
            name: "time.weekday",
            args: [-900_000_000],
            expected: .success("Wednesday")
        ),
        // Sub-second into new year: 2020-01-01 00:00:00.000000001 UTC — weekday must be Wednesday
        BuiltinTests.TestCase(
            description: "1ns truncation does not affect weekday",
            name: "time.weekday",
            args: [1_577_836_800_000_000_001],
            expected: .success("Wednesday")
        ),
    ]

    // MARK: - time.parse_duration_ns Tests
    private static let validDurations: [(String, Int64)] = [
        ("5s", 5_000_000_000),
        ("5ms", 5_000_000),
        ("100ms", 100_000_000),
        ("5us", 5_000),
        ("5µs", 5_000),
        ("5ns", 5),
        ("1m", 60_000_000_000),
        ("1h", 3_600_000_000_000),
        ("-3µs", -3_000),
        ("1m10s", 70_000_000_000),
        ("1h10m11s5ms", 4_211_005_000_000),
        ("10ns10ns", 20),
        (" 10ns ", 10),
    ]

    private static let invalidDurations: [String] = [
        "1",
        "1f",
        "Ams",
        "--1m",
        "1m 10s",
        "1m10s foo",
    ]

    static let parseDurationNanosValidTests: [BuiltinTests.TestCase] = validDurations.map { (input, expected) in
        BuiltinTests.TestCase(
            description: "\(input)",
            name: "time.parse_duration_ns",
            args: [.string(input)],
            expected: .success(.number(RegoNumber(int: expected)))
        )
    }

    static let parseDurationNanosInvalidTests: [BuiltinTests.TestCase] = invalidDurations.map { input in
        BuiltinTests.TestCase(
            description: "invalid: \(input)",
            name: "time.parse_duration_ns",
            args: [.string(input)],
            expected: .failure(
                BuiltinError.evalError(msg: "invalid duration \"\(input)\""))
        )
    }

    // MARK: - time.format Tests
    static let formatTests: [BuiltinTests.TestCase] = [
        // Compliance suite cases
        BuiltinTests.TestCase(
            description: "bare ns → RFC3339Nano UTC",
            name: "time.format",
            args: [1_670_006_453_141_828_752],
            expected: .success("2022-12-02T18:40:53.141828752Z")
        ),
        BuiltinTests.TestCase(
            description: "ns + timezone → RFC3339Nano in timezone",
            name: "time.format",
            args: [[1_670_006_453_141_828_752, "Asia/Kolkata"]],
            expected: .success("2022-12-03T00:10:53.141828752+05:30")
        ),
        BuiltinTests.TestCase(
            description: "ns + timezone + custom layout",
            name: "time.format",
            args: [[1_670_006_453_141_828_752, "Asia/Kolkata", "Mon Jan 02 15:04:05 -0700 2006"]],
            expected: .success("Sat Dec 03 00:10:53 +0530 2022")
        ),
        BuiltinTests.TestCase(
            description: "ns + timezone + RFC1123Z alias",
            name: "time.format",
            args: [[1_670_006_453_141_828_752, "Asia/Kolkata", "RFC1123Z"]],
            expected: .success("Sat, 03 Dec 2022 00:10:53 +0530")
        ),
        // Named alias coverage — 2022-12-15T12:30:45.123456789Z (Thu) in America/New_York (EST = 07:30:45 -0500)
        BuiltinTests.TestCase(
            description: "ANSIC alias (no timezone in format)",
            name: "time.format",
            args: [[1_671_107_445_123_456_789, "America/New_York", "ANSIC"]],
            expected: .success("Thu Dec 15 07:30:45 2022")
        ),
        BuiltinTests.TestCase(
            description: "UnixDate alias",
            name: "time.format",
            args: [[1_671_107_445_123_456_789, "America/New_York", "UnixDate"]],
            expected: .success("Thu Dec 15 07:30:45 EST 2022")
        ),
        BuiltinTests.TestCase(
            description: "RubyDate alias",
            name: "time.format",
            args: [[1_671_107_445_123_456_789, "America/New_York", "RubyDate"]],
            expected: .success("Thu Dec 15 07:30:45 -0500 2022")
        ),
        BuiltinTests.TestCase(
            description: "RFC822 alias",
            name: "time.format",
            args: [[1_671_107_445_123_456_789, "America/New_York", "RFC822"]],
            expected: .success("15 Dec 22 07:30 EST")
        ),
        BuiltinTests.TestCase(
            description: "RFC822Z alias",
            name: "time.format",
            args: [[1_671_107_445_123_456_789, "America/New_York", "RFC822Z"]],
            expected: .success("15 Dec 22 07:30 -0500")
        ),
        BuiltinTests.TestCase(
            description: "RFC850 alias",
            name: "time.format",
            args: [[1_671_107_445_123_456_789, "America/New_York", "RFC850"]],
            expected: .success("Thursday, 15-Dec-22 07:30:45 EST")
        ),
        BuiltinTests.TestCase(
            description: "RFC1123 alias",
            name: "time.format",
            args: [[1_671_107_445_123_456_789, "America/New_York", "RFC1123"]],
            expected: .success("Thu, 15 Dec 2022 07:30:45 EST")
        ),
        BuiltinTests.TestCase(
            description: "RFC1123Z alias",
            name: "time.format",
            args: [[1_671_107_445_123_456_789, "America/New_York", "RFC1123Z"]],
            expected: .success("Thu, 15 Dec 2022 07:30:45 -0500")
        ),
        BuiltinTests.TestCase(
            description: "RFC3339 alias",
            name: "time.format",
            args: [[1_671_107_445_123_456_789, "America/New_York", "RFC3339"]],
            expected: .success("2022-12-15T07:30:45-05:00")
        ),
        BuiltinTests.TestCase(
            description: "RFC3339Nano alias",
            name: "time.format",
            args: [[1_671_107_445_123_456_789, "America/New_York", "RFC3339Nano"]],
            expected: .success("2022-12-15T07:30:45.123456789-05:00")
        ),
        // Epoch 0
        BuiltinTests.TestCase(
            description: "epoch zero → no fractional seconds",
            name: "time.format",
            args: [0],
            expected: .success("1970-01-01T00:00:00Z")
        ),
        // Format without fractional seconds
        BuiltinTests.TestCase(
            description: "RFC1123Z with UTC — no fractional seconds",
            name: "time.format",
            args: [[1_670_006_453_141_828_752, "UTC", "RFC1123Z"]],
            expected: .success("Fri, 02 Dec 2022 18:40:53 +0000")
        ),
        // Negative timestamp
        BuiltinTests.TestCase(
            description: "negative timestamp (pre-epoch)",
            name: "time.format",
            args: [-1_000_000_000],
            expected: .success("1969-12-31T23:59:59Z")
        ),
        // Error cases
        BuiltinTests.TestCase(
            description: "timestamp too big",
            name: "time.format",
            args: [.number(RegoNumber(nsNumber: UInt64.max as NSNumber))],
            expected: .failure(BuiltinError.evalError(msg: "timestamp too big"))
        ),
        BuiltinTests.TestCase(
            description: "non-integer ns",
            name: "time.format",
            args: [42.5],
            expected: .failure(
                BuiltinError.evalError(msg: "timestamp must be an integer, but got a floating-point number"))
        ),
        BuiltinTests.TestCase(
            description: "non-string timezone",
            name: "time.format",
            args: [[1_670_006_453_141_828_752, 42]],
            expected: .failure(
                BuiltinError.argumentTypeMismatch(arg: "timezone", got: "number", want: "string"))
        ),
        BuiltinTests.TestCase(
            description: "unknown timezone",
            name: "time.format",
            args: [[1_670_006_453_141_828_752, "Fake/Zone"]],
            expected: .failure(BuiltinError.evalError(msg: "unknown timezone: Fake/Zone"))
        ),
    ]

    // MARK: - time.diff Tests
    static let diffTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "ns1 must be an integer",
            name: "time.diff",
            args: [42.5, 1_000_000_000_000_000_000],
            expected: .failure(
                BuiltinError.evalError(msg: "timestamp must be an integer, but got a floating-point number"))
        ),
        BuiltinTests.TestCase(
            description: "ns2 must be an integer",
            name: "time.diff",
            args: [1_000_000_000_000_000_000, 42.5],
            expected: .failure(
                BuiltinError.evalError(msg: "timestamp must be an integer, but got a floating-point number"))
        ),
        BuiltinTests.TestCase(
            description: "minute and second difference",
            name: "time.diff",
            // base + 61s vs base → [0, 0, 0, 0, 1, 1]
            args: [1_000_000_061_000_000_000, 1_000_000_000_000_000_000],
            expected: .success([0, 0, 0, 0, 1, 1])
        ),
        BuiltinTests.TestCase(
            description: "order is irrelevant (always returns non-negative)",
            name: "time.diff",
            args: [1_000_000_000_000_000_000, 1_000_000_061_000_000_000],
            expected: .success([0, 0, 0, 0, 1, 1])
        ),
        BuiltinTests.TestCase(
            description: "equal timestamps",
            name: "time.diff",
            args: [1_000_000_000_000_000_000, 1_000_000_000_000_000_000],
            expected: .success([0, 0, 0, 0, 0, 0])
        ),
        // 2020-02-02 → 2020-03-01: Feb 2020 has 29 days (leap year), so 29-2=27 remaining + 1 day = 28 days
        BuiltinTests.TestCase(
            description: "leap year: 2020-02-02 to 2020-03-01 = 28 days",
            name: "time.diff",
            args: [1_580_601_600_000_000_000, 1_583_020_800_000_000_000],
            expected: .success([0, 0, 28, 0, 0, 0])
        ),
        // 2021-02-02 → 2021-03-01: Feb 2021 has 28 days (not leap year), so 28-2=26 remaining + 1 day = 27 days
        BuiltinTests.TestCase(
            description: "non-leap year: 2021-02-02 to 2021-03-01 = 27 days",
            name: "time.diff",
            args: [1_612_224_000_000_000_000, 1_614_556_800_000_000_000],
            expected: .success([0, 0, 27, 0, 0, 0])
        ),
        // 2004-02-29 → 2005-03-01: 1 year, 0 months, 1 day
        BuiltinTests.TestCase(
            description: "leap day: 2004-02-29 to 2005-03-01 = 1 year 1 day",
            name: "time.diff",
            args: [1_078_012_800_000_000_000, 1_109_635_200_000_000_000],
            expected: .success([1, 0, 1, 0, 0, 0])
        ),
        // Timezone tests: noon in LA vs noon in NY.
        // LA and NY always differ by 3 hours (both observe DST together).
        BuiltinTests.TestCase(
            description: "LA vs NY during DST (2025-07-04 noon): 3 hours apart",
            name: "time.diff",
            // LA noon (PDT=UTC-7): 2025-07-04T19:00:00Z = 1751655600
            // NY noon (EDT=UTC-4): 2025-07-04T16:00:00Z = 1751644800
            args: [
                [1_751_655_600_000_000_000, "America/Los_Angeles"], [1_751_644_800_000_000_000, "America/New_York"],
            ],
            expected: .success([0, 0, 0, 3, 0, 0])
        ),
        BuiltinTests.TestCase(
            description: "LA vs NY outside DST (2025-01-15 noon): 3 hours apart",
            name: "time.diff",
            // LA noon (PST=UTC-8): 2025-01-15T20:00:00Z = 1736971200
            // NY noon (EST=UTC-5): 2025-01-15T17:00:00Z = 1736960400
            args: [
                [1_736_971_200_000_000_000, "America/Los_Angeles"], [1_736_960_400_000_000_000, "America/New_York"],
            ],
            expected: .success([0, 0, 0, 3, 0, 0])
        ),
        // Timezone tests: noon in LA vs noon in UTC.
        // During DST, LA is UTC-7 → 7 hours; outside DST, LA is UTC-8 → 8 hours.
        BuiltinTests.TestCase(
            description: "LA vs UTC during DST (2025-07-04 noon): 7 hours apart (PDT=UTC-7)",
            name: "time.diff",
            // LA noon (PDT=UTC-7): 2025-07-04T19:00:00Z = 1751655600
            // UTC noon: 2025-07-04T12:00:00Z = 1751630400
            args: [[1_751_655_600_000_000_000, "America/Los_Angeles"], [1_751_630_400_000_000_000, "UTC"]],
            expected: .success([0, 0, 0, 7, 0, 0])
        ),
        BuiltinTests.TestCase(
            description: "LA vs UTC outside DST (2025-01-15 noon): 8 hours apart (PST=UTC-8)",
            name: "time.diff",
            // LA noon (PST=UTC-8): 2025-01-15T20:00:00Z = 1736971200
            // UTC noon: 2025-01-15T12:00:00Z = 1736942400
            args: [[1_736_971_200_000_000_000, "America/Los_Angeles"], [1_736_942_400_000_000_000, "UTC"]],
            expected: .success([0, 0, 0, 8, 0, 0])
        ),
        // All 5 icza/gox normalizations cascade:
        //   raw: year=1, month=0, day=-30, hour=-1, min=-1, sec=-1
        //   sec=-1  → sec=59,  min=-2
        //   min=-2  → min=58,  hour=-2
        //   hour=-2 → hour=22, day=-31
        //   day=-31, daysInMonth(Mar 2026)=31 → day=0, month=-1
        //   month=-1 → month=11, year=0
        BuiltinTests.TestCase(
            description: "all 5 normalizations: 2026-03-31 23:59:59 → 2027-03-01 22:58:58",
            name: "time.diff",
            args: [1_775_001_599_000_000_000, 1_803_941_938_000_000_000],
            expected: .success([0, 11, 0, 22, 58, 59])
        ),
        BuiltinTests.TestCase(
            description: "unknown timezone in first argument",
            name: "time.diff",
            args: [[1_000_000_000_000_000_000, "Fake/Zone"], 1_000_000_000_000_000_000],
            expected: .failure(BuiltinError.evalError(msg: "unknown timezone: Fake/Zone"))
        ),
        BuiltinTests.TestCase(
            description: "unknown timezone in second argument",
            name: "time.diff",
            args: [1_000_000_000_000_000_000, [1_000_000_000_000_000_000, "Fake/Zone"]],
            expected: .failure(BuiltinError.evalError(msg: "unknown timezone: Fake/Zone"))
        ),
        // OPA converts t2 into t1's timezone before calendar decomposition (time.go: t2 = t2.In(t1.Location())).
        // t1 = [1751655600, LA] = 2025-07-04 12:00:00 PDT; t2 = 1751630400 (UTC) = 2025-07-04 12:00:00 UTC.
        // t2 converted to PDT = 2025-07-04 05:00:00 PDT → diff = 7 hours.
        BuiltinTests.TestCase(
            description: "explicit LA timezone vs implicit UTC: 2025-07-04 noon each, 7 hours apart",
            name: "time.diff",
            // LA noon PDT: 2025-07-04T19:00:00Z = 1751655600
            // UTC noon:    2025-07-04T12:00:00Z = 1751630400 (no timezone → UTC)
            args: [[1_751_655_600_000_000_000, "America/Los_Angeles"], 1_751_630_400_000_000_000],
            expected: .success([0, 0, 0, 7, 0, 0])
        ),
    ]

    // MARK: - time.parse_ns Tests
    // Reference: 2017-06-02T19:00:00-07:00 = 2017-06-03T02:00:00Z = 1_496_455_200_000_000_000 ns
    static let parseNanosTests: [BuiltinTests.TestCase] = [
        // Named aliases
        BuiltinTests.TestCase(
            description: "RFC3339 alias",
            name: "time.parse_ns",
            args: ["RFC3339", "2017-06-02T19:00:00-07:00"],
            expected: .success(1_496_455_200_000_000_000)
        ),
        BuiltinTests.TestCase(
            description: "RFC3339Nano alias - fractional stripped",
            name: "time.parse_ns",
            args: ["RFC3339Nano", "2017-06-02T19:00:00.000000000-07:00"],
            expected: .success(1_496_455_200_000_000_000)
        ),
        BuiltinTests.TestCase(
            description: "RFC1123Z alias",
            name: "time.parse_ns",
            args: ["RFC1123Z", "Fri, 02 Jun 2017 19:00:00 -0700"],
            expected: .success(1_496_455_200_000_000_000)
        ),
        BuiltinTests.TestCase(
            description: "RFC822Z alias",
            name: "time.parse_ns",
            args: ["RFC822Z", "02 Jun 17 19:00 -0700"],
            expected: .success(1_496_455_200_000_000_000)
        ),
        BuiltinTests.TestCase(
            description: "RubyDate alias",
            name: "time.parse_ns",
            args: ["RubyDate", "Fri Jun 02 19:00:00 -0700 2017"],
            expected: .success(1_496_455_200_000_000_000)
        ),
        // Additional named aliases — 2022-12-15T12:30:45.123456789Z (Thu) in America/New_York (EST = 07:30:45)
        // Fractional seconds are accepted even when the format omits them (mirrors Go's time.Parse).
        BuiltinTests.TestCase(
            description: "ANSIC alias (no timezone → defaults to UTC, with fractional seconds)",
            name: "time.parse_ns",
            args: ["ANSIC", "Thu Dec 15 07:30:45.123456789 2022"],
            expected: .success(1_671_089_445_123_456_789)
        ),
        BuiltinTests.TestCase(
            description: "UnixDate alias with fractional seconds",
            name: "time.parse_ns",
            args: ["UnixDate", "Thu Dec 15 07:30:45.123456789 EST 2022"],
            expected: .success(1_671_107_445_123_456_789)
        ),
        BuiltinTests.TestCase(
            description: "RFC822 alias (no seconds field)",
            name: "time.parse_ns",
            args: ["RFC822", "15 Dec 22 07:30 EST"],
            expected: .success(1_671_107_400_000_000_000)
        ),
        BuiltinTests.TestCase(
            description: "RFC850 alias with fractional seconds",
            name: "time.parse_ns",
            args: ["RFC850", "Thursday, 15-Dec-22 07:30:45.123456789 EST"],
            expected: .success(1_671_107_445_123_456_789)
        ),
        BuiltinTests.TestCase(
            description: "RFC1123 alias with fractional seconds",
            name: "time.parse_ns",
            args: ["RFC1123", "Thu, 15 Dec 2022 07:30:45.123456789 EST"],
            expected: .success(1_671_107_445_123_456_789)
        ),
        // Custom formats — individual token coverage
        BuiltinTests.TestCase(
            description: "custom RFC3339 format (same as alias)",
            name: "time.parse_ns",
            args: ["2006-01-02T15:04:05Z07:00", "2017-06-02T19:00:00-07:00"],
            expected: .success(1_496_455_200_000_000_000)
        ),
        BuiltinTests.TestCase(
            description: "full month name (January token)",
            name: "time.parse_ns",
            args: ["January 02 2006 15:04:05Z07:00", "June 02 2017 19:00:00-07:00"],
            expected: .success(1_496_455_200_000_000_000)
        ),
        BuiltinTests.TestCase(
            description: "abbreviated month name (Jan token)",
            name: "time.parse_ns",
            args: ["Jan 02 2006 15:04:05Z07:00", "Jun 02 2017 19:00:00-07:00"],
            expected: .success(1_496_455_200_000_000_000)
        ),
        BuiltinTests.TestCase(
            description: "full weekday name (Monday token)",
            name: "time.parse_ns",
            args: ["Monday, January 02 2006 15:04:05Z07:00", "Friday, June 02 2017 19:00:00-07:00"],
            expected: .success(1_496_455_200_000_000_000)
        ),
        BuiltinTests.TestCase(
            description: "2-digit year (06 token)",
            name: "time.parse_ns",
            args: ["01/02/06 15:04:05Z07:00", "06/02/17 19:00:00-07:00"],
            expected: .success(1_496_455_200_000_000_000)
        ),
        BuiltinTests.TestCase(
            description: "numeric -0700 timezone offset",
            name: "time.parse_ns",
            args: ["2006-01-02T15:04:05-0700", "2017-06-02T19:00:00-0700"],
            expected: .success(1_496_455_200_000_000_000)
        ),
        BuiltinTests.TestCase(
            description: "no timezone in format defaults to UTC",
            name: "time.parse_ns",
            args: ["2006-01-02 15:04:05", "2017-06-03 02:00:00"],
            expected: .success(1_496_455_200_000_000_000)
        ),
        BuiltinTests.TestCase(
            description: "AM/PM (PM token) and literal apostrophe ('06 year)",
            name: "time.parse_ns",
            args: ["01/02 03:04:05PM '06 -0700", "06/02 07:00:00PM '17 -0700"],
            expected: .success(1_496_455_200_000_000_000)
        ),
        // Go always accepts fractional seconds even when not in the format
        BuiltinTests.TestCase(
            description: "fractional seconds accepted even when not in format",
            name: "time.parse_ns",
            args: ["2006-01-02T15:04:05Z07:00", "2017-06-02T19:00:00.123456789-07:00"],
            expected: .success(1_496_455_200_123_456_789)
        ),
        BuiltinTests.TestCase(
            description: "fractional seconds truncated to 9 digits",
            name: "time.parse_ns",
            args: ["2006-01-02T15:04:05Z07:00", "2017-06-02T19:00:00.1-07:00"],
            expected: .success(1_496_455_200_100_000_000)
        ),
        // Boundary values
        BuiltinTests.TestCase(
            description: "Int64.min boundary (1677-09-21T00:12:43.145224192Z)",
            name: "time.parse_ns",
            args: ["2006-01-02T15:04:05Z07:00", "1677-09-21T00:12:43.145224192-00:00"],
            expected: .success(.number(RegoNumber(int: Int64.min)))
        ),
        BuiltinTests.TestCase(
            description: "Int64.max boundary (2262-04-11T23:47:16.854775807Z)",
            name: "time.parse_ns",
            args: ["2006-01-02T15:04:05Z07:00", "2262-04-11T23:47:16.854775807-00:00"],
            expected: .success(.number(RegoNumber(int: Int64.max)))
        ),
        // Error cases
        BuiltinTests.TestCase(
            description: "one nanosecond before Int64.min throws",
            name: "time.parse_ns",
            args: ["2006-01-02T15:04:05Z07:00", "1677-09-21T00:12:43.145224191-00:00"],
            expected: .failure(BuiltinError.evalError(msg: "time outside of valid range"))
        ),
        BuiltinTests.TestCase(
            description: "one nanosecond after Int64.max throws",
            name: "time.parse_ns",
            args: ["2006-01-02T15:04:05Z07:00", "2262-04-11T23:47:16.854775808-00:00"],
            expected: .failure(BuiltinError.evalError(msg: "time outside of valid range"))
        ),
        BuiltinTests.TestCase(
            description: "unparseable value",
            name: "time.parse_ns",
            args: ["2006-01-02", "not-a-date"],
            expected: .failure(
                BuiltinError.evalError(
                    msg: "time.parse_ns: failed to parse \"not-a-date\" with format \"2006-01-02\""))
        ),
        BuiltinTests.TestCase(
            description: "non-string format",
            name: "time.parse_ns",
            args: [42, "2017-06-02T19:00:00-07:00"],
            expected: .failure(
                BuiltinError.argumentTypeMismatch(arg: "format", got: "number", want: "string"))
        ),
        BuiltinTests.TestCase(
            description: "non-string value",
            name: "time.parse_ns",
            args: ["RFC3339", 42],
            expected: .failure(
                BuiltinError.argumentTypeMismatch(arg: "value", got: "number", want: "string"))
        ),
    ]

    // MARK: - time.parse_rfc3339_ns Tests
    static let parseRFC3339NanosTests: [BuiltinTests.TestCase] = [
        BuiltinTests.TestCase(
            description: "basic RFC3339",
            name: "time.parse_rfc3339_ns",
            args: ["2017-06-02T19:00:00-07:00"],
            expected: .success(1_496_455_200_000_000_000)
        ),
        BuiltinTests.TestCase(
            description: "UTC via +00:00",
            name: "time.parse_rfc3339_ns",
            args: ["1970-01-01T00:00:00+00:00"],
            expected: .success(0)
        ),
        BuiltinTests.TestCase(
            description: "UTC via Z suffix",
            name: "time.parse_rfc3339_ns",
            args: ["1970-01-01T00:00:00Z"],
            expected: .success(0)
        ),
        BuiltinTests.TestCase(
            description: "fractional seconds — nanosecond precision",
            name: "time.parse_rfc3339_ns",
            args: ["2017-06-02T19:00:00.123456789-07:00"],
            expected: .success(1_496_455_200_123_456_789)
        ),
        BuiltinTests.TestCase(
            description: "fractional seconds — millisecond precision",
            name: "time.parse_rfc3339_ns",
            args: ["2017-06-02T19:00:00.123-07:00"],
            expected: .success(1_496_455_200_123_000_000)
        ),
        BuiltinTests.TestCase(
            description: "fractional seconds — single digit",
            name: "time.parse_rfc3339_ns",
            args: ["2017-06-02T19:00:00.1-07:00"],
            expected: .success(1_496_455_200_100_000_000)
        ),
        // Boundary values
        BuiltinTests.TestCase(
            description: "Int64.min boundary",
            name: "time.parse_rfc3339_ns",
            args: ["1677-09-21T00:12:43.145224192-00:00"],
            expected: .success(.number(RegoNumber(int: Int64.min)))
        ),
        BuiltinTests.TestCase(
            description: "Int64.max boundary",
            name: "time.parse_rfc3339_ns",
            args: ["2262-04-11T23:47:16.854775807-00:00"],
            expected: .success(.number(RegoNumber(int: Int64.max)))
        ),
        BuiltinTests.TestCase(
            description: "one nanosecond before Int64.min throws",
            name: "time.parse_rfc3339_ns",
            args: ["1677-09-21T00:12:43.145224191-00:00"],
            expected: .failure(BuiltinError.evalError(msg: "time outside of valid range"))
        ),
        BuiltinTests.TestCase(
            description: "one nanosecond after Int64.max throws",
            name: "time.parse_rfc3339_ns",
            args: ["2262-04-11T23:47:16.854775808-00:00"],
            expected: .failure(BuiltinError.evalError(msg: "time outside of valid range"))
        ),
        BuiltinTests.TestCase(
            description: "unparseable value",
            name: "time.parse_rfc3339_ns",
            args: ["not-a-date"],
            expected: .failure(
                BuiltinError.evalError(msg: "time.parse_rfc3339_ns: failed to parse \"not-a-date\""))
        ),
        BuiltinTests.TestCase(
            description: "non-string arg",
            name: "time.parse_rfc3339_ns",
            args: [42],
            expected: .failure(
                BuiltinError.argumentTypeMismatch(arg: "value", got: "number", want: "string"))
        ),
    ]

    // MARK: - All time Tests
    static var allTests: [BuiltinTests.TestCase] {
        [
            BuiltinTests.generateFailureTests(
                builtinName: "time.add_date", sampleArgs: [1_585_852_421_593_912_000, 3, 9, 12], argIndex: 0,
                argName: "ns",
                allowedArgTypes: ["number[integer]"],
                generateNumberOfArgsTest: true, numberAsInteger: true),
            BuiltinTests.generateFailureTests(
                builtinName: "time.add_date", sampleArgs: [1_585_852_421_593_912_000, 3, 9, 12], argIndex: 1,
                argName: "years",
                allowedArgTypes: ["number[integer]"],
                generateNumberOfArgsTest: false, numberAsInteger: true),
            BuiltinTests.generateFailureTests(
                builtinName: "time.add_date", sampleArgs: [1_585_852_421_593_912_000, 3, 9, 12], argIndex: 2,
                argName: "months",
                allowedArgTypes: ["number[integer]"],
                generateNumberOfArgsTest: false, numberAsInteger: true),
            BuiltinTests.generateFailureTests(
                builtinName: "time.add_date", sampleArgs: [1_585_852_421_593_912_000, 3, 9, 12], argIndex: 3,
                argName: "days",
                allowedArgTypes: ["number[integer]"],
                generateNumberOfArgsTest: false, numberAsInteger: true),
            BuiltinTests.generateFailureTests(
                builtinName: "time.clock", sampleArgs: [[1_585_852_421_593_912_000, "UTC"]], argIndex: 0,
                argName: "x",
                allowedArgTypes: ["array", "number[integer]"],
                wantArgs: "any<number[integer], array<number[integer], string>>",
                generateNumberOfArgsTest: true, numberAsInteger: true),
            BuiltinTests.generateFailureTests(
                builtinName: "time.date", sampleArgs: [[1_585_852_421_593_912_000, "UTC"]], argIndex: 0,
                argName: "x",
                allowedArgTypes: ["array", "number[integer]"],
                wantArgs: "any<number[integer], array<number[integer], string>>",
                generateNumberOfArgsTest: true, numberAsInteger: true),
            BuiltinTests.generateFailureTests(
                builtinName: "time.weekday", sampleArgs: [[1_585_852_421_593_912_000, "UTC"]], argIndex: 0,
                argName: "x",
                allowedArgTypes: ["array", "number[integer]"],
                wantArgs: "any<number[integer], array<number[integer], string>>",
                generateNumberOfArgsTest: true, numberAsInteger: true),
            BuiltinTests.generateNumberOfArgumentsFailureTests(
                builtinName: "time.diff", sampleArgs: [1_585_852_421_593_912_000, 1_585_852_421_593_912_000]),
            BuiltinTests.generateFailureTests(
                builtinName: "time.format", sampleArgs: [1_670_006_453_141_828_752], argIndex: 0,
                argName: "x",
                allowedArgTypes: ["array", "number[integer]"],
                wantArgs:
                    "any<number[integer], array<number[integer], string>, array<number[integer], string, string>>",
                generateNumberOfArgsTest: true, numberAsInteger: true),
            BuiltinTests.generateNumberOfArgumentsFailureTests(
                builtinName: "time.now_ns", sampleArgs: []),
            BuiltinTests.generateFailureTests(
                builtinName: "time.parse_duration_ns", sampleArgs: ["100ms"], argIndex: 0,
                argName: "duration",
                allowedArgTypes: ["string"],
                generateNumberOfArgsTest: true),
            BuiltinTests.generateNumberOfArgumentsFailureTests(
                builtinName: "time.parse_ns", sampleArgs: ["RFC3339", "2017-06-02T19:00:00-07:00"]),
            BuiltinTests.generateNumberOfArgumentsFailureTests(
                builtinName: "time.parse_rfc3339_ns", sampleArgs: ["2017-06-02T19:00:00-07:00"]),
            addDateTests,
            clockTests,
            dateTests,
            parseDurationNanosValidTests,
            parseDurationNanosInvalidTests,
            weekdayTests,
            diffTests,
            formatTests,
            parseNanosTests,
            parseRFC3339NanosTests,
        ].flatMap { $0 }
    }

    @Test(arguments: allTests)
    func testBuiltins(tc: BuiltinTests.TestCase) async throws {
        try await BuiltinTests.testBuiltin(tc: tc)
    }

    // MARK: - time.now_ns Tests
    @Test
    func timeNowNanosReturnsValidTime() async throws {
        let expected = UInt64(Date().timeIntervalSince1970 * 1_000_000_000)
        let reg = BuiltinRegistry.defaultRegistry
        let ctx = BuiltinContext()
        let result = try await reg.invoke(withContext: ctx, name: "time.now_ns", args: [], strict: true)
        // Make sure the output is *actually* an integer that represents time
        switch result {
        case .number(let actual):
            #expect(actual.clampedUint64Value >= expected)
        default:
            Issue.record("time.now_ns should return a number, but got: \(result)")
        }
    }

    @Test
    func timeNowNanosReturnsTimeFromContext() async throws {
        let expected = Date()
        let reg = BuiltinRegistry.defaultRegistry
        let ctx = BuiltinContext(timestamp: expected)
        let result = try await reg.invoke(withContext: ctx, name: "time.now_ns", args: [], strict: true)
        // Make sure the output is *actually* an integer that represents current time
        switch result {
        case .number(let actual):
            #expect(actual.clampedUint64Value == UInt64(expected.timeIntervalSince1970 * 1_000_000_000))
        default:
            Issue.record("time.now_ns should return a number, but got: \(result)")
        }
    }

    @Test
    func timeNowNanosReturnsSameValueForSameContext() async throws {
        let reg = BuiltinRegistry.defaultRegistry
        let ctx = BuiltinContext()
        let result1 = try await reg.invoke(withContext: ctx, name: "time.now_ns", args: [], strict: true)
        let result2 = try await reg.invoke(withContext: ctx, name: "time.now_ns", args: [], strict: true)
        #expect(result1 == result2)
    }

    @Test
    func timeNowNanosReturnsDifferentValuesForDifferentContexts() async throws {
        let reg = BuiltinRegistry.defaultRegistry
        let ctx1 = BuiltinContext()
        let ctx2 = BuiltinContext(timestamp: ctx1.timestamp.addingTimeInterval(2))
        let result1 = try await reg.invoke(withContext: ctx1, name: "time.now_ns", args: [], strict: true)
        let result2 = try await reg.invoke(withContext: ctx2, name: "time.now_ns", args: [], strict: true)
        #expect(result2 > result1)
    }

    // MARK: - parseDurationNanoseconds Tests
    @Test(arguments: validDurations)
    func parseValidDurations(arg: (String, Int64)) throws {
        let result = try BuiltinFuncs.parseDurationNanoseconds(arg.0)
        #expect(result == arg.1)
    }

    @Test(arguments: invalidDurations)
    func parseInvalidDurations(arg: String) {
        #expect(throws: BuiltinFuncs.DurationParseError.invalidFormat) {
            try BuiltinFuncs.parseDurationNanoseconds(arg)
        }
    }
}
