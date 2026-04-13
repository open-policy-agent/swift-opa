import AST
import Foundation
import IR
import Testing

@testable import Rego

/// Tests for the new validation checks performed by ``IREvaluator(bundles:userPolicies:)``:
/// - bundle plan names must lie under that bundle's declared roots, and
/// - plan names must be unique across the entire set of bundles + user policies.
@Suite("IREvaluatorValidationTests")
struct IREvaluatorValidationTests {

    // MARK: - Helpers

    /// Build an `IR.Policy` with empty plans for the given names.
    /// This works for these tests because we only care about
    /// construction-time checks, and don't test evaluation at all.
    static func makeIRPolicy(planNames: [String]) -> IR.Policy {
        let plans = planNames.map { IR.Plan(name: $0, blocks: []) }
        return IR.Policy(
            staticData: nil,
            plans: IR.Plans(plans: plans),
            funcs: IR.Funcs(funcs: [])
        )
    }

    /// Build a test `OPA.Bundle` whose single plan file encodes the given
    /// IR policy. The bundle has no data under its roots.
    static func makeTestBundle(roots: [String], planNames: [String]) throws -> OPA.Bundle {
        let policy = makeIRPolicy(planNames: planNames)
        let serializedPolicy = try JSONEncoder().encode(policy)
        let manifest = OPA.Manifest(roots: roots)
        let planFile = BundleFile(
            url: URL(fileURLWithPath: "/synthetic/plan.json"),
            data: serializedPolicy
        )
        return try OPA.Bundle(manifest: manifest, planFiles: [planFile])
    }

    // MARK: - Plan contained under roots check

    @Test
    func testPlanUnderBundleRootSucceeds() throws {
        let bundle = try Self.makeTestBundle(roots: ["foo"], planNames: ["foo/allow"])
        _ = try IREvaluator(bundles: ["b": bundle])
    }

    @Test
    func testPlanUnderEmptyRootSucceeds() throws {
        let bundle = try Self.makeTestBundle(roots: [""], planNames: ["foo/bar"])
        _ = try IREvaluator(bundles: ["b": bundle])
    }

    @Test
    func testPlanOutsideBundleRootsThrows() throws {
        let bundle = try Self.makeTestBundle(roots: ["foo"], planNames: ["bar/oops"])
        let err = try requireThrows(throws: RegoError.self) {
            try IREvaluator(bundles: ["b": bundle])
        }
        #expect(err.code == .planEscapedBundleRoots)
        #expect(err.message.contains("bar/oops"))
        #expect(err.message.contains("'b'"))
    }

    @Test
    func testPlanSegmentMustMatchOnBoundaries() throws {
        // root "foo" must NOT match plan "foobar/x". (path segment-aware matching)
        let bundle = try Self.makeTestBundle(roots: ["foo"], planNames: ["foobar/x"])
        let err = try requireThrows(throws: RegoError.self) {
            try IREvaluator(bundles: ["b": bundle])
        }
        #expect(err.code == .planEscapedBundleRoots)
    }

    // MARK: - Plan-name uniqueness

    @Test
    func testTwoBundlesWithSamePlanNameThrows() throws {
        // Use distinct roots so the bundle-overlap check passes. This lets the
        // us reach the plan-name check for failing.
        let b1 = try Self.makeTestBundle(roots: ["a"], planNames: ["a/allow", "a/x"])
        let b2 = try Self.makeTestBundle(roots: ["b"], planNames: ["b/allow"])
        // Make a collision by giving ensuring both bundles share the empty root
        let bShared1 = try Self.makeTestBundle(roots: [""], planNames: ["shared/p"])
        let bShared2 = try Self.makeTestBundle(roots: [""], planNames: ["shared/p"])

        // Sanity: distinct names is fine.
        _ = try IREvaluator(bundles: ["b1": b1, "b2": b2])

        // The bundle overlap check only happens in the Engine. If we
        // construct an IREvaluator directly, we can bypass that check,
        // and exercise our name uniqueness check.
        let err = try requireThrows(throws: RegoError.self) {
            try IREvaluator(bundles: ["x": bShared1, "y": bShared2])
        }
        #expect(err.code == .planNameConflictError)
        #expect(err.message.contains("shared/p"))
        #expect(err.message.contains("bundle:x"))
        #expect(err.message.contains("bundle:y"))
    }

