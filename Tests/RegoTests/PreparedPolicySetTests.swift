import AST
import Foundation
import IR
import Testing

@testable import Rego

/// Tests for ``OPA/Engine/preparePolicySet()`` and the queries derived from it.
@Suite("PreparedPolicySetTests")
struct PreparedPolicySetTests {

    /// A policy bundle at `example/allow` reading `config/example/value`,
    /// and a data bundle providing that value.
    static func makeEngine(value: AST.RegoValue = .number(42)) throws -> OPA.Engine {
        let policyBundle = try BundleCrossBundleDataTests.makePolicyOnlyBundle(
            decisionPath: "example/allow",
            dataPath: "config/example/value"
        )
        let dataBundle = try BundleCrossBundleDataTests.makeDataOnlyBundle(
            dataPath: "config/example/value",
            value: value
        )
        return OPA.Engine(bundles: ["policy": policyBundle, "data": dataBundle])
    }

    // MARK: - Deriving queries

    @Test("Queries derived from one policy set evaluate against its bundle data")
    func testDerivedQueriesEvaluate() async throws {
        let set = try await Self.makeEngine().preparePolicySet()

        let dotted = try set.query("data.example.allow")
        let slashed = try set.query("data/example/allow")
        let expected = ResultSet([.object(["result": .number(42)])])
        #expect(try await dotted.evaluate(input: .object([:])) == expected)
        #expect(try await slashed.evaluate(input: .object([:])) == expected)
    }

    @Test("Deriving an unserved query throws unknownQuery")
    func testUnknownQueryThrows() async throws {
        let set = try await Self.makeEngine().preparePolicySet()
        do {
            _ = try set.query("data.example.missing")
            Issue.record("expected unknownQuery")
        } catch {
            #expect(error.code == .unknownQuery)
        }
    }

    @Test("Deriving a query outside data throws unsupportedQuery")
    func testUnsupportedQueryThrows() async throws {
        let set = try await Self.makeEngine().preparePolicySet()
        do {
            _ = try set.query("input.example")
            Issue.record("expected unsupportedQuery")
        } catch {
            #expect(error.code == .unsupportedQuery)
        }
    }

    @Test(
        "Queries must be data or a path under it",
        arguments: ["dataXexample.allow", "database.allow", "data_example/allow"])
    func testQueryPrefixMustEndAtSeparator(query: String) async throws {
        let set = try await Self.makeEngine().preparePolicySet()
        #expect(!set.contains(query: query))
        do {
            _ = try set.query(query)
            Issue.record("expected unsupportedQuery")
        } catch {
            #expect(error.code == .unsupportedQuery)
        }
    }

    @Test("prepareForEvaluation defers unknownQuery to evaluation")
    func testLegacyUnknownQueryDefersError() async throws {
        var engine = try Self.makeEngine()
        let pq = try await engine.prepareForEvaluation(query: "data.example.missing")
        #expect(pq.supportsSyncEvaluation == false)
        do {
            _ = try await pq.evaluate(input: .object([:]))
            Issue.record("expected unknownQuery")
        } catch let err as RegoError {
            #expect(err.code == .unknownQuery)
        }
    }

    // MARK: - Introspection

    @Test("entrypoints and contains(query:) report the plans the policy set serves")
    func testEntrypointsAndContains() async throws {
        let set = try await Self.makeEngine().preparePolicySet()

        #expect(set.entrypoints == ["example/allow"])
        #expect(set.contains(query: "data.example.allow"))
        #expect(set.contains(query: "data/example/allow"))
        #expect(!set.contains(query: "data.example.missing"))
        #expect(!set.contains(query: "data"))
        #expect(!set.contains(query: "input.example.allow"))
    }

    @Test("owner(ofEntrypoint:) names the bundle, and is nil for raw IR plans")
    func testOwner() async throws {
        let bundle = try IREvaluatorValidationTests.makeTestBundle(roots: ["app"], planNames: ["app/allow"])
        let userPolicy = IREvaluatorValidationTests.makeIRPolicy(planNames: ["user/allow"])
        let evaluator = try IREvaluator(bundles: ["app-bundle": bundle], userPolicies: [userPolicy])
        let set = OPA.PreparedPolicySet(
            evaluator: evaluator,
            store: OPA.InMemoryStore(initialData: .object(["data": .object([:])])),
            builtinRegistry: .defaultRegistry
        )

        #expect(set.entrypoints == ["app/allow", "user/allow"])
        #expect(set.owner(ofEntrypoint: "app/allow") == "app-bundle")
        #expect(set.owner(ofEntrypoint: "user/allow") == nil)
        #expect(set.owner(ofEntrypoint: "app/missing") == nil)
    }

