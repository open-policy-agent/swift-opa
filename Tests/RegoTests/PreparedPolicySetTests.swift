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
            builtinRegistry: .defaultRegistry,
            bundleRoots: ["app-bundle": ["app"]],
            planBundles: ["app-bundle"]
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

    @Test("Preparing surfaces store read errors instead of resetting data")
    func testStoreReadErrorsPropagate() async throws {
        struct ReadError: Error {}
        struct FailingReadStore: OPA.Store {
            func read(from: StoreKeyPath) async throws -> AST.RegoValue { throw ReadError() }
            mutating func write(to: StoreKeyPath, value: AST.RegoValue) async throws {}
            mutating func remove(at: StoreKeyPath) async throws {}
        }
        let engine = OPA.Engine(
            policies: [IREvaluatorValidationTests.makeIRPolicy(planNames: ["user/allow"])],
            store: FailingReadStore()
        )
        await #expect(throws: ReadError.self) {
            _ = try await engine.preparePolicySet()
        }
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

    // MARK: - Replacing data

    static let query = "data.example.allow"

    static func result(_ value: AST.RegoValue) -> ResultSet {
        ResultSet([.object(["result": value])])
    }

    @Test("replacingData(bundles:) swaps bundle data and leaves the original policy set untouched")
    func testReplacingBundleData() async throws {
        let set = try await Self.makeEngine().preparePolicySet()
        let replaced = try await set.replacingData(bundles: ["data": ["config": ["example": ["value": 7]]]])

        #expect(try await set.query(Self.query).evaluate() == Self.result(42))
        #expect(try await replaced.query(Self.query).evaluate() == Self.result(7))
        #expect(replaced.bundleRoots == set.bundleRoots)
    }

    @Test("replacingData(bundles:) rejects unknown bundles and data outside the bundle's roots")
    func testReplacingBundleDataValidation() async throws {
        let set = try await Self.makeEngine().preparePolicySet()
        await Self.expectRegoError(.bundleNotFoundError) {
            _ = try await set.replacingData(bundles: ["missing": [:]])
        }
        await Self.expectRegoError(.bundleNotFoundError) {
            _ = try await set.replacingData(removingBundles: ["missing"])
        }
        await Self.expectRegoError(.bundleLoadError) {
            _ = try await set.replacingData(bundles: ["data": ["other": 1]])
        }
        await Self.expectRegoError(.bundleLoadError) {
            _ = try await set.replacingData(bundles: ["data": 7])
        }
        await Self.expectRegoError(.invalidArgumentError) {
            _ = try await set.replacingData(bundles: ["data": [:]], removingBundles: ["data"])
        }
    }

    @Test("Data-only bundles can be added and removed without recompiling")
    func testAddingAndRemovingDataBundles() async throws {
        let set = try await Self.makeEngine().preparePolicySet()
        let removed = try await set.replacingData(removingBundles: ["data"])
        #expect(try await removed.query(Self.query).evaluate() == ResultSet.empty)
        #expect(removed.bundleRoots.keys.sorted() == ["policy"])

        let dataBundle = try BundleCrossBundleDataTests.makeDataOnlyBundle(
            dataPath: "config/example/value", value: 9)
        let added = try await removed.replacingData(addingBundles: ["data2": dataBundle])
        #expect(try await added.query(Self.query).evaluate() == Self.result(9))
    }

    @Test("Removing and adding one name replaces a data-only bundle, including its roots")
    func testReplacingDataBundleRoots() async throws {
        let set = try await Self.makeEngine().preparePolicySet()
        let wider = try BundleCrossBundleDataTests.makeDataOnlyBundle(
            dataPath: "config", value: ["example": ["value": 5]])
        let replaced = try await set.replacingData(addingBundles: ["data": wider], removingBundles: ["data"])

        #expect(try await replaced.query(Self.query).evaluate() == Self.result(5))
        #expect(replaced.bundleRoots["data"] == ["config"])
    }

    @Test("Adding or removing bundles with plan files requires preparePolicySet()")
    func testPlanBundlesRequireRecompile() async throws {
        let set = try await Self.makeEngine().preparePolicySet()
        let planBundle = try BundleCrossBundleDataTests.makePolicyOnlyBundle(
            decisionPath: "other/allow", dataPath: "config/example/value")
        await Self.expectRegoError(.bundleHasPlansError) {
            _ = try await set.replacingData(removingBundles: ["policy"])
        }
        await Self.expectRegoError(.bundleHasPlansError) {
            _ = try await set.replacingData(addingBundles: ["other": planBundle])
        }
    }

    @Test("Added bundles must not conflict with existing names, roots, or raw IR plans")
    func testAddedBundleConflicts() async throws {
        let set = try await Self.makeEngine().preparePolicySet()
        let overlapping = try BundleCrossBundleDataTests.makeDataOnlyBundle(dataPath: "config/example", value: [:])
        await Self.expectRegoError(.bundleNameConflictError) {
            _ = try await set.replacingData(addingBundles: ["data": overlapping])
        }
        await Self.expectRegoError(.bundleRootConflictError) {
            _ = try await set.replacingData(addingBundles: ["overlap": overlapping])
        }
        // Empty segments are dropped from store paths, so "config//example" is "config/example".
        let doubleSlash = try OPA.Bundle(manifest: OPA.Manifest(roots: ["config//example"]), planFiles: [], data: [:])
        await Self.expectRegoError(.bundleRootConflictError) {
            _ = try await set.replacingData(addingBundles: ["doubleSlash": doubleSlash])
        }

        let userPolicy = IREvaluatorValidationTests.makeIRPolicy(planNames: ["user/allow"])
        let userSet = OPA.PreparedPolicySet(
            evaluator: try IREvaluator(bundles: [:], userPolicies: [userPolicy]),
            store: OPA.InMemoryStore(initialData: .object(["data": .object([:])])),
            builtinRegistry: .defaultRegistry,
            bundleRoots: [:],
            planBundles: []
        )
        // Roots above and under a raw IR plan both conflict with it.
        for dataPath in ["user", "user/allow/extra"] {
            let claiming = try BundleCrossBundleDataTests.makeDataOnlyBundle(dataPath: dataPath, value: [:])
            await Self.expectRegoError(.planNameConflictError) {
                _ = try await userSet.replacingData(addingBundles: ["claiming": claiming])
            }
        }

        let scalar = try OPA.Bundle(manifest: OPA.Manifest(roots: ["scalar"]), planFiles: [], data: .null)
        await Self.expectRegoError(.bundleLoadError) {
            _ = try await set.replacingData(addingBundles: ["scalar": scalar])
        }
    }

    @Test("replacingData(at:with:) writes and removes user data outside bundle roots")
    func testReplacingUserData() async throws {
        let policyBundle = try BundleCrossBundleDataTests.makePolicyOnlyBundle(
            decisionPath: "user/pref",
            dataPath: "user/preference"
        )
        let irPolicy = try IR.Policy(jsonData: policyBundle.planFiles.first!.data)
        let engine = OPA.Engine(
            policies: [irPolicy],
            store: OPA.InMemoryStore(initialData: .object(["data": .object(["user": .object(["preference": 7])])]))
        )
        let set = try await engine.preparePolicySet()

        let written = try await set.replacingData(at: "user/preference", with: 8)
        #expect(try await set.query("data.user.pref").evaluate() == Self.result(7))
        #expect(try await written.query("data.user.pref").evaluate() == Self.result(8))

        let removed = try await written.replacingData(at: "user/preference", with: nil)
        #expect(try await removed.query("data.user.pref").evaluate() == ResultSet.empty)
        await Self.expectRegoError(.storePathNotFound) {
            _ = try await removed.replacingData(at: "user/preference", with: nil)
        }

        // Removing all of `data` leaves an empty `data` object behind.
        let cleared = try await set.replacingData(at: "", with: nil)
        #expect(try await cleared.store.read(from: StoreKeyPath(["data"])) == .object([:]))

        // All of `data` must stay an object.
        await Self.expectRegoError(.storeInvalidPatch) {
            _ = try await set.replacingData(at: "", with: [1, 2])
        }
        let replacedRoot = try await set.replacingData(at: "", with: ["user": ["preference": 9]])
        #expect(try await replacedRoot.query("data.user.pref").evaluate() == Self.result(9))
    }

    @Test(
        "replacingData(at:with:) rejects paths under or above a bundle root",
        arguments: ["config", "config/example/value/x", "config//example/value", "/config/example//value/x/"])
    func testReplacingUserDataRejectsBundlePaths(path: String) async throws {
        let set = try await Self.makeEngine().preparePolicySet()
        await Self.expectRegoError(.pathOwnedByBundleError) {
            _ = try await set.replacingData(at: path, with: 1)
        }
        // A sibling of a bundle root is fine.
        _ = try await set.replacingData(at: "config/other", with: 1)
    }

    @Test("replacingData(at:with:) rejects writes that put data at or under a raw IR plan")
    func testReplacingUserDataRejectsPlanPaths() async throws {
        let userPolicy = IREvaluatorValidationTests.makeIRPolicy(planNames: ["user/allow"])
        let set = OPA.PreparedPolicySet(
            evaluator: try IREvaluator(bundles: [:], userPolicies: [userPolicy]),
            store: OPA.InMemoryStore(initialData: .object(["data": .object(["user": .object(["allow": true])])])),
            builtinRegistry: .defaultRegistry,
            bundleRoots: [:],
            planBundles: []
        )

        let conflicting: [(path: String, value: AST.RegoValue)] = [
            ("user/allow", true),
            ("user/allow/extra", 1),
            ("user", ["allow": true]),
            ("", ["user": ["allow": ["nested": 1]]]),
        ]
        for (path, value) in conflicting {
            await Self.expectRegoError(.planNameConflictError) {
                _ = try await set.replacingData(at: path, with: value)
            }
        }

        // Writes above the plan are fine when they hold nothing at the plan's path.
        _ = try await set.replacingData(at: "user", with: ["other": 1])
        _ = try await set.replacingData(at: "", with: ["user": 5])
        _ = try await set.replacingData(at: "elsewhere", with: 1)
        // Removals can't put data under a plan.
        _ = try await set.replacingData(at: "user/allow", with: nil)
    }

    @Test(
        "replacingData(at:with:) reports why a path is bundle-owned, like OPA",
        arguments: [
            ("", ["data": ["config"]], "can't write to document root with bundle roots configured"),
            ("config/x", ["all": [""]], #"all paths owned by bundle "all""#),
            ("/config/", ["data": ["config/example"]], #"path config is owned by bundle "data""#),
        ])
    func testReplacingUserDataMessages(path: String, bundleRoots: [String: [String]], message: String) async throws {
        let set = OPA.PreparedPolicySet(
            evaluator: try IREvaluator(
                bundles: [:], userPolicies: [IREvaluatorValidationTests.makeIRPolicy(planNames: ["user/allow"])]),
            store: OPA.InMemoryStore(initialData: .object(["data": .object([:])])),
            builtinRegistry: .defaultRegistry,
            bundleRoots: bundleRoots,
            planBundles: []
        )
        do {
            _ = try await set.replacingData(at: path, with: 1)
            Issue.record("expected pathOwnedByBundleError")
        } catch let err as RegoError {
            #expect(err.code == .pathOwnedByBundleError)
            #expect(err.message == message)
        }
    }

    // MARK: - Helpers

    static func expectRegoError(
        _ code: RegoError.Code,
        sourceLocation: SourceLocation = #_sourceLocation,
        _ body: () async throws -> Void
    ) async {
        let err = await #expect(throws: RegoError.self, sourceLocation: sourceLocation) { try await body() }
        #expect(err?.code == code, sourceLocation: sourceLocation)
    }

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
