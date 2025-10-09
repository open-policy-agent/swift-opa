import AST
import Foundation

/// Per-evaluation cache for OPA builtins.
///
/// Lightweight cache for (custom) OPA builtins.
/// Stores `RegoValue` entries under namespaced string keys to avoid
/// collisions between different builtins or key spaces.
///
/// ### Single-evaluation only
///
/// The cache is not concurrency-safe.
/// Use one instance per top-down policy evaluation at a time (which is performed synchronously) and do not
/// share it across concurrent evaluations.
public final class BuiltinsCache {
    /// Key namespace for isolating builtin domains.
    public struct Namespace: Hashable, Sendable {
        let ns: String
        init(_ ns: String) {
            self.ns = ns
        }

        /// Default namespace.
        public static let global: Namespace = Namespace("__global__")

        /// Create a custom namespace.
        ///
        /// - Parameter ns: The namespace name.
        public static func namespace(_ ns: String) -> Namespace {
            return Namespace(ns)
        }
    }

    /// A `CompositeKey` is used to distinguish keys of different namespaces.
    private struct CompositeKey: Hashable {
        let key: String
        let namespace: Namespace

        init(_ key: String, namespace: Namespace) {
            self.key = key
            self.namespace = namespace
        }
    }

    private var cache: [CompositeKey: RegoValue]

    /// Create a new empty builtin cache.
    public init() {
        self.cache = [CompositeKey: RegoValue]()
    }

    /// Access a cached value scoped by a key and namespace.
    public subscript(key: String, namespace: Namespace = .global) -> RegoValue? {
        get {
            self.cache[CompositeKey(key, namespace: namespace)]
        }
        set(newValue) {
            let k = CompositeKey(key, namespace: namespace)

            guard let newValue else {
                self.cache[k] = nil
                return
            }
            self.cache[k] = newValue
        }
    }

    /// Remove all cached entries.
    public func removeAll() {
        self.cache.removeAll()
    }

    /// Current number of entries in cache,
    public var count: Int {
        self.cache.count
    }
}
