import AST
import Foundation
import IR

extension OPA {
    /// A Rego evaluation engine.
    public struct Engine {
        // bundlePaths are pointers to directories we should load as bundles
        private var bundlePaths: [BundlePath]?

        // bundles are bundles after loading from disk
        private var bundles: BundleCache = BundleCache(bundles: [:])

        // directly load IR Policies, mostly useful for testing
        private var policies: [IR.Policy] = []

        // store is an interface for passing data to the evaluator
        private var store: any OPA.Store = InMemoryStore(initialData: .object([:]))

        // Input of the capabilities file
        private var capabilities: CapabilitiesInput? = nil

        // Custom builtins that are specified along the default builtins
        private var customBuiltins: [String: Builtin] = [:]

        // Custom synchronous builtins. These can run on the synchronous eval path.
        private var customSyncBuiltins: [String: SyncBuiltin] = [:]

        // Bundle-owned `/data` subtrees written by the most recent
        // `prepareForEvaluation(query:)` call. The next prepare call uses
        // this set (along with the new prepare's roots) to decide which
        // subtrees to erase before writing fresh bundle data into the store.
        // User data outside this set survives across prepare calls.
        private var lastWrittenBundleRoots: Set<StoreKeyPath> = []

        private var maxCallDepth: Int = OPA.Engine.defaultMaxCallDepth

        /// Default recursion limit. Conservative so evaluation stays safe on small caller stacks
        /// (e.g. a `Task` on the cooperative pool); raise it for deeply-recursive policies.
        public static let defaultMaxCallDepth = 32
    }
}

extension OPA.Engine {
    /// Initializes the OPA engine with bundles located on disk.
    ///
    /// - Parameters:
    ///   - bundlePaths: File system paths to the bundles.
    ///   - capabilities: Optional capabilities. If set, all bundles are validated against it during ``prepareForEvaluation(query:)``.
    ///                   See https://www.openpolicyagent.org/docs/deployments#capabilities
    ///   - customBuiltins: Additional builtins to register alongside the default Rego builtins.
    ///                     See https://www.openpolicyagent.org/docs/policy-reference/builtins
    ///                     Conflicts are validated during ``prepareForEvaluation(query:)``.
    ///   - customSyncBuiltins: Additional synchronous builtins (usable on the ``PreparedQuery/evaluateSync(input:tracer:strictBuiltins:)``
    ///                     path). A name may not appear in both `customBuiltins` and `customSyncBuiltins`,
    ///                     nor collide with a default builtin; such conflicts throw during ``prepareForEvaluation(query:)``.
    public init(
        bundlePaths: [BundlePath],
        capabilities: CapabilitiesInput? = nil,
        customBuiltins: [String: Builtin] = [:],
        customSyncBuiltins: [String: SyncBuiltin] = [:],
        maxCallDepth: Int = OPA.Engine.defaultMaxCallDepth
    ) {
        self.bundlePaths = bundlePaths
        self.capabilities = capabilities
        self.customBuiltins = customBuiltins
        self.customSyncBuiltins = customSyncBuiltins
        self.maxCallDepth = maxCallDepth
    }