    // MARK: - Store snapshots

    @Test("Preparing a policy set leaves the engine's store and user data untouched")
    func testSetDoesNotMutateEngineStore() async throws {
        let policyBundle = try BundleCrossBundleDataTests.makePolicyOnlyBundle(
            decisionPath: "user/pref",
            dataPath: "user/preference"
        )
        let irPolicy = try IR.Policy(jsonData: policyBundle.planFiles.first!.data)
        let engine = OPA.Engine(
            policies: [irPolicy],
            store: OPA.InMemoryStore(initialData: .object(["data": .object(["user": .object(["preference": 7])])]))
        )

        // Both policy sets see the user data, and neither depends on the other.
        let first = try await engine.preparePolicySet()
        let second = try await engine.preparePolicySet()
        let expected = ResultSet([.object(["result": .number(7)])])
        #expect(try await first.query("data.user.pref").evaluate(input: .object([:])) == expected)
        #expect(try await second.query("data.user.pref").evaluate(input: .object([:])) == expected)
    }

    @Test("Policy sets prepared from one engine pin their own data snapshots")
    func testSetsPinDataSnapshots() async throws {
        // A disk bundle whose data changes between prepares.
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }
        let policyBundle = try BundleCrossBundleDataTests.makePolicyOnlyBundle(
            decisionPath: "example/allow",
            dataPath: "config/example/value"
        )
        try Data(#"{"roots": [""]}"#.utf8).write(to: dir.appending(path: ".manifest"))
        try policyBundle.planFiles.first!.data.write(to: dir.appending(path: "plan.json"))
        func writeValue(_ value: Int) throws {
            try Data(#"{"config": {"example": {"value": \#(value)}}}"#.utf8)
                .write(to: dir.appending(path: "data.json"))
        }

        var engine = OPA.Engine(bundlePaths: [.init(name: "bundle", url: dir)])
        try writeValue(1)
        let first = try await engine.preparePolicySet()
        let legacyFirst = try await engine.prepareForEvaluation(query: "data.example.allow")
        try writeValue(2)
        let second = try await engine.preparePolicySet()
        let legacySecond = try await engine.prepareForEvaluation(query: "data.example.allow")

        let one = ResultSet([.object(["result": .number(1)])])
        let two = ResultSet([.object(["result": .number(2)])])
        #expect(try await first.query("data.example.allow").evaluate(input: .object([:])) == one)
        #expect(try await legacyFirst.evaluate(input: .object([:])) == one)
        #expect(try await second.query("data.example.allow").evaluate(input: .object([:])) == two)
        #expect(try await legacySecond.evaluate(input: .object([:])) == two)
    }

    // MARK: - Capabilities

    @Test("A capabilities file is re-read on every prepare")
    func testCapabilitiesFileReread() async throws {
        let dir = try Self.makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let capsURL = dir.appending(path: "capabilities.json")
        let engine = OPA.Engine(
            bundlePaths: [.init(name: "policy", url: relPath("TestData/Bundles/full-capabilities-bundle"))],
            capabilities: .path(capsURL)
        )
        do {
            _ = try await engine.preparePolicySet()
            Issue.record("expected capabilitiesReadError")
        } catch let err as RegoError {
            #expect(err.code == .capabilitiesReadError)
        }

        try FileManager.default.copyItem(
            at: relPath("TestData/Bundles/full-capabilities-bundle/capabilities.json"), to: capsURL)
        _ = try await engine.preparePolicySet()
    }

    // MARK: - Helpers

    static func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // The bundle loader needs a canonical path. On macOS the temp directory sits
        // behind a `/var` symlink, which `resolvingSymlinksInPath()` keeps.
        guard let real = realpath(dir.path, nil) else {
            throw CocoaError(.fileNoSuchFile)
        }
        defer { free(real) }
        return URL(fileURLWithPath: String(cString: real), isDirectory: true)
    }
}
