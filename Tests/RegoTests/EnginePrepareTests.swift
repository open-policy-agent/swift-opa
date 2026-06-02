import AST
import Foundation
import IR
import Testing

@testable import Rego

/// Engine-level tests covering how the store is affected by the
/// store writes done during ``OPA/Engine/prepareForEvaluation(query:)``.
@Suite("EnginePrepareTests")
struct EnginePrepareTests {

    // MARK: - User data preservation across query prepare

    @Test("User data outside bundle roots survives prepareForEvaluation")
    func testUserDataSurvivesPrepare() async throws {
        // Construct a store with example data at populated `/data/user/preference`.
        // Use the same helper as the cross-bundle data tests to build a user
        // IR policy that walks down to `data.user.preference`.
        // With no bundles in use, the engine should not erase the store
        // contents.
        let userSeed: AST.RegoValue = .object([
            "data": .object([
                "user": .object(["preference": .number(99)])
            ])
        ])

        // Convert the generated JSON to an IR.Policy.
        let policyBundle = try BundleCrossBundleDataTests.makePolicyOnlyBundle(
            decisionPath: "user/pref",
            dataPath: "user/preference"
        )
        let planJSON = policyBundle.planFiles.first!.data
        let irPolicy = try IR.Policy(jsonData: planJSON)

        var engine = OPA.Engine(
            policies: [irPolicy],
            store: OPA.InMemoryStore(initialData: userSeed)
        )
        let pq = try await engine.prepareForEvaluation(query: "data.user.pref")
        let result = try await pq.evaluate(input: .object([:]))

        // If the engine had wiped `/data` on prepare, this would be empty.
        #expect(result == ResultSet([.object(["result": .number(99)])]))
    }

    // MARK: - Multiple prepare correctness

    @Test("Preparing the same engine twice produces consistent results")
    func testPrepareIsIdempotent() async throws {
        let policyBundle = try BundleCrossBundleDataTests.makePolicyOnlyBundle(
            decisionPath: "example/allow",
            dataPath: "config/example/value"
        )
        let dataBundle = try BundleCrossBundleDataTests.makeDataOnlyBundle(
            dataPath: "config/example/value",
            value: .number(42)
        )

        var engine = OPA.Engine(bundles: [
            "policy": policyBundle,
            "data": dataBundle,
        ])

        let pq1 = try await engine.prepareForEvaluation(query: "data/example/allow")
        let r1 = try await pq1.evaluate(input: .object([:]))
        #expect(r1 == ResultSet([.object(["result": .number(42)])]))

        // Second prepare: erases the previously written bundle roots and
        // writes the same data again. The result should be identical.
        let pq2 = try await engine.prepareForEvaluation(query: "data/example/allow")
        let r2 = try await pq2.evaluate(input: .object([:]))
        #expect(r2 == r1)
    }

    @Test("Multiple bundles with disjoint roots evaluate together after prepare")
    func testMultipleDisjointBundlesEval() async throws {
        // Exercises the  happy path: a policy bundle owning the
        // decision-path root, alongside a data-only bundle owning a
        // disjoint data root.
        let policyBundle = try BundleCrossBundleDataTests.makePolicyOnlyBundle(
            decisionPath: "bundle/allow",
            dataPath: "config/example/value"
        )
        let dataBundle = try BundleCrossBundleDataTests.makeDataOnlyBundle(
            dataPath: "config/example/value",
            value: .number(11)
        )

        var engine = OPA.Engine(bundles: [
            "policy": policyBundle,
            "data": dataBundle,
        ])
        let pq = try await engine.prepareForEvaluation(query: "data/bundle/allow")
        let result = try await pq.evaluate(input: .object([:]))
        #expect(result == ResultSet([.object(["result": .number(11)])]))
    }

    @Test("Empty-bundle engine does not crash on read of /data")
    func testPolicyOnlyBundleStillProducesData() async throws {
        // The VM unconditionally reads `/data`, so the engine must
        // ensure that key exists even when no bundle wrote anything
        // into the store.
        let policyBundle = try BundleCrossBundleDataTests.makePolicyOnlyBundle(
            decisionPath: "example/allow",
            dataPath: "config/feature/enabled"
        )
        var engine = OPA.Engine(bundles: ["policy": policyBundle])

        let pq = try await engine.prepareForEvaluation(query: "data/example/allow")
        let result = try await pq.evaluate(input: .object([:]))
        // Policy fails at runtime (data is missing), and gives an empty
        // result set.
        #expect(result == ResultSet([]))
    }

    // MARK: - User IR policies vs. bundle roots

    @Test("User IR plan whose name falls under a bundle root is rejected")
    func testUserPolicyUnderBundleRootRejected() throws {
        // Bundle owns the `app/` root. A user-supplied IR policy whose
        // plan name lives at `app/admin/allow` is reserving a name in a
        // subtree the bundle owns, even though the bundle ships no plan
        // by that exact name. The Engine should reject this at prepare
        // time, before reaching the IREvaluator's name-uniqueness check.
        let bundle = try IREvaluatorValidationTests.makeTestBundle(
            roots: ["app"],
            planNames: ["app/allow"]
        )
        let userPolicy = IREvaluatorValidationTests.makeIRPolicy(planNames: ["app/admin/allow"])

        do {
            try OPA.Engine.checkUserPoliciesAgainstBundleRoots(
                userPolicies: [userPolicy],
                bundles: ["b": bundle]
            )
            Issue.record("expected planNameConflictError")
        } catch let err as RegoError {
            #expect(err.code == .planNameConflictError)
            #expect(err.message.contains("app/admin/allow"))
            #expect(err.message.contains("bundle:b"))
        }
    }

    @Test("User IR plan with a name disjoint from all bundle roots is accepted")
    func testUserPolicyOutsideBundleRootsAccepted() throws {
        let bundle = try IREvaluatorValidationTests.makeTestBundle(
            roots: ["app"],
            planNames: ["app/allow"]
        )
        // `tooling/...` is disjoint from `app/...`, and should pass.
        let userPolicy = IREvaluatorValidationTests.makeIRPolicy(planNames: ["tooling/lint"])

        try OPA.Engine.checkUserPoliciesAgainstBundleRoots(
            userPolicies: [userPolicy],
            bundles: ["b": bundle]
        )
    }

    @Test("User IR plan name overlapping multiple bundle roots reports all owners")
    func testUserPolicyOverlapAcrossMultipleBundles() throws {
        // Two bundles each declare an empty root (matches everything).
        // A user plan named `shared/x` should be reported as conflicting
        // against both, with bundle owners listed in sorted order.
        let b1 = try IREvaluatorValidationTests.makeTestBundle(roots: [""], planNames: ["b1/p"])
        let b2 = try IREvaluatorValidationTests.makeTestBundle(roots: [""], planNames: ["b2/p"])
        let userPolicy = IREvaluatorValidationTests.makeIRPolicy(planNames: ["shared/x"])

        do {
            try OPA.Engine.checkUserPoliciesAgainstBundleRoots(
                userPolicies: [userPolicy],
                bundles: ["b1": b1, "b2": b2]
            )
            Issue.record("expected planNameConflictError")
        } catch let err as RegoError {
            #expect(err.code == .planNameConflictError)
            #expect(err.message.contains("shared/x"))
            #expect(err.message.contains("bundle:b1"))
            #expect(err.message.contains("bundle:b2"))
        }
    }
}
