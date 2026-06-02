import AST
import Bytecode
import Foundation
import IR

internal struct IREvaluator {
    let policies: [Bytecode.Policy]

    /// Lookup table from a plan's entrypoint name (e.g. "foo/bar") to the
    /// (policy index, plan index) within `policies`. Built at construction
    /// time and guaranteed to be unique by ``init(bundles:userPolicies:)``.
    private let planIndex: [String: (policyIdx: Int, planIdx: Int)]

    /// Identifies which source claimed a given plan name during construction.
    /// Used only for plan-name uniqueness bookkeeping; instances are not
    /// compared and only stringified on the error path.
    private enum PlanOwner: Sendable {
        case bundle(String)
        case user(Int)

        var displayString: String {
            switch self {
            case .bundle(let name): return "bundle:\(name)"
            case .user(let i): return "user:#\(i)"
            }
        }
    }

    /// Constructs an `IREvaluator` from the union of bundle-supplied IR plans
    /// and user-supplied raw IR policies.
    ///
    /// We validate two properties at construction time:
    ///
    /// - Every plan name within a bundle must lie under one of *that bundle's*
    ///   declared roots. User policies are not constrained to any roots.
    /// - Plan names must be unique across the entire union. A duplicate name
    ///   fails with `planNameConflictError`.
    init(bundles: [String: OPA.Bundle], userPolicies: [IR.Policy] = []) throws {
        var compiled: [Bytecode.Policy] = []
        // Plan-name origin tracking. The common case is "each plan name has
        // exactly one owner". We keep a flat first-claim map for that case and
        // only spill into `conflicts` when a second source claims the same
        // name.
        var firstOwner: [String: PlanOwner] = [:]
        var conflicts: [String: [PlanOwner]] = [:]

        func recordOwner(planName: String, owner: PlanOwner) {
            guard let prior = firstOwner[planName] else {
                firstOwner[planName] = owner
                return
            }
            // If there's more than one claim, promote to a multi-owner conflict entry.
            if conflicts[planName] == nil {
                conflicts[planName] = [prior, owner]
            } else {
                conflicts[planName]!.append(owner)
            }
        }

        for (bundleName, bundle) in bundles.sorted(by: { $0.key < $1.key }) {
            for planFile in bundle.planFiles {
                let parsed: IR.Policy
                do {
                    var p = try IR.Policy(jsonData: planFile.data)
                    try p.prepareForExecution()
                    parsed = p
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

                // Per bundle "plan contained under roots?" check.
                for plan in parsed.plans?.plans ?? [] {
                    guard OPA.Bundle.rootPathsContain(bundle.manifest.roots, plan.name) else {
                        throw RegoError(
                            code: .planEscapedBundleRoots,
                            message:
                                "bundle '\(bundleName)' roots \(bundle.manifest.roots) "
                                + "do not permit plan '\(plan.name)'"
                        )
                    }
                    recordOwner(planName: plan.name, owner: .bundle(bundleName))
                }

                let bytecodePolicy: Bytecode.Policy
                do {
                    bytecodePolicy = try Converter.convert(parsed)
                } catch {
                    throw RegoError(
                        code: .bundleInitializationError,
                        message: """
                            initialization failed for bundle \(bundleName), \
                            conversion failed in file: \(planFile.url)
                            """,
                        cause: error
                    )
                }
                compiled.append(bytecodePolicy)
            }
        }

        // User policies don't have or need roots, but their plan names
        // share the namespace and must remain unique against everything else.
        for (i, raw) in userPolicies.enumerated() {
            var p = raw
            try p.prepareForExecution()
            for plan in p.plans?.plans ?? [] {
                recordOwner(planName: plan.name, owner: .user(i))
            }
            compiled.append(try Converter.convert(p))
        }

        // Ensure all plan names (raw user policies + bundle policies) are unique.
        if !conflicts.isEmpty {
            // Stable, sorted message so callers can match on it. Stringify
            // owners only here, on the failure path.
            let parts = conflicts.keys.sorted().map { name in
                let owners = conflicts[name]!.map { $0.displayString }.sorted()
                return "'\(name)' defined in [\(owners.joined(separator: ", "))]"
            }
            throw RegoError(
                code: .planNameConflictError,
                message: "plan name conflicts across sources: \(parts.joined(separator: "; "))"
            )
        }

        // We allow cases with zero plans here when raw IR policies were supplied
        // (some test fixtures provide policies whose only contribution is
        // funcs). Bundles, on the other hand, must contribute at least one
        // plan.
        guard !compiled.isEmpty else {
            throw RegoError(code: .noPlansFoundError, message: "no IR plans were found in any of the provided bundles")
        }

        // Build the plan name lookup index.
        var index: [String: (policyIdx: Int, planIdx: Int)] = [:]
        for (pi, policy) in compiled.enumerated() {
            for (li, plan) in policy.plans.enumerated() {
                // We're guaranteed unique keys here, thanks to the earlier conflicts check.
                index[plan.name] = (pi, li)
            }
        }

        self.policies = compiled
        self.planIndex = index
    }

    /// Initialize from bundles only. Provided for backwards compatibility.
    init(bundles: [String: OPA.Bundle]) throws {
        try self.init(bundles: bundles, userPolicies: [])
    }

    /// Initialize directly with parsed user policies.
    /// Intended mainly for testing, and provided for backwards compatibility.
    init(policies: [IR.Policy]) throws {
        try self.init(bundles: [:], userPolicies: policies)
    }
}

extension IREvaluator: Evaluator {
    func evaluate(withContext ctx: EvaluationContext) async throws -> ResultSet {
        let entrypoint = try queryToEntryPoint(ctx.query)
        guard let hit = planIndex[entrypoint] else {
            throw RegoError(code: .unknownQuery, message: "query not found in plan: \(ctx.query)")
        }
        let vm = VM(policy: policies[hit.policyIdx])
        return try await vm.executePlan(withContext: ctx, planIndex: hit.planIdx)
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
