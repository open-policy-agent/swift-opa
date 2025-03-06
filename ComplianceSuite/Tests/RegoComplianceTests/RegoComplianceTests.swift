import AST
import Foundation
import IR
import Testing

@testable import Rego
@testable import RegoCompliance

extension Tag {
    @Tag static var compliance: Self
}

private let complianceFilterFlag = "OPA_COMPLIANCE_TESTS"
private let complianceTraceLevelFlag = "OPA_COMPLIANCE_TRACE"
private let complianceTestsConfigFlag = "OPA_COMPLINACE_TESTS_CONFIG"
private let complianceSkipKnownIssuesFlag = "OPA_COMPLIANCE_TESTS_SKIP_KNOWN_ISSUES"

// Feature flag compliance tests, set OPA_COMPLIANCE_TESTS=... to run
func complianceEnabled() -> Bool {
    return ProcessInfo.processInfo.environment[complianceFilterFlag] != nil
}

@Suite("Compliance Tests", .tags(.compliance), .enabled(if: complianceEnabled()))
struct ComplianceTests {
    // testFilterFromEnv is an environment-variable based mechanism for running only
    // conformance tests from files matching the filter.
    // To set a filter, set OPA_COMPLIANCE_TESTS to the test regex matching test cases
    // you want to run.
    static func testFilterFromEnv() -> String? {
        let v = ProcessInfo.processInfo.environment[complianceFilterFlag]
        guard let v else {
            return nil
        }
        return v
    }

    // Feature flag controlling compliance test trace level [none|full]
    static func complianceTraceLevelFromEnv() -> OPA.Trace.Level {
        let v = ProcessInfo.processInfo.environment[complianceTraceLevelFlag]
        guard let v else {
            return .none
        }
        return switch v.lowercased() {
        case "full":
            .full
        default:
            .none
        }
    }

    static func complianceSkipKnownIssuesFromEnv() -> Bool {
        return ProcessInfo.processInfo.environment[complianceSkipKnownIssuesFlag] != nil
    }

    static func complianceTestKnownIssues() throws -> [KnownIssue] {
        // Load the config file at the root of the repo,
        // unless an environment variable override is in place
        let v = ProcessInfo.processInfo.environment[complianceTestsConfigFlag]
        let cfgURL: URL
        if let v {
            cfgURL = URL(fileURLWithPath: v)
        } else {
            cfgURL = Bundle.module.resourceURL!
                .appendingPathComponent("TestData")
                .appendingPathComponent("rego-compliance.config")
        }
        let jsonData = try Data(contentsOf: cfgURL)
        let cfg = try JSONDecoder().decode(ComplianceTestConfig.self, from: jsonData)
        return cfg.knownIssues
    }

    static var testConfig: ComplianceTesting.TestConfig {
        get throws {
            return try ComplianceTesting.TestConfig(
                knownIssues: try complianceTestKnownIssues(),
                skipKnownIssues: complianceSkipKnownIssuesFromEnv(),
                sourceURL: Bundle.module.resourceURL!,
                testFilter: testFilterFromEnv(),
                traceLevel: complianceTraceLevelFromEnv()
            )
        }
    }

    static var allCases: [ComplianceTesting.IRTestCase] {
        get throws {
            let cases = try ComplianceTesting.loadAllTestCases(testConfig)
            return cases
        }
    }

    @Test(arguments: try allCases)
    func testCompliance(tc: ComplianceTesting.IRTestCase) async throws {
        let testConfig = try ComplianceTests.testConfig

        // Run our test. result.error will be non-nil for any kind of test failure,
        // be it an unexpected error, an expected error that wasn't there, or some other expectation
        // mismatch.
        print("\t🧬 executing \(tc.testDescription)")
        let result = try await ComplianceTesting.runTest(
            config: ComplianceTests.testConfig, tc, ComplianceTests.customBuiltins)
        if testConfig.traceLevel != .none && result.trace != nil {
            result.trace!.prettyPrint(to: .standardOutput)
        }

        // Success, we're done here
        guard let err = result.error else {
            print("\t✅ \(tc.testDescription)")
            return
        }

        // Errors, on the other hand - we need to check if they're known
        // issues or not.
        if let knownIssue = result.knownIssue {
            withKnownIssue(Comment(stringLiteral: "\t⏭️ \(knownIssue)")) {
                throw err
            }
            return  // no error on this case, but the test should be marked as skipped
        }

        #expect(throws: Never.self, Comment(stringLiteral: "\t❌ \(tc.testDescription): \(err)")) {
            throw err
        }
        return
    }

    fileprivate static var customBuiltins: [String: Builtin] {
        return [
            "test.sleep": TestBuiltins.testSleep
        ]
    }
}

extension ComplianceTesting.IRTestCase: CustomTestStringConvertible {
    public var testDescription: String { "\(description)" }
}

struct TestBuiltins {
    static func testSleep(ctx: BuiltinContext, args: [AST.RegoValue]) async throws -> AST.RegoValue {
        guard args.count == 1 else {
            throw BuiltinError.argumentCountMismatch(got: args.count, want: 1)
        }

        guard case .string(let x) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "string")
        }

        guard let timeDuration = try? parseDurationNanoseconds(x), timeDuration > 0 else {
            return .null
        }

        try await Task.sleep(nanoseconds: UInt64(timeDuration))

        return .null
    }

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
        if duration.hasPrefix("-") {
            isNegative = true
            durationValue = String(duration.dropFirst())
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
}