    /// Initializes the OPA engine with in-memory bundles.
    ///
    /// - Parameters:
    ///   - bundles: Bundles provided directly in memory, keyed by name.
    ///   - capabilities: Optional capabilities. If set, all bundles are validated against it during ``prepareForEvaluation(query:)``.
    ///                   See https://www.openpolicyagent.org/docs/deployments#capabilities
    ///   - customBuiltins: Additional builtins to register alongside the default Rego builtins.
    ///                     See https://www.openpolicyagent.org/docs/policy-reference/builtins
    ///                     Conflicts are validated during ``prepareForEvaluation(query:)``.
    ///   - customSyncBuiltins: Additional synchronous builtins (usable on the ``PreparedQuery/evaluateSync(input:tracer:strictBuiltins:)``
    ///                     path). A name may not appear in both `customBuiltins` and `customSyncBuiltins`,
    ///                     nor collide with a default builtin; such conflicts throw during ``prepareForEvaluation(query:)``.
    public init(
        bundles: [String: OPA.Bundle],
        capabilities: CapabilitiesInput? = nil,
        customBuiltins: [String: Builtin] = [:],
        customSyncBuiltins: [String: SyncBuiltin] = [:],
        maxCallDepth: Int = OPA.Engine.defaultMaxCallDepth
    ) {
        self.bundles = BundleCache(bundles: bundles)
        self.capabilities = capabilities
        self.customBuiltins = customBuiltins
        self.customSyncBuiltins = customSyncBuiltins
        self.maxCallDepth = maxCallDepth
    }

    /// Initializes the OPA engine with raw IR policies and a data store, useful for testing.
    ///
    /// - Parameters:
    ///   - policies: IR policies to load into the engine.
    ///   - store: Data store backing policy evaluation.
    ///   - capabilities: Optional capabilities. If set, all bundles are validated against it during ``prepareForEvaluation(query:)``.
    ///                   See https://www.openpolicyagent.org/docs/deployments#capabilities
    ///   - customBuiltins: Additional builtins to register alongside the default Rego builtins.
    ///                     See https://www.openpolicyagent.org/docs/policy-reference/builtins
    ///                     Conflicts are validated during ``prepareForEvaluation(query:)``.
    ///   - customSyncBuiltins: Additional synchronous builtins (usable on the ``PreparedQuery/evaluateSync(input:tracer:strictBuiltins:)``
    ///                     path). A name may not appear in both `customBuiltins` and `customSyncBuiltins`,
    ///                     nor collide with a default builtin; such conflicts throw during ``prepareForEvaluation(query:)``.
    public init(
        policies: [IR.Policy],
        store: any OPA.Store,
        capabilities: CapabilitiesInput? = nil,
        customBuiltins: [String: Builtin] = [:],
        customSyncBuiltins: [String: SyncBuiltin] = [:],
        maxCallDepth: Int = OPA.Engine.defaultMaxCallDepth
    ) {
        self.policies = policies
        self.store = store
        self.capabilities = capabilities
        self.customBuiltins = customBuiltins
        self.customSyncBuiltins = customSyncBuiltins
        self.maxCallDepth = maxCallDepth
    }

    /// A PreparedQuery represents a query that has been prepared for evaluation.
    ///
    /// The PreparedQuery can be evaluated by calling ``evaluate(input:tracer:strictBuiltins:)``.
    /// PreparedQuery can be re-used for multiple evaluations against different inputs.
    public struct PreparedQuery: Sendable {
        let query: String
        let evaluator: any Evaluator
        let store: any OPA.Store
        let builtinRegistry: BuiltinRegistry
        /// Builtin functions pre-resolved by string table index for each policy.
        let builtins: [[AnyBuiltin?]]
        /// True if the prepared policies reference any async builtin. When false, ``evaluateSync(input:tracer:strictBuiltins:)`` is available.
        let hasAsyncBuiltins: Bool
        let maxCallDepth: Int

        /// Returns the result of evaluating the prepared query against the given input.
        ///
        /// - Parameters:
        ///   - input: The input data to evaluate the query against.
        ///   - tracer: (optional) The tracer to use for this evaluation.
        ///   - strictBuiltins: (optional) Whether to run in strict builtin evaluation mode.
        ///                     In strict mode, builtin errors abort evaluation, rather than returning undefined.
        public func evaluate(
            input: AST.RegoValue = .undefined,
            tracer: OPA.Trace.QueryTracer? = nil,
            strictBuiltins: Bool = false
        ) async throws -> ResultSet {
            let ctx = EvaluationContext(
                query: self.query,
                input: input,
                store: self.store,
                builtins: self.builtinRegistry,
                tracer: tracer,
                strictBuiltins: strictBuiltins,
                hasAsyncBuiltins: self.hasAsyncBuiltins,
                maxCallDepth: self.maxCallDepth
            )
            return try await self.evaluator.evaluate(withContext: ctx, builtins: self.builtins)
        }

