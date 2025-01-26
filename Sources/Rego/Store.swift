import AST

public protocol Store {
    func read(path: StoreKeyPath) async throws -> AST.RegoValue
    func write(path: StoreKeyPath, value: AST.RegoValue) async throws
}

public enum StoreError: Error {
    case notFound(StoreKeyPath)
    case internalError(reason: String)
}

// StoreKeyPath represents the path to a value in the Store
public struct StoreKeyPath: Sendable {
    let segments: [String]
}

struct NullStore: Store {
    public func read(path: StoreKeyPath) async throws(StoreError) -> AST.RegoValue {
        return AST.RegoValue.object([:])
    }

    public func write(path: StoreKeyPath, value: AST.RegoValue) async throws(StoreError) {
        throw StoreError.internalError(reason: "not implemented!")
    }
}
