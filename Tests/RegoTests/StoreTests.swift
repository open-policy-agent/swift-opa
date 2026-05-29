import AST
import Foundation
import Testing

@testable import Rego

@Suite
struct StoreTests {
    struct TestCase: Sendable {
        let description: String
        let data: Data
        let path: StoreKeyPath
        let expected: AST.RegoValue
    }

    struct ErrorCase {
        let description: String
        let data: Data
        let path: StoreKeyPath
        let expectedErr: RegoError.Code
    }

    private static var successCases: [TestCase] {
        return [
            TestCase(
                description: "simple nested lookup",
                data: #" {"data": {"foo": {"bar": 42}}} "#.data(using: .utf8)!,
                path: StoreKeyPath(["data", "foo", "bar"]),
                expected: .number(42)
            ),
            TestCase(
                description: "array traversal by integer index",
                data: #" {"data": [10, 20, 30]} "#.data(using: .utf8)!,
                path: StoreKeyPath(["data", "1"]),
                expected: .number(20)
            ),
            TestCase(
                description: "mixed object then array traversal",
                data: #" {"items": [{"val": 7}]} "#.data(using: .utf8)!,
                path: StoreKeyPath(["items", "0", "val"]),
                expected: .number(7)
            ),
        ]
    }

    private static var errorCases: [ErrorCase] {
        return [
            ErrorCase(
                description: "key not found",
                data: #" {"data": {"foo": {"bar": 42}}} "#.data(using: .utf8)!,
                path: StoreKeyPath(["data", "nope", "bar"]),
                expectedErr: RegoError.Code.storePathNotFound
            ),
            ErrorCase(
                description: "array index out of bounds",
                data: #" {"data": [1, 2, 3]} "#.data(using: .utf8)!,
                path: StoreKeyPath(["data", "99"]),
                expectedErr: RegoError.Code.storePathNotFound
            ),
            ErrorCase(
                description: "array index not an integer",
                data: #" {"data": [1, 2, 3]} "#.data(using: .utf8)!,
                path: StoreKeyPath(["data", "foo"]),
                expectedErr: RegoError.Code.storePathNotFound
            ),
            ErrorCase(
                description: "scalar at intermediate path segment",
                data: #" {"data": 42} "#.data(using: .utf8)!,
                path: StoreKeyPath(["data", "key"]),
                expectedErr: RegoError.Code.storePathNotFound
            ),
        ]
    }

    @Test(arguments: successCases)
    func testStoreReads(tc: TestCase) async throws {
        let root = try AST.RegoValue(jsonData: tc.data)
        let store = OPA.InMemoryStore(initialData: root)
        let actual = try await store.read(from: tc.path)

        print(actual)
        #expect(actual == tc.expected)
    }

