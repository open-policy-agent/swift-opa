import Foundation

/// A single Rego test case found in a compiled IR policy.
///
/// Test cases are Rego rules whose names begin with `test_`. Rules
/// beginning with `todo_test_` are found but marked ``skipped`` and never
/// evaluated.
public struct TestCase: Hashable, Sendable {
    /// Fully-qualified query name, e.g. `data.authz_test.test_post_allowed`.
    public let name: String
    /// IR plan name used to invoke the generated wrapper, e.g. `authz_test/test_post_allowed`.
    public let planName: String
    /// The IR func name that implements the test, e.g. `g0.data.authz_test.test_post_allowed`.
    public let funcName: String
    /// Whether this test is skipped (a `todo_test_` rule).
    public let skipped: Bool
    /// Source file name the test was compiled from, when available (for verbose output).
    public let file: String?
    /// Source row the test was compiled from, when available (for verbose output).
    public let row: Int?

    public init(
        name: String,
        planName: String,
        funcName: String,
        skipped: Bool,
        file: String? = nil,
        row: Int? = nil
    ) {
        self.name = name
        self.planName = planName
        self.funcName = funcName
        self.skipped = skipped
        self.file = file
        self.row = row
    }
}

/// The outcome of running (or skipping) a single ``TestCase``.
public enum TestOutcome: Hashable, Sendable {
    /// The test rule result was defined and its result was `true`.
    case passed
    /// The test rule result was undefined.
    case failed
    /// The test was a `todo_test_` rule and was not evaluated.
    case skipped
    /// Evaluating the test threw an error.
    case errored(String)
}

/// The result of a single test execution.
public struct TestResult: Sendable {
    public let testCase: TestCase
    public let outcome: TestOutcome
    public let duration: Duration

    public init(testCase: TestCase, outcome: TestOutcome, duration: Duration) {
        self.testCase = testCase
        self.outcome = outcome
        self.duration = duration
    }
}