    @Test
    func testBundleAndUserPolicyWithSamePlanNameThrows() throws {
        let bundle = try Self.makeTestBundle(roots: [""], planNames: ["x/y"])
        let userPolicy = Self.makeIRPolicy(planNames: ["x/y"])
        let err = try requireThrows(throws: RegoError.self) {
            try IREvaluator(bundles: ["b": bundle], userPolicies: [userPolicy])
        }
        #expect(err.code == .planNameConflictError)
        #expect(err.message.contains("x/y"))
        #expect(err.message.contains("bundle:b"))
        #expect(err.message.contains("user:#0"))
    }

    @Test
    func testTwoUserPoliciesWithSamePlanNameThrows() throws {
        let p1 = Self.makeIRPolicy(planNames: ["foo/bar"])
        let p2 = Self.makeIRPolicy(planNames: ["foo/bar"])
        let err = try requireThrows(throws: RegoError.self) {
            try IREvaluator(bundles: [:], userPolicies: [p1, p2])
        }
        #expect(err.code == .planNameConflictError)
        #expect(err.message.contains("foo/bar"))
    }

    // MARK: - Bundle and user policies

    @Test
    func testBundleAndUserPolicyWithDistinctPlanNamesCoexist() async throws {
        let bundle = try Self.makeTestBundle(roots: ["bundle"], planNames: ["bundle/allow"])
        let userPolicy = Self.makeIRPolicy(planNames: ["user/decision"])

        let evaluator = try IREvaluator(bundles: ["b": bundle], userPolicies: [userPolicy])

        // Both plan names should be reachable: evaluating either query
        // executes its (empty) plan and returns an empty result set rather
        // than throwing unknownQuery. A name from neither source must throw.
        let store = OPA.InMemoryStore(initialData: .object(["data": .object([:])]))
        func evaluate(_ query: String) async throws -> ResultSet {
            let builtins = evaluator.policies.map { _ in [BuiltinImpl?]() }
            return try await evaluator.evaluate(
                withContext: EvaluationContext(query: query, input: .object([:]), store: store),
                builtins: builtins)
        }

        #expect(try await evaluate("data.bundle.allow") == ResultSet.empty)
        #expect(try await evaluate("data.user.decision") == ResultSet.empty)

        let err = try await requireThrows(throws: RegoError.self) {
            _ = try await evaluate("data.nonexistent")
        }
        #expect(err.code == .unknownQuery)
    }
}

// Note(philip): These functions emulate modern #require(throws:) behavior in
// older versions of Swift (<= 6.0.3), which do not return the caught error.
// They should be replaced with normal usage of #require as soon as 6.0.3
// support is dropped. See also the copy in CapabilityEvaluatorTests.swift.
private func requireThrows<E: Error & Sendable, R>(
    throws errorType: E.Type,
    _ comment: String = "",
    operation: () throws -> R
) throws -> E {
    do {
        _ = try operation()
        #expect(Bool(false), "Expected \(errorType) to be thrown. \(comment)")
        fatalError("This should never be reached")
    } catch let error as E {
        return error
    } catch {
        #expect(Bool(false), "Expected \(errorType) but got \(type(of: error)). \(comment)")
        fatalError("This should never be reached")
    }
}

private func requireThrows<E: Error & Sendable, R>(
    throws errorType: E.Type,
    _ comment: String = "",
    operation: () async throws -> R
) async throws -> E {
    do {
        _ = try await operation()
        #expect(Bool(false), "Expected \(errorType) to be thrown. \(comment)")
        fatalError("This should never be reached")
    } catch let error as E {
        return error
    } catch {
        #expect(Bool(false), "Expected \(errorType) but got \(type(of: error)). \(comment)")
        fatalError("This should never be reached")
    }
}
