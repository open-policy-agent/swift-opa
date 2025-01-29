import AST
import Foundation

public struct Engine {
    // bundlePaths are pointers to directories we should load as bundles
    private var bundlePaths: [BundlePath]

    // bundles are bundles after loading from disk
    private var bundles: [String: Bundle] = [:]

    // evaluator is a cached evaluator for evaluating policy
    private var evaluator: IREvaluator?

    // store is an interface for passing data to the evaluator
    private var store: any Store

    public init(withBundlePaths: [BundlePath]) throws {
        self.bundlePaths = withBundlePaths
        self.store = InMemoryStore(initialData: .object([:]))
    }

    public mutating func prepare() async throws {
        // Load all the bundles from disk
        // This includes parsing their data trees, etc.
        bundles = [:]
        for path in bundlePaths {
            var b: Bundle
            do {
                b = try BundleLoader.load(fromDirectory: path.url)
            } catch {
                throw Err.bundleLoadError(bundle: path.name, error: error)
            }
            bundles[path.name] = b
        }

        // Patch all the bundle data into the data tree on the store
        for (name, bundle) in bundles {
            // TODO do all the cross-bundle root overlap checks
            let roots = bundle.manifest.roots
            try await store.write(path: StoreKeyPath(["data"]), value: bundle.data)
        }

        // Parse/compile the evaluation plans
        self.evaluator = try IREvaluator(bundles: bundles)
    }

    public func evaluate(
        query: String,
        input: AST.RegoValue = .null,
        tracer: QueryTracer? = nil
    ) async throws -> ResultSet {
        // withContext ctx: EvaluationContext
        let ctx = EvaluationContext(
            query: query,
            input: input,
            store: self.store,
            builtins: defaultBuiltinRegistry,
            tracer: tracer
        )

        guard let evaluator = self.evaluator else {
            throw Err.unpreparedError
        }

        return try await evaluator.evaluate(withContext: ctx)
    }

    public struct BundlePath {
        let name: String
        let url: URL
    }

    public enum Err: Error {
        case bundleLoadError(bundle: String, error: Error)
        case unpreparedError
    }
}
