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
private let complianceTestsConfigFlag = "OPA_COMPLIANCE_TESTS_CONFIG"
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

    /// Subset of ``allCases`` that can run through the synchronous evaluation path.
    /// Excludes cases that rely on async-only builtins (e.g. `test.sleep`).
    static var syncCases: [ComplianceTesting.IRTestCase] {
        get throws {
            try allCases.filter { !ComplianceTesting.requiresAsyncBuiltins($0) }
        }
    }

    @Test(arguments: try allCases)
    func testCompliance(tc: ComplianceTesting.IRTestCase) async throws {
        let testConfig = try ComplianceTests.testConfig

        // Run our test. result.error will be non-nil for any kind of test failure,
        // be it an unexpected error, an expected error that wasn't there, or some other expectation
        // mismatch.
        print("\t🧬 executing \(tc.testDescription)")
        let result = try await ComplianceTesting.runTestAsync(
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

    @Test(arguments: try syncCases)
    func testComplianceSync(tc: ComplianceTesting.IRTestCase) async throws {
        let testConfig = try ComplianceTests.testConfig

        print("\t🧬 executing (sync) \(tc.testDescription)")
        let result = await ComplianceTesting.runTestSync(config: testConfig, tc)
        if testConfig.traceLevel != .none && result.trace != nil {
            result.trace!.prettyPrint(to: .standardOutput)
        }

        guard let err = result.error else {
            print("\t✅ \(tc.testDescription)")
            return
        }

        if let knownIssue = result.knownIssue {
            withKnownIssue(Comment(stringLiteral: "\t⏭️ \(knownIssue)")) {
                throw err
            }
            return
        }

        #expect(throws: Never.self, Comment(stringLiteral: "\t❌ \(tc.testDescription): \(err)")) {
            throw err
        }
        return
    }

    fileprivate static var customBuiltins: [String: AsyncBuiltin] {
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

        guard let timeDuration = try? BuiltinFuncs.parseDurationNanoseconds(x), timeDuration > 0 else {
            return .null
        }

        try await Task.sleep(nanoseconds: UInt64(timeDuration))

        return .null
    }
}
