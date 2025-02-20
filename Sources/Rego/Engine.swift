import AST
import Foundation
import IR

public struct Engine {
    // bundlePaths are pointers to directories we should load as bundles
    private var bundlePaths: [BundlePath]?

    // bundles are bundles after loading from disk
    private var bundles: [String: Bundle] = [:]

    // evaluator is a cached evaluator for evaluating policy
    private var evaluator: IREvaluator?

    // store is an interface for passing data to the evaluator
    private var store: any Store = InMemoryStore(initialData: .object([:]))

    public init(withBundlePaths: [BundlePath]) throws {
        self.bundlePaths = withBundlePaths
    }

    public init(withBundles: [String: Bundle]) {
        self.bundles = withBundles
    }

    public init(withPolicies policies: [IR.Policy], andStore store: any Store) {
        self.evaluator = IREvaluator(withPolicies: policies)
        self.store = store
    }

    public mutating func prepare() async throws {
        // Load all the bundles from disk
        // This includes parsing their data trees, etc.
        for path in bundlePaths ?? [] {
            var b: Bundle
            do {
                b = try BundleLoader.load(fromFile: path.url)
            } catch {
                throw Err.bundleLoadError(bundle: path.name, error: error)
            }
            bundles[path.name] = b
        }

        // Verify correctness of this bundle set
        try checkBundlesForOverlap(bundleSet: bundles)

        // Patch all the bundle data into the data tree on the store
        for (_, bundle) in bundles {
            try await store.write(path: StoreKeyPath(["data"]), value: bundle.data)
        }

        // Parse/compile the evaluation plans
        self.evaluator = try IREvaluator(bundles: bundles)
    }

    public func evaluate(
        query: String,
        input: AST.RegoValue = .undefined,
        tracer: QueryTracer? = nil,
        strictBuiltins: Bool = false
    ) async throws -> ResultSet {
        let ctx = EvaluationContext(
            query: query,
            input: input,
            store: self.store,
            builtins: defaultBuiltinRegistry,
            tracer: tracer,
            strictBuiltins: strictBuiltins
        )

        guard let evaluator = self.evaluator else {
            throw Err.unpreparedError
        }

        return try await evaluator.evaluate(withContext: ctx)
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
        case bundleConflictError(bundle: String)
    }
}
