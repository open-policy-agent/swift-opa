import AST
import Foundation
import IR

public struct Engine {
    // bundlePaths are pointers to directories we should load as bundles
    private var bundlePaths: [BundlePath]?

    // bundles are bundles after loading from disk
    private var bundles: [String: Bundle] = [:]

    // directly load IR Policies, mostly useful for testing
    private var policies: [IR.Policy] = []

    // store is an interface for passing data to the evaluator
    private var store: any Store = InMemoryStore(initialData: .object([:]))

    public init(withBundlePaths: [BundlePath]) throws {
        self.bundlePaths = withBundlePaths
    }

    public init(withBundles: [String: Bundle]) {
        self.bundles = withBundles
    }

    public init(withPolicies policies: [IR.Policy], andStore store: any Store) {
        self.policies = policies
        self.store = store
    }

    public struct PreparedQuery {
        let query: String
        let evaluator: any Evaluator
        let store: any Store

        public func evaluate(
            input: AST.RegoValue = .undefined,
            tracer: QueryTracer? = nil,
            strictBuiltins: Bool = false
        ) async throws -> ResultSet {
            let ctx = EvaluationContext(
                query: self.query,
                input: input,
                store: self.store,
                builtins: defaultBuiltinRegistry,
                tracer: tracer,
                strictBuiltins: strictBuiltins
            )

            return try await evaluator.evaluate(withContext: ctx)
        }
    }

    public mutating func prepareForEval(query: String) async throws -> PreparedQuery {
        // Load all the bundles from disk
        // This includes parsing their data trees, etc.
        var loadedBundles = self.bundles
        for path in bundlePaths ?? [] {
            guard loadedBundles[path.name] == nil else {
                throw Err.bundleNameConflictError(bundle: path.name)
            }
            var b: Bundle
            do {
                b = try BundleLoader.load(fromFile: path.url)
            } catch {
                throw Err.bundleLoadError(bundle: path.name, error: error)
            }
            loadedBundles[path.name] = b
        }

        // Verify correctness of this bundle set
        try checkBundlesForOverlap(bundleSet: loadedBundles)

        // Patch all the bundle data into the data tree on the store
        for (_, bundle) in loadedBundles {
            try await store.write(path: StoreKeyPath(["data"]), value: bundle.data)
        }

        if self.policies.count > 0 {
            guard loadedBundles.isEmpty else {
                throw Err.invalidArgumentError("Cannot mix direct IR policies with bundles")
            }
            return PreparedQuery(
                query: query,
                evaluator: IREvaluator(withPolicies: self.policies),
                store: self.store
            )
        }

        return PreparedQuery(
            query: query,
            evaluator: try IREvaluator(bundles: loadedBundles),
            store: self.store
        )
    }

    public struct BundlePath: Codable {
        public let name: String
        public let url: URL

        public init(name: String, url: URL) {
            self.name = name
            self.url = url
        }
    }

    public enum Err: Error {
        case internalError(String)
        case bundleLoadError(bundle: String, error: Error)
        case unpreparedError
        case bundleNameConflictError(bundle: String)
        case bundleRootConflictError(bundle: String)
        case invalidArgumentError(String)
    }
}
