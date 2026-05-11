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
    public init(
        bundlePaths: [BundlePath],
        capabilities: CapabilitiesInput? = nil,
        customBuiltins: [String: Builtin] = [:]
    ) {
        self.bundlePaths = bundlePaths
        self.capabilities = capabilities
        self.customBuiltins = customBuiltins
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
    public init(
        bundles: [String: OPA.Bundle],
        capabilities: CapabilitiesInput? = nil,
        customBuiltins: [String: Builtin] = [:]
    ) {
        self.bundles = BundleCache(bundles: bundles)
        self.capabilities = capabilities
        self.customBuiltins = customBuiltins
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
    public init(
        policies: [IR.Policy],
        store: any OPA.Store,
        capabilities: CapabilitiesInput? = nil,
        customBuiltins: [String: Builtin] = [:]
    ) {
        self.policies = policies
        self.store = store
        self.capabilities = capabilities
        self.customBuiltins = customBuiltins
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
                strictBuiltins: strictBuiltins
            )

            return try await self.evaluator.evaluate(withContext: ctx)
        }
    }

    /// Prepares a query for evaluation.
    ///
    /// Loads all bundles, performs internal consistency checks and validations via the specified capabilities,
    /// and prepares the provided query for evaluation.
    /// Uses default + custom builtins (specified at ``OPA/Engine`` initialization) to validate and evaluate builtin calls.
    ///
    /// ## Store Behavior
    /// When this method is called, any data in the store will be overwritten with the current combined
    /// data tree available from the loaded bundles (including anything from bundles loaded from disk).
    ///
    /// - Parameters:
    ///   - query: The query to prepare evaluation for.
    /// - Returns: A PreparedQuery that can be used to evaluate the given query.
    /// - Throws: `RegoError` if bundles fail to load, collide, or if capabilities/builtins validation fails.
    public mutating func prepareForEvaluation(query: String) async throws -> PreparedQuery {
        // Merge default and custom builtins, throw appropriate error in case of name conflict
        let registryBuiltins = BuiltinRegistry.defaultRegistry.builtins
        let conflictingBuiltins = Set(self.customBuiltins.keys).intersection(registryBuiltins.keys)
        guard conflictingBuiltins.isEmpty else {
            throw RegoError(
                code: .ambiguousBuiltinError,
                message:
                    "encountered conflicting builtin names between custom and default builtins: \(conflictingBuiltins)"
            )
        }
        let builtins = self.customBuiltins.merging(
            registryBuiltins,
            uniquingKeysWith: { $1 }  // should never happen, see guard above
        )
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

        // Write each bundle's data into the store at paths corresponding to
        // the bundle's declared roots. `checkBundlesForOverlap` guarantees
        // these root paths are disjoint across bundles, so the per-root
        // writes below cannot collide — each bundle contributes only within
        // the subtree it "owns".
        //
        // A bundle with no data under one of its roots simply writes nothing
        // for that root (e.g. a policy-only bundle whose roots describe
        // decision paths rather than data paths).
        try await store.write(to: StoreKeyPath(["data"]), value: .object([:]))
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

        let evaluator: IREvaluator

        if !self.policies.isEmpty {
            guard loadedBundles.isEmpty else {
                throw RegoError(code: .invalidArgumentError, message: "Cannot mix direct IR policies with bundles")
            }

            evaluator = try IREvaluator(policies: self.policies)
        } else {
            evaluator = try IREvaluator(bundles: loadedBundles)
        }

        // TODO: Future improvement - validate local allocation assumptions (see Locals.swift)
        // Could add validation to check:
        // - Local indices are not sparse
        // - No register collision between function frames
        // - Maximum local index is reasonable

        // Verifies that builtins are available in the OPA capabilities and builtin registry
        try await Self.verifyCapabilitiesAndBuiltIns(
            capabilities: self.capabilities, builtins: builtins, evaluator: evaluator)

        return PreparedQuery(
            query: query,
            evaluator: evaluator,
            store: self.store,
            builtinRegistry: mergedBuiltinRegistry
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
