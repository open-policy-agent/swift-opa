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
    }
}

extension OPA.Engine {
    public init(bundlePaths: [BundlePath]) {
        self.bundlePaths = bundlePaths
    }
    public init(bundles: [String: OPA.Bundle]) {
        self.bundles = bundles
    }

    public init(policies: [IR.Policy], store: any OPA.Store) {
        self.policies = policies
        self.store = store
    }

    /// A PreparedQuery represents a query that has been prepared for evaluation.
    ///
    /// The PreparedQuery can be evaluated by calling ``evaluate(input:tracer:strictBuiltins:)``.
    /// PreparedQuery can be re-used for multuple evaluations against different inputs.
    public struct PreparedQuery {
        let query: String
        let evaluator: any Evaluator
        let store: any OPA.Store

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
                builtins: .defaultRegistry,
                tracer: tracer,
                strictBuiltins: strictBuiltins
            )

            return try await evaluator.evaluate(withContext: ctx)
        }
    }

    /// Prepares a query for evaluation.
    ///
    /// Loads all bundles, performs internal consistency checks and validations, and prepares
    /// the provided query for evaluation.
    ///
    /// - Returns: A PreparedQuery that can be used to evaluate the given query.
    public mutating func prepareForEvaluation(query: String) async throws -> PreparedQuery {
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

        guard loadedBundles.count <= 1 else {
            throw RegoError(
                code: .invalidArgumentError, message: "Support for loading multiple bundles is not implemented yet")
        }

        // Verify correctness of this bundle set
        try checkBundlesForOverlap(bundleSet: loadedBundles)

        // Patch all the bundle data into the data tree on the store
        for (_, bundle) in loadedBundles {
            try await store.write(to: StoreKeyPath(["data"]), value: bundle.data)
        }

        if self.policies.count > 0 {
            guard loadedBundles.isEmpty else {
                throw RegoError.init(code: .invalidArgumentError, message: "Cannot mix direct IR policies with bundles")
            }
            return PreparedQuery(
                query: query,
                evaluator: IREvaluator(policies: self.policies),
                store: self.store
            )
        }

        return PreparedQuery(
            query: query,
            evaluator: try IREvaluator(bundles: loadedBundles),
            store: self.store
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
