import AST

extension OPA {
    /// An abstraction over a store providing keyed access to data used in policy evaluation.
    public protocol Store {
        /// Returns the value at the specified key path.
        /// - Parameter from: The path from which to return the value.
        /// - Throws: an error if the path is not found in the store.
        func read(from: StoreKeyPath) async throws -> AST.RegoValue
        /// Writes a value at the specified key path.
        /// - Parameter to: The path at which to return the value.
        mutating func write(to: StoreKeyPath, value: AST.RegoValue) async throws
    }

    /// InMemoryStore is an in-memory implementation of ``OPA/Store``
    public struct InMemoryStore {
        private var data: AST.RegoValue = AST.RegoValue.object([:])
    }
}

/// A segmented path to a key in an ``OPA/Store``
///
/// The segments represent an ordered path of traversals within the virtual document,
/// culminating with the leaf key whose value is being pointed at.
public struct StoreKeyPath: Equatable, Hashable, Sendable {
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
    public init(initialData data: AST.RegoValue) {
        self.data = data
    }

    public func read(from path: StoreKeyPath) async throws -> AST.RegoValue {
        var current: AST.RegoValue = data
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
    }

    public mutating func write(to path: StoreKeyPath, value: AST.RegoValue) async throws {
        // TODO this is not achieving our goal of thread safety
        data = data.patch(with: value, at: path.segments)
    }
}
