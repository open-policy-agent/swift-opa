import AST
import Foundation
import IR

extension OPA {
    /// A Rego evaluation engine.
    public struct Engine {
        // bundlePaths are pointers to directories we should load as bundles
        private var bundlePaths: [BundlePath]?

        // bundles are bundles after loading from disk
        private var bundles: [String: OPA.Bundle] = [:]

        // directly load IR Policies, mostly useful for testing
        private var policies: [IR.Policy] = []

        // store is an interface for passing data to the evaluator
        private var store: any OPA.Store = InMemoryStore(initialData: .object([:]))

        // Input of the capabilities file
        private var capabilities: CapabilitiesInput? = nil
    }
}

extension OPA.Engine {
    /// Initializes the OPA engine with bundles located on disk.
    ///
    /// - Parameters:
    ///   - bundlePaths: File system paths to the bundles.
    ///   - capabilitiesPath: Optional path to a capabilities JSON file. If set,
    ///     all bundles are validated against it.
    public init(bundlePaths: [BundlePath], capabilitiesPath: URL? = nil) {
        self.bundlePaths = bundlePaths
        if let capabilitiesPath {
            self.capabilities = .path(capabilitiesPath)
        }
    }

    /// Initializes the OPA engine with in-memory bundles.
    ///
    /// - Parameters:
    ///   - bundles: Bundles provided directly in memory, keyed by name.
    ///   - capabilities: Optional in-memory capabilities. If set, all bundles
    ///     are validated against it.
    public init(bundles: [String: OPA.Bundle], capabilities: Capabilities? = nil) {
        self.bundles = bundles
        if let capabilities {
            self.capabilities = .data(capabilities)
        }
    }

    /// Initializes the OPA engine with raw IR policies and a data store, useful for testing.
    ///
    /// - Parameters:
    ///   - policies: IR policies to load into the engine.
    ///   - store: Data store backing policy evaluation.
    ///   - capabilities: Optional in-memory capabilities. If set, all policies
    ///     are validated against it.
    public init(policies: [IR.Policy], store: any OPA.Store, capabilities: Capabilities? = nil) {
        self.policies = policies
        self.store = store
        if let capabilities {
            self.capabilities = .data(capabilities)
        }
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
    /// Loads all bundles, performs internal consistency checks and validations, and prepares
    /// the provided query for evaluation.
    ///
    /// - Parameters:
    ///   - query: The query to prepare evaluation for.
    ///   - customBuiltins: The custom builtin capabilities for the evaluation, in addition to the default Rego builtins: https://www.openpolicyagent.org/docs/policy-reference/builtins
    /// - Returns: A PreparedQuery that can be used to evaluate the given query.
    public mutating func prepareForEvaluation(
        query: String,
        customBuiltins: [String: Builtin] = [:]
    ) async throws -> PreparedQuery {
        let registryBuiltins = BuiltinRegistry.defaultRegistry.builtins()

        // Merge default and custom builtins, throw appropriate error in case of name conflict
        let conflictingBuiltins = Set(customBuiltins.keys).intersection(registryBuiltins.keys)
        guard conflictingBuiltins.isEmpty else {
            throw RegoError(
                code: .ambiguousBuiltinError,
                message: "encountered conflicting builtin names between custom and default builtins: \(conflictingBuiltins)"
            )
        }
        let builtins = customBuiltins.merging(
            registryBuiltins,
            uniquingKeysWith: { $1 }        // should never happen, see guard above
        )

        // Load all the bundles from disk
        // This includes parsing their data trees, etc.
        var loadedBundles = self.bundles
        for path in bundlePaths ?? [] {
            guard loadedBundles[path.name] == nil else {
                throw RegoError(
                    code: .bundleNameConflictError,
                    message: "encountered conflicting bundle names: \(path.name)"
                )
            }
            var b: OPA.Bundle
            do {
                b = try BundleLoader.load(fromFile: path.url)
            } catch {
                throw RegoError(
                    code: .bundleLoadError,
                    message: "failed to load bundle \(path.name)",
                    cause: error
                )
            }
            loadedBundles[path.name] = b
        }

        // Verify correctness of this bundle set
        try checkBundlesForOverlap(bundleSet: loadedBundles)

        // Patch all the bundle data into the data tree on the store
        for (_, bundle) in loadedBundles {
            try await store.write(to: StoreKeyPath(["data"]), value: bundle.data)
        }

        let evaluator: IREvaluator

        if self.policies.count > 0 {
            guard loadedBundles.isEmpty else {
                throw RegoError.init(code: .invalidArgumentError, message: "Cannot mix direct IR policies with bundles")
            }

            evaluator = IREvaluator(policies: self.policies)
        } else {
            evaluator = try IREvaluator(bundles: loadedBundles)
        }

        // Load the capabilities
        let capabilities: Capabilities? = switch self.capabilities {
        case .path(let url): try Self.capabilitiesDecoder.decode(Capabilities.self, from: Data(contentsOf: url))
        case .data(let capabilities): capabilities
        case .none: nil
        }

        for policy in evaluator.policies.map(\.ir) {
            guard let requiredBuiltInsArray = policy.staticData?.builtinFuncs else {
                continue
            }

            // Check if all builtins required by the policy are present in the capabilities
            if let capabilities {
                let missingBuiltinsInCapabilities = Set(requiredBuiltInsArray).subtracting(Set(capabilities.builtins))
                if !missingBuiltinsInCapabilities.isEmpty {
                    throw RegoError(
                        code: .capabilitiesMissingBuiltin,
                        message: """
                        Missing the following builtins (required by the policies) in the capabilities.json: \
                        \(missingBuiltinsInCapabilities.description)
                        """
                    )
                }
            }

            // Check if all builtins required by the policy are present in default + custom builtins specified in the `customBuiltins` parameter.
            //
            // We cannot actually verify a matching builtin signature here, since with the current setup
            // all builtins are defined as closures taking an arbitrary array of `AST.RegoValue`s.
            // The validity of the passed parameters can only be checked at runtime inside the builtin itself.
            // Therefore, we just check for matching builtin names.
            let missingBuiltins = Set(requiredBuiltInsArray.map { $0.name }).subtracting(Set(builtins.map(\.0)))
            if !missingBuiltins.isEmpty {
                throw RegoError(
                    code: .builtinUndefinedError,
                    message: """
                    Missing the following builtins (required by the policies) in the specified builtins (default or custom builtins): \
                    \(missingBuiltins.description)
                    """
                )
            }
        }

        return PreparedQuery(
            query: query,
            evaluator: evaluator,
            store: self.store,
            builtinRegistry: BuiltinRegistry(builtins: builtins)
        )
    }

    /// A named path to an ``OPA.Bundle``.
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
}
