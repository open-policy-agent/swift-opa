import AST

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
        /// Removes the value at the specified key path, including the leaf key
        /// from its parent. Removing the root path resets the store to its empty state.
        /// Objects are traversed by string key; arrays by integer index; a set at any
        /// intermediate position throws `RegoError.internalError`.
        /// - Throws: `RegoError.storePathNotFound` if any path segment is not found;
        ///           `RegoError.internalError` if a set is encountered during traversal.
        mutating func remove(at: StoreKeyPath) async throws
    }

    /// An ``OPA/Store`` that additionally supports synchronous reads, enabling `evaluateSync`.
    public protocol SyncStore: Store {
        /// Synchronously returns the value at the specified key path.
        /// - Throws: an error if the path is not found in the store.
        func readSync(from: StoreKeyPath) throws -> AST.RegoValue
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

    mutating public func remove(at: StoreKeyPath) async throws {
        throw RegoError(code: .internalError, message: "not implemented!")
    }
}

extension OPA.InMemoryStore: OPA.Store {
    public init(initialData data: AST.RegoValue) {
        self.data = data
    }

    public func read(from path: StoreKeyPath) async throws -> AST.RegoValue {
        return try readSync(from: path)
    }

    public mutating func write(to path: StoreKeyPath, value: AST.RegoValue) async throws {
        // TODO this is not achieving our goal of thread safety
        data = data.patch(with: value, at: path.segments)
    }

    public mutating func remove(at path: StoreKeyPath) async throws {
        data = try applyRemove(data, at: path.segments[...], fullPath: path)
    }
}

extension OPA.InMemoryStore: OPA.SyncStore {
    public func readSync(from path: StoreKeyPath) throws -> AST.RegoValue {
        var current: AST.RegoValue = data
        for segment in path.segments {
            switch current {
            case .object(let o):
                guard let next = o[.string(segment)] else {
                    throw RegoError(code: .storePathNotFound, message: "path not found: \(path)")
                }
                current = next
            case .array(let a):
                guard let idx = Int(segment), idx >= 0, idx < a.count else {
                    throw RegoError(code: .storePathNotFound, message: "path not found: \(path)")
                }
                current = a[idx]
            default:
                throw RegoError(code: .storePathNotFound, message: "path not found: \(path)")
            }
        }

        return current
    }
}

private func applyRemove(
    _ value: AST.RegoValue,
    at path: ArraySlice<String>,
    fullPath: StoreKeyPath
) throws -> AST.RegoValue {
    guard !path.isEmpty else {
        return .object([:])
    }

    let i = path.startIndex
    let segment = path[i]
    let rest = path[i.advanced(by: 1)...]

    switch value {
    case .object(var o):
        let k = AST.RegoValue.string(segment)
        guard let child = o[k] else {
            throw RegoError(code: .storePathNotFound, message: "path not found: \(fullPath)")
        }
        if rest.isEmpty {
            o.removeValue(forKey: k)
            return .object(o)
        }
        o[k] = try applyRemove(child, at: rest, fullPath: fullPath)
        return .object(o)

    case .array(let a):
        guard let idx = Int(segment), idx >= 0, idx < a.count else {
            throw RegoError(code: .storePathNotFound, message: "path not found: \(fullPath)")
        }
        if rest.isEmpty {
            var newArr = a
            newArr.remove(at: idx)
            return .array(newArr)
        }
        var newArr = a
        newArr[idx] = try applyRemove(a[idx], at: rest, fullPath: fullPath)
        return .array(newArr)

    case .set:
        throw RegoError(code: .internalError, message: "invalid data value encountered")

    default:
        throw RegoError(code: .storePathNotFound, message: "path not found: \(fullPath)")
    }
}
