import AST
import Foundation
import IR
import Rego

/// Runs Rego `test_*` rules found in compiled IR plan bundles.
///
/// ``TestFinder`` finds test funcs, then ``integrate(_:)`` replaces a policy's
/// plans with one ad-hoc wrapper plan per runnable test, and
/// ``run(bundles:runFilter:count:)`` evaluates each plan wrapper.
public enum TestRunner {
    /// Replaces `policy`'s plans with one test plan per test func.
    ///
    /// We drop the original plans because the test runner only needs the
    /// test funcs and the data, never the original entrypoints. The test
    /// plans generated here are thin wrapper around each test func.
    ///
    /// The returned policy retains the original funcs and static data (with a
    /// `"result"` string added, if needed). Skipped tests are reported in the
    /// returned list but get no plan. A policy with no runnable tests is
    /// returned unchanged.
    public static func integrate(_ policy: IR.Policy) -> (policy: IR.Policy, tests: [TestCase]) {
        let tests = TestFinder.findTests(in: policy)
        let runnable = tests.filter { !$0.skipped }
        guard !runnable.isEmpty else {
            return (policy, tests)
        }

        var newPolicy = policy

        // Ensure the "result" key exists in the static string table and
        // record its index for use in the plan generator.
        var staticData = newPolicy.staticData ?? IR.Static()
        var strings = staticData.strings ?? []
        let resultIndex: Int
        if let idx = strings.firstIndex(where: { $0.value == TestPlanGenerator.resultKey }) {
            resultIndex = idx
        } else {
            resultIndex = strings.count
            strings.append(IR.ConstString(value: TestPlanGenerator.resultKey))
        }
        staticData.strings = strings
        newPolicy.staticData = staticData

        // Replace the original plans with our "wrapper" plans.
        // Names keep the test's package path (e.g. `authz/rbac_test/test_x`),
        // so they should be unique and stay under the bundle's roots.
        let wrapperPlans = runnable.map { test in
            TestPlanGenerator.makeWrapperPlan(
                planName: test.planName,
                funcName: test.funcName,
                resultStringIndex: resultIndex
            )
        }
        newPolicy.plans = IR.Plans(plans: wrapperPlans)

        return (newPolicy, tests)
    }

    /// Finds and runs every test found in the bundles at `paths`.
    ///
    /// Each path is loaded with ``BundleLoader``. Bundles' names are
    /// the filesystem paths they were loaded from.
    public static func run(
        paths: [URL],
        runFilter: String? = nil,
        count: Int = 1
    ) async throws -> [TestResult] {
        var bundles: [String: OPA.Bundle] = [:]
        for path in paths {
            bundles[path.path] = try BundleLoader.load(fromFile: path)
        }
        return try await run(bundles: bundles, runFilter: runFilter, count: count)
    }

    /// Finds and runs every test found in `bundles`.
    ///
    /// Each bundle's plan files are integrated (see ``integrate(_:)``) and
    /// re-encoded in place, then all of those bundles are loaded onto a single
    /// ``OPA/Engine``. This means that any conflicts between bundles will
    /// surface exactly the same as loading and running those bundles normally.
    ///
    /// - Parameters:
    ///   - bundles: Loaded plan bundles keyed by name.
    ///   - runFilter: Optional regular expression. Only tests with matching names are run.
    ///   - count: Number of times to repeat each test (default: 1).
    /// - Returns: One ``TestResult`` per (test, repetition), in the order tests are found.
    public static func run(
        bundles: [String: OPA.Bundle],
        runFilter: String? = nil,
        count: Int = 1
    ) async throws -> [TestResult] {
        var integratedBundles: [String: OPA.Bundle] = [:]
        var tests: [TestCase] = []

        // Sort by name for deterministic test ordering across bundles.
        for (name, bundle) in bundles.sorted(by: { $0.key < $1.key }) {
            var newPlanFiles: [BundleFile] = []
            for planFile in bundle.planFiles {
                let policy = try IR.Policy(jsonData: planFile.data)
                let (integrated, found) = integrate(policy)
                tests.append(contentsOf: found)
                let encoded = try JSONEncoder().encode(integrated)
                newPlanFiles.append(BundleFile(url: planFile.url, data: encoded))
            }
            // Preserve the manifest, rego files, and data. Only the plan
            // files change. The engine validates roots/overlap when preparing.
            integratedBundles[name] = try OPA.Bundle(
                manifest: bundle.manifest,
                planFiles: newPlanFiles,
                regoFiles: bundle.regoFiles,
                data: bundle.data
            )
        }

        var engine = OPA.Engine(bundles: integratedBundles)
        return try await execute(engine: &engine, tests: tests, runFilter: runFilter, count: count)
    }

    /// Evaluates each test against `engine`.
    ///
    /// Skipped tests are reported without evaluation. Any error thrown while
    /// preparing/evaluating a test are thrown upward.
    private static func execute(
        engine: inout OPA.Engine,
        tests: [TestCase],
        runFilter: String?,
        count: Int
    ) async throws -> [TestResult] {
        let filtered = try filter(tests, runFilter: runFilter)

        let clock = ContinuousClock()
        var results: [TestResult] = []

        for _ in 0..<max(count, 1) {
            for test in filtered {
                if test.skipped {
                    results.append(TestResult(testCase: test, outcome: .skipped, duration: .zero))
                    continue
                }

                let start = clock.now
                let outcome: TestOutcome
                do {
                    let prepared = try await engine.prepareForEvaluation(query: test.name)
                    let resultSet = try await prepared.evaluate(input: .object([:]))
                    outcome = passed(resultSet) ? .passed : .failed
                } catch {
                    outcome = .errored(String(describing: error))
                }
                let duration = clock.now - start
                results.append(TestResult(testCase: test, outcome: outcome, duration: duration))
            }
        }

        return results
    }

    /// A test passes iff some result-set element is an object whose `result`
    /// field is `true`.
    static func passed(_ resultSet: ResultSet) -> Bool {
        for value in resultSet {
            if case .object(let object) = value,
                object[.string(TestPlanGenerator.resultKey)] == .boolean(true)
            {
                return true
            }
        }
        return false
    }

    /// Applies the `--run` regular-expression filter to `tests`, matching against
    /// each test's fully-qualified name.
    static func filter(_ tests: [TestCase], runFilter: String?) throws -> [TestCase] {
        guard let runFilter, !runFilter.isEmpty else {
            return tests
        }
        let regex = try Regex(runFilter)
        return try tests.filter { try regex.firstMatch(in: $0.name) != nil }
    }
}
