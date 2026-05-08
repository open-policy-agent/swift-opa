import AST
import Foundation
import Rego
import Testing

@Suite("EngineMiniPlannerTests")
struct EngineMiniPlannerTests {
    // Helper: build an in-memory bundle whose only contribution is the data
    // tree. Ad-hoc data lookups via MiniPlanner should work against this.
    static func makeDataOnlyBundle(name: String, data: AST.RegoValue) throws -> OPA.Bundle {
        let manifest = OPA.Manifest(revision: "test", roots: [name])
        return try OPA.Bundle(
            manifest: manifest,
            planFiles: [],
            regoFiles: [],
            data: [name: data]
        )
    }

    // The data tree used by the data-only-bundle tests below. Mirrors a
    // minimal "discovery"-style payload nested under the bundle root.
    static let appConfig: AST.RegoValue = [
        "feature_flag": true,
        "max_retries": 3,
    ]
    static let appData: AST.RegoValue = ["config": appConfig]

    @Test("data-only bundle: nested path resolves to wrapped value")
    func dataOnlyNestedLookup() async throws {
        let bundle = try Self.makeDataOnlyBundle(name: "app", data: Self.appData)
        var engine = OPA.Engine(bundles: ["app": bundle])
        let prepared = try await engine.prepareForEvaluation(query: "data.app.config")
        let result = try await prepared.evaluate()

        let expected: Rego.ResultSet = [
            ["result": Self.appConfig]
        ]
        #expect(result == expected)
    }

    @Test("data-only bundle: bare `data` query returns full data tree wrapped")
    func dataOnlyBareDataQuery() async throws {
        let bundle = try Self.makeDataOnlyBundle(name: "app", data: Self.appData)
        var engine = OPA.Engine(bundles: ["app": bundle])
        let prepared = try await engine.prepareForEvaluation(query: "data")
        let result = try await prepared.evaluate()

        // Bare `data` returns the full data tree (rooted at "app" here).
        let expected: Rego.ResultSet = [
            ["result": ["app": Self.appData]]
        ]
        #expect(result == expected)
    }

    @Test("data-only bundle: missing path yields empty ResultSet, not an error")
    func dataOnlyMissingPath() async throws {
        let bundle = try Self.makeDataOnlyBundle(name: "app", data: Self.appData)
        var engine = OPA.Engine(bundles: ["app": bundle])
        let prepared = try await engine.prepareForEvaluation(query: "data.app.does.not.exist")
        let result = try await prepared.evaluate()
        #expect(result == Rego.ResultSet.empty)
    }

    @Test("data-only bundle: scalar leaf value")
    func dataOnlyScalarLeaf() async throws {
        let bundle = try Self.makeDataOnlyBundle(name: "app", data: Self.appData)
        var engine = OPA.Engine(bundles: ["app": bundle])
        let prepared = try await engine.prepareForEvaluation(query: "data.app.config.max_retries")
        let result = try await prepared.evaluate()
        #expect(result == [["result": 3]])
    }

    @Test("real plan wins over the generated lookup plan")
    func realPlanTakesPrecedence() async throws {
        // basic-policy-with-input-bundle ships a plan named main/allow.
        // A query targeting that name must hit the real plan, not a synth.
        // We assert by passing input that would change the real plan's
        // outcome — a generated plan would ignore input entirely and just
        // walk the data tree.
        var engine = OPA.Engine(
            bundlePaths: [
                OPA.Engine.BundlePath(
                    name: "basic-policy-with-input-bundle",
                    url: relPath("TestData/Bundles/basic-policy-with-input-bundle")
                )
            ]
        )
        let prepared = try await engine.prepareForEvaluation(query: "data.main.allow")
        let allowed = try await prepared.evaluate(input: ["should_allow": true])
        let denied = try await prepared.evaluate(input: ["should_allow": false])

        #expect(allowed == [["result": true]])
        // The real plan's `allow` rule is undefined when should_allow is false,
        // so the result set is empty. A generated data lookup at `main/allow`
        // would have produced `{"result": <data.main.allow value>}` regardless
        // of input, so an empty set here proves the real plan ran.
        #expect(denied == Rego.ResultSet.empty)
    }

    @Test("plan miss + data hit: generated plan resolves data sibling of a real plan")
    func planMissDataHit() async throws {
        // basic-policy-with-input-bundle has a plan at main/allow but no
        // plan at the sibling path we'll query. We use a data-only
        // bundle alongside it that provides that sibling under a
        // disjoint root, then query into the data, expecting that the
        // generated plan should cover it.
        let dataBundle = try Self.makeDataOnlyBundle(
            name: "lookup",
            data: ["greeting": "hello"]
        )
        var engine = OPA.Engine(bundles: ["lookup": dataBundle])
        let prepared = try await engine.prepareForEvaluation(query: "data.lookup.greeting")
        let result = try await prepared.evaluate()
        #expect(result == [["result": "hello"]])
    }

    @Test("query without `data` prefix throws unsupportedQuery during prepare")
    func unsupportedQuery() async throws {
        var engine = OPA.Engine(bundles: [:])
        await #expect {
            _ = try await engine.prepareForEvaluation(query: "input.foo")
        } throws: { error in
            guard let regoError = error as? Rego.RegoError else { return false }
            return regoError.code == .unsupportedQuery
        }
    }
}
