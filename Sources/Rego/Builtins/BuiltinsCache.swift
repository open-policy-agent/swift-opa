import AST
import Foundation

/// Per-evaluation cache for OPA builtins.
///
/// Lightweight cache for (custom) OPA builtins.
/// Stores `RegoValue` entries under namespaced string keys to avoid
/// collisions between different builtins or key spaces.
///
/// It is designed for use within a single top-down policy evaluation, but you can also
/// provide your own cache instance to reuse results between evaluations
/// (for example, to avoid redundant costly network-bound builtin calls).
public final class BuiltinsCache: Sendable {
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

    private let lock = NSLock()
    private nonisolated(unsafe) var _cache: [CompositeKey: RegoValue]

    /// Creates a new, empty builtin cache.
    ///
    /// The cache stores `RegoValue` entries keyed by a combination of a string and a namespace.
    /// It is designed for use within a single top-down policy evaluation, but you can also
    /// provide your own cache instance to reuse results between evaluations
    /// (for example, to avoid redundant costly network-bound builtin calls).
    public init() {
        self._cache = [CompositeKey: RegoValue]()
    }

    /// Accesses or updates a cached value scoped by a key and optional namespace.
    ///
    /// Use this subscript to read or write entries in the builtin cache.
    /// Setting a value to `nil` removes the corresponding cache entry.
    ///
    /// - Parameters:
    ///   - key: The cache key used to identify the entry within the given namespace.
    ///   - namespace: The namespace to scope the key under to avoid collisions between different builtins.. Defaults to ``Namespace/global``.
    ///
    /// - Note: Writing to the same key multiple times simply overwrites the previous value,
    ///         the cache does not enforce immutability or write-once semantics.
    public subscript(key: String, namespace: Namespace = .global) -> RegoValue? {
        get {
            self.lock.withLock {
                self._cache[CompositeKey(key, namespace: namespace)]
            }
        }
        set(newValue) {
            let k = CompositeKey(key, namespace: namespace)

            guard let newValue else {
                self.lock.withLock {
                    self._cache[k] = nil
                }
                return
            }
            self.lock.withLock {
                self._cache[k] = newValue
            }
        }
    }

    /// Remove all cached entries.
    public func removeAll() {
        self.lock.withLock {
            self._cache.removeAll()
        }
    }

    /// Current number of entries in cache.
    public var count: Int {
        self.lock.withLock {
            self._cache.count
        }
    }
}

