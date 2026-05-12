import AST

extension OPA {
    /// An abstraction over a store providing keyed access to data used in policy evaluation.
    ///
    /// Stores that support synchronous evaluation must override ``read(from:)-throws``;
    /// the default implementation throws ``RegoError/Code/storeSyncNotSupported``.
    public protocol Store: Sendable {
        /// Returns the value at the specified key path asynchronously.
        func read(from: StoreKeyPath) async throws -> AST.RegoValue
        /// Returns the value at the specified key path synchronously.
        ///
        /// The default implementation throws ``RegoError/Code/storeSyncNotSupported``.
        /// Override this method to support the synchronous evaluation path.
        func read(from: StoreKeyPath) throws -> AST.RegoValue
        /// Writes a value at the specified key path.
        mutating func write(to: StoreKeyPath, value: AST.RegoValue) async throws
    }

    /// InMemoryStore is an in-memory implementation of ``OPA/Store``
    public struct InMemoryStore {
        private var data: AST.RegoValue = AST.RegoValue.object([:])
    }
}

extension OPA.Store {
    /// Default sync read: throws ``RegoError/Code/storeSyncNotSupported``.
    /// Stores that support synchronous evaluation should override this.
    public func read(from path: StoreKeyPath) throws -> AST.RegoValue {
        throw RegoError(
            code: .storeSyncNotSupported,
            message: "store does not support synchronous reads"
        )
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
    public init(initialData data: AST.RegoValue) {
        self.data = data
    }

    public func read(from path: StoreKeyPath) async throws -> AST.RegoValue {
        try readValue(from: path)
    }

    public func read(from path: StoreKeyPath) throws -> AST.RegoValue {
        try readValue(from: path)
    }

    private func readValue(from path: StoreKeyPath) throws -> AST.RegoValue {
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
