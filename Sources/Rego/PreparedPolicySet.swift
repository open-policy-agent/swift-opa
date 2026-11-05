import AST
import Foundation

extension OPA {
    /// An immutable, validated, and compiled snapshot of an engine's policies and data.
    ///
    /// Created by ``OPA/Engine/preparePolicySet()``, which does all of the bundle set level
    /// work once. Use ``query(_:)`` to derive a ``OPA/Engine/PreparedQuery`` for each
    /// entrypoint. Every query derived from the same policy set shares its compiled policies
    /// and its data snapshot.
    public struct PreparedPolicySet: Sendable {
        let evaluator: IREvaluator
        let store: any OPA.Store
        let builtinRegistry: BuiltinRegistry
        /// Builtin implementations pre-resolved by string table index for each policy.
        let builtins: [[BuiltinImpl?]]

        /// The plan entrypoints served by this policy set, e.g. `app/rbac/allow`.
        /// Prefix an entrypoint with `data/` to form a query for ``query(_:)``.
        public let entrypoints: Set<String>

        init(evaluator: IREvaluator, store: any OPA.Store, builtinRegistry: BuiltinRegistry) {
            self.evaluator = evaluator
            self.store = store
            self.builtinRegistry = builtinRegistry
            self.builtins = evaluator.policies.map { policy in policy.strings.map { builtinRegistry.lookup($0) } }
            self.entrypoints = Set(evaluator.planIndex.keys)
        }

        /// Prepares `query` for evaluation against this policy set.
        ///
        /// - Parameters:
        ///   - query: The query to prepare, e.g. `data.app.rbac.allow` or `data/app/rbac/allow`.
        /// - Returns: A PreparedQuery that can be used to evaluate the given query.
        /// - Throws: `RegoError.unsupportedQuery` if `query` is not `data` or a path under it,
        ///           or `RegoError.unknownQuery` if no plan in this policy set serves `query`.
        public func query(_ query: String) throws(RegoError) -> Engine.PreparedQuery {
            let entrypoint = try queryToEntryPoint(query)
            guard let hit = evaluator.planIndex[entrypoint] else {
                throw RegoError(code: .unknownQuery, message: "query not found in plan: \(query)")
            }
            return makeQuery(
                query, supportsSyncEvaluation: evaluator.policies[hit.policyIdx].plans[hit.planIdx].syncSafe)
        }

        /// Whether a plan in this policy set serves `query`, e.g. `data.app.rbac.allow`.
        public func contains(query: String) -> Bool {
            guard let entrypoint = try? queryToEntryPoint(query) else {
                return false
            }
            return evaluator.planIndex[entrypoint] != nil
        }

        /// The name of the bundle that defines `entrypoint` (e.g. `app/rbac/allow`), or nil if no bundle plan serves it.
        /// Plans from raw IR policies have no owner.
        func owner(ofEntrypoint entrypoint: String) -> String? {
            evaluator.bundleOwners[entrypoint]
        }

        /// Prepares `query` without checking it. Evaluating an unserved or
        /// unsupported query throws the error ``query(_:)`` would have thrown.
        func uncheckedQuery(_ query: String) -> Engine.PreparedQuery {
            (try? self.query(query)) ?? makeQuery(query, supportsSyncEvaluation: false)
        }

        private func makeQuery(_ query: String, supportsSyncEvaluation: Bool) -> Engine.PreparedQuery {
            Engine.PreparedQuery(
                query: query,
                evaluator: evaluator,
                store: store,
                builtinRegistry: builtinRegistry,
                builtins: builtins,
                supportsSyncEvaluation: supportsSyncEvaluation
            )
        }
    }
}
