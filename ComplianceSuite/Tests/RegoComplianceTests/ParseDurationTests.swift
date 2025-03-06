import Testing

@Suite("Duration Parsing Tests")
struct ParseDurationTests {
    static let durationArguments: [(String, Int)] = [
        ("5s", 5 * 1_000_000_000),
        ("5ms", 5 * 1_000_000),
        ("5us", 5 * 1_000),
        ("5µs", 5 * 1_000),
        ("5ns", 5),
        ("1m", 1 * 60 * 1_000_000_000),
        ("1h", 1 * 60 * 60 * 1_000_000_000),
        // Negative values
        ("-3µs", -3 * 1_000),
        // Composite Values
        ("1m10s", 1 * 60 * 1_000_000_000 + 10 * 1_000_000_000),
        ("1h10m11s5ms", 1 * 60 * 60 * 1_000_000_000 + 10 * 60 * 1_000_000_000 + 11 * 1_000_000_000 + 5 * 1_000_000),
        ("10ns10ns", 20),
        (" 10ns ", 10),  // spaces are successfully ignored
    ]

    @Test(arguments: durationArguments)
    func parseValidDurationsTest(arg: (String, Int)) {
        let result = try? TestBuiltins.parseDurationNanoseconds(arg.0)
        #expect(result != nil)
        #expect(result! == arg.1)
    }

    static let invalidDurations: [String] = [
        "1",  // no unit
        "1f",  // unknown unit
        "Ams",  // not a numeric value
        "--1m",  // double minus
        "1m 10s",  // space in the middle is not okay
        "1m10s foo",  // unknown string at the end
    ]

    @Test(arguments: invalidDurations)
    func parseInvalidDurationsTest(arg: String) {
        #expect(throws: TestBuiltins.DurationParseError.invalidFormat) {
            try TestBuiltins.parseDurationNanoseconds(arg)
        }
    }

}
