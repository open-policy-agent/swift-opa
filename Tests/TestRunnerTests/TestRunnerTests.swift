import AST
import Foundation
import IR
import Rego
import Testing

@testable import TestRunner

@Suite("TestRunner")
struct TestRunnerTests {
    /// URL of the extracted plan bundle fixture (built via
    /// `opa build -b . -t plan -e example_test`, so all test rules appear as funcs).
    static var bundleURL: URL {
        Bundle.module.resourceURL!.appending(path: "Fixtures/example-bundle")
    }

    /// Decodes the fixture bundle's single plan file into an IR policy.
    static func fixturePolicy() throws -> IR.Policy {
        let bundle = try BundleLoader.load(fromFile: bundleURL)
        let planFile = try #require(bundle.planFiles.first)
        return try IR.Policy(jsonData: planFile.data)
    }

    // MARK: - Finding tests

    @Test("finds test funcs, classifying todo_ as skipped")
    func findTests() throws {
        let policy = try Self.fixturePolicy()
        let tests = TestFinder.findTests(in: policy)

        let byName = Dictionary(uniqueKeysWithValues: tests.map { ($0.name, $0) })
        #expect(
            Set(byName.keys) == [
                "data.example_test.test_pass",
                "data.example_test.test_fail",
                "data.example_test.test_allow_admin",
                "data.example_test.todo_test_skip",
            ])

        let pass = try #require(byName["data.example_test.test_pass"])
        #expect(pass.planName == "example_test/test_pass")
        #expect(pass.funcName == "g0.data.example_test.test_pass")
        #expect(pass.skipped == false)
        #expect(pass.file == "example_test.rego")
        #expect(pass.row != nil)

        let skip = try #require(byName["data.example_test.todo_test_skip"])
        #expect(skip.skipped == true)
    }

    // MARK: - Integration (plan generation)

    @Test("integrate replaces plans with exactly one wrapper per runnable test")
    func integrate() throws {
        let policy = try Self.fixturePolicy()
        let (integrated, tests) = TestRunner.integrate(policy)

        let runnable = tests.filter { !$0.skipped }
        #expect(runnable.count == 3)

        // The plan list is exactly the runnable-test wrappers. The fixture's
        // original package-level plan ("example_test") is dropped, and the
        // skipped todo_ test gets no plan.
        let planNames = Set((integrated.plans?.plans ?? []).map(\.name))
        #expect(
            planNames == [
                "example_test/test_pass",
                "example_test/test_fail",
                "example_test/test_allow_admin",
            ])

        // The "result" key must be present in the static string table.
        let strings = integrated.staticData?.strings?.map(\.value) ?? []
        #expect(strings.contains(TestPlanGenerator.resultKey))

        // Funcs are preserved.
        #expect(integrated.funcs?.funcs?.count == policy.funcs?.funcs?.count)
    }

    // MARK: - Strict result-set interpretation

    @Test("passed() requires a result object whose `result` field is true")
    func strictResultSemantics() {
        let key = AST.RegoValue.string(TestPlanGenerator.resultKey)

        // Bare true value under `result` -> pass.
        #expect(TestRunner.passed([.object([key: .boolean(true)])]))
        // Extra annotation keys are tolerated as long as `result` is true.
        #expect(TestRunner.passed([.object([key: .boolean(true), .string("trace"): .array([])])]))
        // `result` is false -> not a pass.
        #expect(!TestRunner.passed([.object([key: .boolean(false)])]))
        // Object without a `result` key -> not a pass.
        #expect(!TestRunner.passed([.object([.string("other"): .boolean(true)])]))
        // A bare true (not wrapped in an object) -> not a pass.
        #expect(!TestRunner.passed([.boolean(true)]))
        // Empty result set (undefined test) -> not a pass.
        #expect(!TestRunner.passed([]))
    }

    // MARK: - End-to-end run

    @Test("run classifies pass/fail/skip against the fixture bundle")
    func endToEnd() async throws {
        let results = try await TestRunner.run(paths: [Self.bundleURL])
        let outcomes = Dictionary(
            uniqueKeysWithValues: results.map { ($0.testCase.name, $0.outcome) })

        #expect(outcomes["data.example_test.test_pass"] == .passed)
        #expect(outcomes["data.example_test.test_allow_admin"] == .passed)
        #expect(outcomes["data.example_test.test_fail"] == .failed)
        #expect(outcomes["data.example_test.todo_test_skip"] == .skipped)
    }

    /// URL of a bundle with nested packages and two separate test packages,
    /// built with production entrypoints only (`-e authz/allow -e authz/rbac/allow`)
    /// so tests are pulled in via reachability and appear as funcs.
    static var nestedBundleURL: URL {
        Bundle.module.resourceURL!.appending(path: "Fixtures/nested-bundle")
    }

    @Test("nested packages yield one unique plan/result per test")
    func nestedPackages() async throws {
        // Discovery derives a distinct per-test plan name for each test, including
        // the nested `authz.rbac_test` package — no package-level plan is shared.
        let bundle = try BundleLoader.load(fromFile: Self.nestedBundleURL)
        let policy = try IR.Policy(jsonData: #require(bundle.planFiles.first).data)
        let (integrated, tests) = TestRunner.integrate(policy)

        #expect(tests.count == 4)
        #expect(
            Set((integrated.plans?.plans ?? []).map(\.name)) == [
                "authz_test/test_admin_allowed",
                "authz_test/test_anon_denied",
                "authz/rbac_test/test_read_allowed",
                "authz/rbac_test/test_write_denied",
            ])

        // End-to-end: every test runs and passes, one result each.
        let results = try await TestRunner.run(paths: [Self.nestedBundleURL])
        #expect(results.count == 4)
        #expect(results.allSatisfy { $0.outcome == .passed })
        #expect(
            Set(results.map(\.testCase.name)) == [
                "data.authz_test.test_admin_allowed",
                "data.authz_test.test_anon_denied",
                "data.authz.rbac_test.test_read_allowed",
                "data.authz.rbac_test.test_write_denied",
            ])
    }

    @Test("--run filter restricts which tests execute")
    func runFilter() async throws {
        let results = try await TestRunner.run(paths: [Self.bundleURL], runFilter: "test_pass")
        #expect(results.count == 1)
        #expect(results.first?.testCase.name == "data.example_test.test_pass")
        #expect(results.first?.outcome == .passed)
    }

    @Test("--count repeats each test")
    func count() async throws {
        let single = try await TestRunner.run(paths: [Self.bundleURL], runFilter: "test_pass")
        let doubled = try await TestRunner.run(
            paths: [Self.bundleURL], runFilter: "test_pass", count: 2)
        #expect(doubled.count == single.count * 2)
    }
}
