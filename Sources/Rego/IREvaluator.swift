import AST
import Bytecode
import Foundation
import IR

internal struct IREvaluator {
    /// All compiled policies in match order: bundle/raw policies first,
    /// ad-hoc policies (e.g. ``MiniPlanner`` output) appended at the tail.
    /// Bundle-derived plans always win the entrypoint match in ``evaluate``.
    let policies: [Bytecode.Policy]

    /// Count of leading entries in ``policies`` that were derived from
    /// bundles and raw IR policies (not ad-hoc MiniPlanner policies).
    /// Used by the copy initializer to drop a previous ad-hoc tail
    /// before attaching a potential new ad-hoc tail.
    private let basePolicyCount: Int

    /// Initialize from bundles, optionally appending ad-hoc IR policies at
    /// the tail. Ad-hoc policies are prepared and lowered to bytecode the
    /// same way bundle plans are; bytecode is purely an internal
    /// representation of the evaluator.
    init(bundles: [String: OPA.Bundle], adHocPolicies: [IR.Policy] = []) throws {
        var base: [IR.Policy] = []
        for (bundleName, bundle) in bundles {
            for planFile in bundle.planFiles {
                do {
                    base.append(try IR.Policy(jsonData: planFile.data))
                } catch {
                    throw RegoError(
                        code: .bundleInitializationError,
                        message: """
                            initialization failed for bundle \(bundleName), \
                            parsing failed in file: \(planFile.url)
                            """,
                        cause: error
                    )
                }
            }
        }
        // Bundles with no plans (data-only bundles) are valid: the engine
        // supplies a fallback lookup plan via `adHocPolicies` so direct
        // data-tree queries still resolve.
        self.basePolicyCount = base.count
        self.policies = try (base + adHocPolicies).map(Self.compile)
    }

    /// Initialize directly with parsed IR policies, useful for testing.
    init(policies: [IR.Policy], adHocPolicies: [IR.Policy] = []) throws {
        self.basePolicyCount = policies.count
        self.policies = try (policies + adHocPolicies).map(Self.compile)
    }

    /// Copy initializer: reuse `existing`'s base (bundle/raw) compiled
    /// policies and add a fresh set of ad-hoc IR policies. Any ad-hoc
    /// policies previously added to `existing` are dropped, so callers
    /// can safely swap the generated lookup plan without recompiling
    /// bundles.
    init(_ existing: IREvaluator, adHocPolicies: [IR.Policy] = []) throws {
        let base = Array(existing.policies.prefix(existing.basePolicyCount))
        self.basePolicyCount = base.count
        self.policies = base + (try adHocPolicies.map(Self.compile))
    }

    /// Prepares an ``IR/Policy`` and lowers it to a ``Bytecode/Policy``.
    /// Centralized so all entry points share one compilation path.
    private static func compile(_ policy: IR.Policy) throws -> Bytecode.Policy {
        var p = policy
        try p.prepareForExecution()
        return try Converter.convert(p)
    }
}

extension IREvaluator: Evaluator {
    func evaluate(withContext ctx: EvaluationContext) async throws -> ResultSet {
        // TODO: We're assuming that queries are only ever defined in a single policy... that _should_ hold true.. but who's checkin?
        let entrypoint = try queryToEntryPoint(ctx.query)
        for policy in policies {
            if let planIndex = policy.plans.firstIndex(where: { $0.name == entrypoint }) {
                let vm = VM(policy: policy)
                return try await vm.executePlan(withContext: ctx, planIndex: planIndex)
            }
        }
        throw RegoError(code: .unknownQuery, message: "query not found in plan: \(ctx.query)")
    }
}

func queryToEntryPoint(_ query: String) throws -> String {
    let prefix = "data"
    guard query.hasPrefix(prefix) else {
        throw RegoError(code: .unsupportedQuery, message: "unsupported query: \(query), must start with 'data'")
    }
    if query == prefix {
        // done!
        return query
    }
    return query.dropFirst(prefix.count + 1).replacingOccurrences(of: ".", with: "/")
}
