import AST
import Foundation

/// BuiltinsCache defines the caching strategy used by the top-down evaluation.
/// Note that Golang implementation uses `type FooCachingKey string` approach to redefine string keys as distinct types.
/// For Swift implementation, type aliasing does not create a new type, so we will have to use namespaces to separate keys.
/// This implementation wraps a simple dictionary with composite keys made of namespace + key and values being RegoValues.
/// Since Dictionary is not concurrency-safe, neither is BuiltinsCache, but since its intent is to be used within a single evaluation,
/// we do not concurrency support.
public struct BuiltinsCache {
    public struct Namespace: Hashable, Sendable {
        let ns: String
        init(_ ns: String) {
            self.ns = ns
        }

        public static let global: Namespace = Namespace("__global__")

        // Helper for .namespace syntax within BuiltinsCache.subscript.
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

    public init() {
        self.cache = [CompositeKey: RegoValue]()
    }

    public subscript(key: String, namespace: Namespace = .global) -> RegoValue? {
        get {
            return self.cache[CompositeKey(key, namespace: namespace)]
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

    public mutating func removeAll() {
        self.cache.removeAll()
    }

    public var count: Int {
        return self.cache.count
    }
}