    @Test(arguments: errorCases)
    func testStoreReadsFailures(tc: ErrorCase) async throws {
        let root = try AST.RegoValue(jsonData: tc.data)
        let store = OPA.InMemoryStore(initialData: root)

        await #expect() {
            let _ = try await store.read(from: tc.path)
        } throws: { error in
            guard let regoError = error as? RegoError else {
                return false
            }
            let b: Bool = regoError.code == tc.expectedErr
            return b
        }
    }

    @Test
    func testRemoveLeafRemovesKeyFromParent() async throws {
        let root = try AST.RegoValue(
            jsonData: #" {"data": {"foo": {"bar": 1, "baz": 2}}} "#.data(using: .utf8)!)
        var store = OPA.InMemoryStore(initialData: root)

        try await store.remove(at: StoreKeyPath(["data", "foo", "bar"]))

        let parent = try await store.read(from: StoreKeyPath(["data", "foo"]))
        #expect(parent == .object([.string("baz"): .number(2)]))
    }

    @Test
    func testRemoveNonExistentKeyThrowsNotFound() async throws {
        let root = try AST.RegoValue(jsonData: #" {"data": {"foo": 1}} "#.data(using: .utf8)!)
        var store = OPA.InMemoryStore(initialData: root)

        await #expect() {
            try await store.remove(at: StoreKeyPath(["data", "nope"]))
        } throws: { error in
            guard let regoError = error as? RegoError else { return false }
            return regoError.code == .storePathNotFound
        }
    }

    @Test
    func testRemoveObjectKeyThroughArrayTraversal() async throws {
        let root = try AST.RegoValue(
            jsonData: #" {"items": [{"a": 1}, {"b": 2}]} "#.data(using: .utf8)!)
        var store = OPA.InMemoryStore(initialData: root)

        try await store.remove(at: StoreKeyPath(["items", "0", "a"]))

        // Element 0 is modified in-place (key deleted); array is not compacted.
        let result = try await store.read(from: StoreKeyPath(["items"]))
        #expect(result == .array([.object([:]), .object([.string("b"): .number(2)])]))
    }

    @Test
    func testRemoveNonExistentKeyThroughArrayThrowsNotFound() async throws {
        let root = try AST.RegoValue(
            jsonData: #" {"items": [{"a": 1}]} "#.data(using: .utf8)!)
        var store = OPA.InMemoryStore(initialData: root)

        await #expect() {
            try await store.remove(at: StoreKeyPath(["items", "0", "missing"]))
        } throws: { error in
            guard let regoError = error as? RegoError else { return false }
            return regoError.code == .storePathNotFound
        }
    }

    @Test
    func testRemoveScalarIntermediateThrowsNotFound() async throws {
        let root = try AST.RegoValue(
            jsonData: #" {"data": {"foo": 42}} "#.data(using: .utf8)!)
        var store = OPA.InMemoryStore(initialData: root)

        await #expect() {
            try await store.remove(at: StoreKeyPath(["data", "foo", "deeper"]))
        } throws: { error in
            guard let regoError = error as? RegoError else { return false }
            return regoError.code == .storePathNotFound
        }
    }

    @Test
    func testRemoveArrayElement() async throws {
        let root = try AST.RegoValue(jsonData: #" {"items": [10, 20, 30]} "#.data(using: .utf8)!)
        var store = OPA.InMemoryStore(initialData: root)

        try await store.remove(at: StoreKeyPath(["items", "1"]))

        let result = try await store.read(from: StoreKeyPath(["items"]))
        #expect(result == .array([.number(10), .number(30)]))
    }

    @Test
    func testRemoveArrayIndexOOBThrowsNotFound() async throws {
        let root = try AST.RegoValue(jsonData: #" {"items": [1, 2, 3]} "#.data(using: .utf8)!)
        var store = OPA.InMemoryStore(initialData: root)

        await #expect() {
            try await store.remove(at: StoreKeyPath(["items", "99"]))
        } throws: { error in
            guard let regoError = error as? RegoError else { return false }
            return regoError.code == .storePathNotFound
        }
    }

    @Test
    func testRemoveThroughSetThrowsInternalError() async throws {
        // Construct a value containing a set directly in Swift since JSON cannot encode sets.
        let root = AST.RegoValue.object([
            .string("data"): .set([.string("a"), .string("b")])
        ])
        var store = OPA.InMemoryStore(initialData: root)

        await #expect() {
            try await store.remove(at: StoreKeyPath(["data", "a"]))
        } throws: { error in
            guard let regoError = error as? RegoError else { return false }
            return regoError.code == .internalError
        }
    }

    @Test
    func testRemoveAtRootResetsToEmptyObject() async throws {
        let root = try AST.RegoValue(jsonData: #" {"foo": 1} "#.data(using: .utf8)!)
        var store = OPA.InMemoryStore(initialData: root)

        try await store.remove(at: StoreKeyPath([]))

        let value = try await store.read(from: StoreKeyPath([]))
        #expect(value == .object([:]))
    }

    @Test
    func testRemovePreservesEmptiedAncestor() async throws {
        let root = try AST.RegoValue(
            jsonData: #" {"data": {"foo": {"bar": 1}, "baz": 2}} "#.data(using: .utf8)!)
        var store = OPA.InMemoryStore(initialData: root)

        try await store.remove(at: StoreKeyPath(["data", "foo", "bar"]))

        // foo is preserved as an empty object, baz untouched.
        let dataValue = try await store.read(from: StoreKeyPath(["data"]))
        #expect(
            dataValue
                == .object([
                    .string("foo"): .object([:]),
                    .string("baz"): .number(2),
                ]))
    }
}

extension StoreTests.TestCase: CustomTestStringConvertible {
    var testDescription: String { description }
}

extension StoreTests.ErrorCase: CustomTestStringConvertible {
    var testDescription: String { description }
}