        /// Synchronously evaluates the prepared query against the given input.
        ///
        /// This avoids all async overhead and is callable from synchronous code. It requires
        /// that the prepared policies use no async builtins and that the store conforms to
        /// ``OPA/SyncStore`` (the default ``OPA/InMemoryStore`` does). Otherwise it throws
        /// ``RegoError/Code/syncEvaluationUnsupported``; use ``evaluate(input:tracer:strictBuiltins:)`` instead.
        ///
        /// - Parameters:
        ///   - input: The input data to evaluate the query against.
        ///   - tracer: (optional) The tracer to use for this evaluation.
        ///   - strictBuiltins: (optional) Whether to run in strict builtin evaluation mode.
        public func evaluateSync(
            input: AST.RegoValue = .undefined,
            tracer: OPA.Trace.QueryTracer? = nil,
            strictBuiltins: Bool = false
        ) throws -> ResultSet {
            guard !self.hasAsyncBuiltins else {
                throw RegoError(
                    code: .syncEvaluationUnsupported,
                    message: "query references async builtins; use evaluate(...) instead")
            }
            guard let syncStore = self.store as? any OPA.SyncStore else {
                throw RegoError(
                    code: .syncEvaluationUnsupported,
                    message: "store does not support synchronous reads; use evaluate(...) instead")
            }
            let data = try syncStore.readSync(from: StoreKeyPath(["data"]))
            let ctx = EvaluationContext(
                query: self.query,
                input: input,
                store: self.store,
                builtins: self.builtinRegistry,
                tracer: tracer,
                strictBuiltins: strictBuiltins,
                maxCallDepth: self.maxCallDepth
            )
            return try self.evaluator.evaluateSync(withContext: ctx, data: data, builtins: self.builtins)
        }
    }

