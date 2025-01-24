import AST

public protocol Store {
    func read(path: StoreKeyPath) async throws -> AST.RegoValue
    func write(path: StoreKeyPath, value: AST.RegoValue) async throws
}

public enum StoreError: Error {
    case notFound(StoreKeyPath)
}

// StoreKeyPath represents the path to a value in the Store
public struct StoreKeyPath: Sendable {
    let segments: [String]
}

struct NullStore: Store {
    public func read(path: StoreKeyPath) async throws(StoreError) -> AST.RegoValue {
        throw StoreError.notFound(path)
    }

    public func write(path: StoreKeyPath, value: AST.RegoValue) async throws(StoreError) {
        throw StoreError.notFound(path)
    }
}
