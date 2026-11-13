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
        private(set) var store: any OPA.Store
        let builtinRegistry: BuiltinRegistry
        /// Builtin implementations pre-resolved by string table index for each policy.
        let builtins: [[BuiltinImpl?]]
        /// Each bundle's manifest roots, keyed by bundle name.
        private(set) var bundleRoots: [String: [String]]
        /// Bundles with plan files. Adding or removing these requires a recompile.
        let planBundles: Set<String>
        /// Plans from raw IR policies (no owning bundle), sorted.
        let userPlans: [String]

        /// The plan entrypoints served by this policy set, e.g. `app/rbac/allow`.
        /// Prefix an entrypoint with `data/` to form a query for ``query(_:)``.
        public let entrypoints: Set<String>

        init(
            evaluator: IREvaluator,
            store: any OPA.Store,
            builtinRegistry: BuiltinRegistry,
            bundleRoots: [String: [String]],
            planBundles: Set<String>
        ) {
            self.evaluator = evaluator
            self.store = store
            self.builtinRegistry = builtinRegistry
            self.builtins = evaluator.policies.map { policy in policy.strings.map { builtinRegistry.lookup($0) } }
            self.bundleRoots = bundleRoots
            self.planBundles = planBundles
            self.entrypoints = Set(evaluator.planIndex.keys)
            self.userPlans = entrypoints.subtracting(evaluator.bundleOwners.keys).sorted()
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

        // MARK: - Replacing data

        /// Returns a copy of this policy set with new bundle data, reusing its compiled policies.
        ///
        /// All changes are validated together before any are written, so an invalid change
        /// writes nothing. Removing and adding the same name in one call replaces a data-only
        /// bundle, and may change its roots.
        /// User data under a removed bundle's roots is not restored. This policy set is left
        /// untouched, unless its store has reference semantics (see ``OPA/Engine/preparePolicySet()``).
        ///
        /// - Parameters:
        ///   - bundles: New data for bundles in this policy set, keyed by name. Each bundle keeps its roots.
        ///   - addingBundles: Data-only bundles (no plan files) to add, keyed by name.
        ///   - removingBundles: Names of data-only bundles to remove.
        /// - Returns: A PreparedPolicySet with the new data.
        /// - Throws: `RegoError.bundleNotFoundError` if a replaced or removed name is unknown,
        ///           `RegoError.invalidArgumentError` if a name is both replaced and removed,
        ///           `RegoError.bundleHasPlansError` if an added or removed bundle has plan files
        ///           (prepare those with ``OPA/Engine/preparePolicySet()``),
        ///           `RegoError.bundleNameConflictError` if an added name already exists,
        ///           `RegoError.bundleLoadError` if data is not an object or falls outside its bundle's roots,
        ///           `RegoError.bundleRootConflictError` if added roots overlap other bundles' roots,
        ///           or `RegoError.planNameConflictError` if added roots are under or above a raw IR plan.
        public func replacingData(
            bundles: [String: AST.RegoValue] = [:],
            addingBundles: [String: OPA.Bundle] = [:],
            removingBundles: Set<String> = []
        ) async throws -> PreparedPolicySet {
            for name in removingBundles.sorted() {
                guard bundleRoots[name] != nil else {
                    throw Self.unknownBundle(name)
                }
                guard !planBundles.contains(name) else {
                    throw Self.planBundle(name, "removed")
                }
            }
            if let name = Set(bundles.keys).intersection(removingBundles).min() {
                throw RegoError(
                    code: .invalidArgumentError, message: "bundle \(name) can't be both replaced and removed")
            }
            var roots = bundleRoots
            for name in removingBundles {
                roots[name] = nil
            }

            var writes: [(name: String, roots: [String], data: AST.RegoValue)] = []
            for (name, data) in bundles.sorted(by: { $0.key < $1.key }) {
                guard let existingRoots = roots[name] else {
                    throw Self.unknownBundle(name)
                }
                try Self.checkBundleData(name: name, data: data, roots: existingRoots)
                writes.append((name, existingRoots, data))
            }

            for (name, bundle) in addingBundles.sorted(by: { $0.key < $1.key }) {
                guard roots[name] == nil else {
                    throw RegoError(
                        code: .bundleNameConflictError, message: "encountered conflicting bundle names: \(name)")
                }
                guard bundle.planFiles.isEmpty else {
                    throw Self.planBundle(name, "added")
                }
                try Self.checkBundleData(name: name, data: bundle.data, roots: bundle.manifest.roots)
                roots[name] = bundle.manifest.roots
                writes.append((name, bundle.manifest.roots, bundle.data))
            }

            if !addingBundles.isEmpty {
                try OPA.Bundle.checkRootsForOverlap(roots)
                // Bundle plans lie under their own roots, so the overlap check covers them.
                try Engine.checkUserPlans(userPlans, againstBundleRoots: addingBundles.mapValues(\.manifest.roots)) {
                    "user '\(userPlans[$0])'"
                }
            }

            var copy = self
            let erasing = removingBundles.flatMap { bundleRoots[$0] ?? [] } + writes.flatMap(\.roots)
            try await Self.writeBundleData(into: &copy.store, erasing: erasing, bundles: writes)
            copy.bundleRoots = roots
            return copy
        }

        /// Returns a copy of this policy set with `value` written at `path`, reusing its compiled policies.
        ///
        /// This is for data outside every bundle's roots, such as the store passed to
        /// ``OPA/Engine/init(policies:store:capabilities:customBuiltins:customSyncBuiltins:)``.
        /// This policy set is left untouched, unless its store has reference semantics
        /// (see ``OPA/Engine/preparePolicySet()``).
        ///
        /// - Parameters:
        ///   - path: A slash-separated path under `data`, e.g. `users/alice`. `""` is all of `data`.
        ///   - value: The value to write, or nil to remove the value at `path`.
        /// - Returns: A PreparedPolicySet with the new data.
        /// - Throws: `RegoError.pathOwnedByBundleError` if `path` is under or above a bundle root,
        ///           `RegoError.planNameConflictError` if the write puts data at or under a raw IR plan,
        ///           `RegoError.storeInvalidPatch` if writing a non-object to all of `data`,
        ///           or `RegoError.storePathNotFound` if removing a path that doesn't exist.
        public func replacingData(at path: String, with value: AST.RegoValue?) async throws -> PreparedPolicySet {
            // Path scope checks and messages match OPA's data API.
            let segments = path.split(separator: "/")
            if segments.isEmpty && !bundleRoots.isEmpty {
                throw Self.pathOwned("can't write to document root with bundle roots configured")
            }
            // Report the first owning bundle by name, so errors are deterministic.
            let owner = bundleRoots.lazy
                .filter { _, roots in roots.contains { OPA.Bundle.pathsOverlap($0, path) } }
                .map(\.key)
                .min()
            if let owner {
                let ownsAll = bundleRoots[owner]!.contains { $0.trimmingCharacters(in: ["/"]).isEmpty }
                throw Self.pathOwned(
                    ownsAll
                        ? "all paths owned by bundle \"\(owner)\""
                        : "path \(segments.joined(separator: "/")) is owned by bundle \"\(owner)\"")
            }

            var copy = self
            let storePath = Self.storePath(for: path)
            if let value {
                if segments.isEmpty {
                    guard case .object = value else {
                        throw RegoError(code: .storeInvalidPatch, message: "root must be object")
                    }
                }
                if let plan = conflictingUserPlan(writing: value, at: segments) {
                    let shown = segments.isEmpty ? "/" : segments.joined(separator: "/")
                    throw RegoError(
                        code: .planNameConflictError,
                        message: "path \(shown) conflicts with raw IR plan '\(plan)'")
                }
                try await copy.store.write(to: storePath, value: value)
            } else {
                try await copy.store.remove(at: storePath)
                // Removing all of `data` leaves it absent.
                if segments.isEmpty {
                    try await Self.ensureDataRoot(in: &copy.store)
                }
            }
            return copy
        }

        /// Returns the first raw IR plan that writing `value` at `segments` would put data at or under.
        /// A write above a plan only conflicts if `value` holds data down at the plan's path.
        private func conflictingUserPlan(writing value: AST.RegoValue, at segments: [Substring]) -> String? {
            for plan in userPlans {
                let planSegments = plan.split(separator: "/")
                if segments.starts(with: planSegments) {
                    return plan
                }
                guard planSegments.starts(with: segments) else { continue }

                var subtree = value
                var found = true
                for segment in planSegments.dropFirst(segments.count) {
                    guard case .object(let obj) = subtree, let next = obj[.string(String(segment))] else {
                        found = false
                        break
                    }
                    subtree = next
                }
                if found {
                    return plan
                }
            }
            return nil
        }

        /// Erases each of `roots` from `store`, then writes each bundle's data under its roots.
        /// Roots are slash-separated paths under `data`.
        static func writeBundleData(
            into store: inout any OPA.Store,
            erasing roots: [String],
            bundles: [(name: String, roots: [String], data: AST.RegoValue)]
        ) async throws {
            // Erase in lexicographic order so an ancestor is removed before
            // any of its descendants. A missing path was never written, so we skip it.
            let paths = Set(roots.map(storePath(for:)))
            for path in paths.sorted(by: { $0.segments.lexicographicallyPrecedes($1.segments) }) {
                do {
                    try await store.remove(at: path)
                } catch let err as RegoError where err.code == .storePathNotFound {
                    // Already absent, nothing to erase.
                }
            }

            // Erasing a "" root removes `data` itself.
            try await ensureDataRoot(in: &store)

            // Bundle roots are disjoint across bundles, so these writes cannot collide.
            // A bundle with no data under one of its roots writes nothing for that root
            // (e.g. a policy-only bundle whose roots describe decision paths).
            for bundle in bundles.sorted(by: { $0.name < $1.name }) {
                for root in bundle.roots.sorted() {
                    let path = storePath(for: root)

                    // Walk the bundle's data down to the subtree under this root.
                    var subtree = bundle.data
                    var found = true
                    for segment in path.segments.dropFirst() {
                        guard case .object(let obj) = subtree, let next = obj[.string(segment)] else {
                            found = false
                            break
                        }
                        subtree = next
                    }
                    guard found else { continue }

                    try await store.write(to: path, value: subtree)
                }
            }
        }

        /// Writes an empty `data` object if `store` has none.
        private static func ensureDataRoot(in store: inout any OPA.Store) async throws {
            do {
                _ = try await store.read(from: StoreKeyPath(["data"]))
            } catch let err as RegoError where err.code == .storePathNotFound {
                try await store.write(to: StoreKeyPath(["data"]), value: .object([:]))
            }
        }

        /// The store path for a slash-separated path under `data`.
        private static func storePath(for path: String) -> StoreKeyPath {
            StoreKeyPath(["data"] + path.split(separator: "/").map(String.init))
        }

        /// Checks that bundle data is an object covered by `roots`.
        private static func checkBundleData(name: String, data: AST.RegoValue, roots: [String]) throws {
            guard case .object = data else {
                throw RegoError(
                    code: .bundleLoadError, message: "invalid data for bundle \(name): root value must be object")
            }
            do {
                try OPA.Bundle.checkDataCoveredByRoots(data: data, roots: roots)
            } catch {
                throw RegoError(code: .bundleLoadError, message: "invalid data for bundle \(name)", cause: error)
            }
        }

        private static func pathOwned(_ message: String) -> RegoError {
            RegoError(code: .pathOwnedByBundleError, message: message)
        }

        private static func unknownBundle(_ name: String) -> RegoError {
            RegoError(code: .bundleNotFoundError, message: "no bundle named \(name) in this policy set")
        }

        private static func planBundle(_ name: String, _ action: String) -> RegoError {
            RegoError(
                code: .bundleHasPlansError,
                message: "bundle \(name) has plan files, and can only be \(action) by preparePolicySet()"
            )
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