    /// Prepares a query for evaluation.
    ///
    /// Loads all bundles, performs internal consistency checks and validations via the specified capabilities,
    /// and prepares the provided query for evaluation.
    /// Uses default + custom builtins (specified at ``OPA/Engine`` initialization) to validate and evaluate builtin calls.
    ///
    /// ## Store Behavior
    /// Bundle-owned `/data` subtrees are refreshed on every call: the union
    /// of the previously written bundle roots + currently declared bundle roots
    /// is erased before fresh bundle data is written. Anything outside that
    /// union is preserved across calls. user-supplied data sitting at paths
    /// outside by any bundle roots survives a prepare call.
    ///
    /// ## Bundles + raw IR policies
    /// If the engine was constructed with a mix of bundles and raw user IR
    /// policies (via ``init(policies:store:capabilities:customBuiltins:)``
    /// alongside ``init(bundles:capabilities:customBuiltins:)``-style
    /// inputs), the union is composed at preparation time. Plan names must
    /// be unique across the entire union, and bundle plan names must lie
    /// under one of their bundle's declared roots.
    ///
    /// - Parameters:
    ///   - query: The query to prepare evaluation for.
    /// - Returns: A PreparedQuery that can be used to evaluate the given query.
    /// - Throws: `RegoError` if bundles fail to load, collide, or if capabilities/builtins validation fails.
    public mutating func prepareForEvaluation(query: String) async throws -> PreparedQuery {
        // Merge default and custom builtins, throw appropriate error in case of name conflict.
        // Custom names must not collide with the defaults or with each other (sync vs async).
        let registryBuiltins = BuiltinRegistry.defaultRegistry.builtins
        let customNames = Set(self.customBuiltins.keys).union(self.customSyncBuiltins.keys)
        let conflictingBuiltins =
            customNames.intersection(registryBuiltins.keys)
            .union(Set(self.customBuiltins.keys).intersection(self.customSyncBuiltins.keys))
        guard conflictingBuiltins.isEmpty else {
            throw RegoError(
                code: .ambiguousBuiltinError,
                message:
                    "encountered conflicting builtin names between custom and default builtins: \(conflictingBuiltins)"
            )
        }
        var builtins: [String: AnyBuiltin] = registryBuiltins
        for (name, builtin) in self.customBuiltins { builtins[name] = .async(builtin) }
        for (name, builtin) in self.customSyncBuiltins { builtins[name] = .sync(builtin) }
        let mergedBuiltinRegistry = BuiltinRegistry(builtins: builtins)

        // Bundles supplied via `init(bundles:)` live in `self.bundles` and are
        // validated once at construction. We never mutate that cache here so
        // repeated calls reuse its cached validation and overlap results.
        //
        // Bundles referenced via `init(bundlePaths:)` are (re)read from disk on
        // every call and staged on top of a copy of the base cache.
        var diskLoaded: [String: OPA.Bundle] = [:]
        if let bundlePaths, !bundlePaths.isEmpty {
            // Snapshot cached names once for cheap conflict checks below.
            let cachedNames = Set(try self.bundles.validated().keys)

            for path in bundlePaths {
                guard !cachedNames.contains(path.name), diskLoaded[path.name] == nil else {
                    throw RegoError(
                        code: .bundleNameConflictError,
                        message: "encountered conflicting bundle names: \(path.name)"
                    )
                }
                do {
                    diskLoaded[path.name] = try BundleLoader.load(fromFile: path.url)
                } catch {
                    throw RegoError(
                        code: .bundleLoadError,
                        message: "failed to load bundle \(path.name)",
                        cause: error
                    )
                }
            }
        }

        // Fast path for the common case: no disk bundles -> use the base cache
        // directly. Slow path: stage disk bundles on top of a copy so we can
        // run a single validation/overlap check over the combined set.
        let loadedBundles: [String: OPA.Bundle]
        if diskLoaded.isEmpty {
            loadedBundles = try self.bundles.validated()
        } else {
            let workingCache = BundleCache(copying: self.bundles)
            workingCache.add(bundles: diskLoaded)
            loadedBundles = try workingCache.validated()
        }

        // Compute the set of `/data/...` subtrees the current bundle set
        // claims. We erase only the union of the previously written roots +
        // newly declared roots, which leaves user data outside both sets
        // untouched across prepare calls.
        var newRoots: Set<StoreKeyPath> = []
        for (_, bundle) in loadedBundles {
            for root in bundle.manifest.roots {
                let segments = root.split(separator: "/").map(String.init)
                newRoots.insert(StoreKeyPath(["data"] + segments))
            }
        }

        // Erase old + new bundle-owned subtrees in lexicographic order so an
        // ancestor is removed before any of its descendants.
        // A missing path is not an error here — the subtree simply wasn't
        // present (e.g. first prepare on a fresh store), so we skip it.
        // The recovery block below re-establishes the `data` root as an
        // empty object whenever a removal leaves it absent.
        let toErase = lastWrittenBundleRoots.union(newRoots)
        for path in toErase.sorted(by: { $0.segments.lexicographicallyPrecedes($1.segments) }) {
            do {
                try await store.remove(at: path)
            } catch let err as RegoError where err.code == .storePathNotFound {
                // Already absent — nothing to erase.
            }
        }

        // Ensure the root `data` node exists; removal of the whole `data`
        // subtree (e.g. a bundle with root "") leaves it absent.
        do {
            _ = try await store.read(from: StoreKeyPath(["data"]))
        } catch {
            try await store.write(to: StoreKeyPath(["data"]), value: .object([:]))
        }

        // Write each bundle's data into the store at paths corresponding to
        // the bundle's declared roots. `checkBundlesForOverlap` guarantees
        // these root paths are disjoint across bundles, so the per-root
        // writes below cannot collide — each bundle contributes only within
        // the subtree it "owns".
        //
        // A bundle with no data under one of its roots simply writes nothing
        // for that root (e.g. a policy-only bundle whose roots describe
        // decision paths rather than data paths).
        for (_, bundle) in loadedBundles.sorted(by: { $0.key < $1.key }) {
            let roots = bundle.manifest.roots
            for root in roots.sorted() {
                let rootSegments = root.split(separator: "/").map(String.init)

                // Walk bundle.data down to the subtree the bundle actually
                // contributes for this root. If any segment is missing or
                // isn't an object, this bundle has nothing to contribute
                // for this root and we skip.
                var subtree: AST.RegoValue = bundle.data
                var found = true
                for segment in rootSegments {
                    guard case .object(let obj) = subtree,
                        let next = obj[.string(segment)]
                    else {
                        found = false
                        break
                    }
                    subtree = next
                }
                guard found else { continue }

                // Write the subtree at ["data"] + rootSegments.
                let storePath = StoreKeyPath(["data"] + rootSegments)
                try await store.write(to: storePath, value: subtree)
            }
        }

        // Remember what we wrote so the next prepare knows what to erase.
        self.lastWrittenBundleRoots = newRoots

        // User-supplied IR policies share the plan-name namespace with
        // bundles. The IREvaluator already enforces global plan-name
        // uniqueness. Here we also reject user plans whose names fall
        // under any bundle's declared roots, because that subtree is
        // owned by the bundle even if the bundle itself does not currently
        // define a plan at that exact name.
        if !self.policies.isEmpty && !loadedBundles.isEmpty {
            try Self.checkUserPoliciesAgainstBundleRoots(
                userPolicies: self.policies,
                bundles: loadedBundles
            )
        }

        let evaluator = try IREvaluator(bundles: loadedBundles, userPolicies: self.policies)

        // TODO: Future improvement - validate local allocation assumptions (see Locals.swift)
        // Could add validation to check:
        // - Local indices are not sparse
        // - No register collision between function frames
        // - Maximum local index is reasonable

        // Verifies that builtins are available in the OPA capabilities and builtin registry
        try await Self.verifyCapabilitiesAndBuiltIns(
            capabilities: self.capabilities, builtins: builtins, evaluator: evaluator)

        // Determine whether any referenced builtin is async; gates the synchronous eval path.
        var hasAsyncBuiltins = false
        asyncScan: for policy in evaluator.policies {
            for fn in policy.builtinFuncs {
                if case .async? = builtins[fn.name] {
                    hasAsyncBuiltins = true
                    break asyncScan
                }
            }
        }

        return PreparedQuery(
            query: query,
            evaluator: evaluator,
            store: self.store,
            builtinRegistry: mergedBuiltinRegistry,
            builtins: evaluator.policies.map { policy in policy.strings.map { mergedBuiltinRegistry[$0] } },
            hasAsyncBuiltins: hasAsyncBuiltins,
            maxCallDepth: self.maxCallDepth
        )
    }

    /// A named path to an ``OPA/Bundle``.
    public struct BundlePath: Codable {
        /// The name of the bundle.
        public let name: String
        /// The local URL pointing to the bundle root.
        public let url: URL

        public init(name: String, url: URL) {
            self.name = name
            self.url = url
        }
    }

    /// Represents how capabilities are supplied to the evaluator.
    ///
    /// This abstraction allows policies to be validated either against a
    /// capabilities file (e.g. `capabilities.json` from an OPA release) or
    /// against programmatically constructed capabilities within Swift.
    public enum CapabilitiesInput: Hashable, Sendable {
        /// Load capabilities from the `capabilities.json` JSON file at the given `URL`.
        case path(URL)
        /// Use an in-memory `Capabilities` object directly.
        case data(Capabilities)
    }
}
