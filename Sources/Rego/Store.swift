import AST
import Synchronization

extension OPA {
    /// An abstraction over a store providing keyed access to data used in policy evaluation.
    public protocol Store: Sendable {
        /// Returns the value at the specified key path.
        /// - Parameter from: The path from which to return the value.
        /// - Throws: an error if the path is not found in the store.
        func read(from: StoreKeyPath) async throws -> AST.RegoValue
        /// Writes a value at the specified key path.
        /// - Parameter to: The path at which to return the value.
        mutating func write(to: StoreKeyPath, value: AST.RegoValue) async throws
    }

    /// InMemoryStore is an in-memory implementation of ``OPA/Store``
    /// This has to be a public final class to implement ``Sendable`` properly.
    public final class InMemoryStore: Sendable {
        private let data: Mutex<AST.RegoValue>

        public init(initialData data: AST.RegoValue = .object([:])) {
            self.data = Mutex(data)
        }
    }
}

/// A segmented path to a key in an ``OPA/Store``
///
/// The segments represent an ordered path of traversals within the virtual document,
/// culminating with the leaf key whose value is being pointed at.
public struct StoreKeyPath: Hashable, Sendable {
    let segments: [String]

    public init(_ segments: [String]) {
        self.segments = segments
    }
}

struct NullStore: OPA.Store {
    public func read(from: StoreKeyPath) async throws -> AST.RegoValue {
        return AST.RegoValue.object([:])
    }

    mutating public func write(to: StoreKeyPath, value: AST.RegoValue) async throws {
        throw RegoError(code: .internalError, message: "not implemented!")
    }
}

extension OPA.InMemoryStore: OPA.Store {
    public func read(from path: StoreKeyPath) async throws -> AST.RegoValue {
        return try self.data.withLock({
            var current: AST.RegoValue = $0
            for segment in path.segments {
                guard case .object(let object) = current else {
                    throw RegoError(code: .storePathNotFound, message: "path not found: \(path)")
                }
                guard let next = object[.string(segment)] else {
                    throw RegoError(code: .storePathNotFound, message: "path not found: \(path)")
                }
                current = next
            }

            return current
        })
    }

    public func write(to path: StoreKeyPath, value: AST.RegoValue) async throws {
        self.data.withLock({ $0 = $0.patch(with: value, at: path.segments) })
    }
}
