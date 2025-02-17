import AST

public protocol Store {
    func read(path: StoreKeyPath) async throws -> AST.RegoValue
    mutating func write(path: StoreKeyPath, value: AST.RegoValue) async throws
}

public enum StoreError: Error {
    case notFound(StoreKeyPath)
    case internalError(reason: String)
}

// StoreKeyPath represents the path to a value in the Store
public struct StoreKeyPath: Sendable {
    let segments: [String]

    public init(_ segments: [String]) {
        self.segments = segments
    }
}

struct NullStore: Store {
    public func read(path: StoreKeyPath) async throws(StoreError) -> AST.RegoValue {
        return AST.RegoValue.object([:])
    }

    mutating public func write(path: StoreKeyPath, value: AST.RegoValue) async throws(StoreError) {
        throw StoreError.internalError(reason: "not implemented!")
    }
}

public struct InMemoryStore: Store {
    private var data: AST.RegoValue = AST.RegoValue.object([:])

    public init(initialData data: AST.RegoValue) {
        self.data = data
    }

    public func read(path: StoreKeyPath) async throws -> AST.RegoValue {
        var current: AST.RegoValue = data
        for segment in path.segments {
            guard case .object(let object) = current else {
                throw StoreError.notFound(path)
            }
            guard let next = object[.string(segment)] else {
                throw StoreError.notFound(path)
            }
            current = next
        }

        return current
    }

    public mutating func write(path: StoreKeyPath, value: AST.RegoValue) async throws {
        // TODO this is not achieving our goal of thread safety
        data = data.patch(with: value, at: path.segments)
    }
}
