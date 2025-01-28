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
        let expectedErr: any (Error.Type)
    }

    private static var successCases: [TestCase] {
        return [
            TestCase(
                description: "simple nested lookup",
                data: #" {"data": {"foo": {"bar": 42}}} "#.data(using: .utf8)!,
                path: StoreKeyPath(["data", "foo", "bar"]),
                expected: .number(42)
            )
        ]
    }

    private static var errorCases: [ErrorCase] {
        return [
            ErrorCase(
                description: "key not found",
                data: #" {"data": {"foo": {"bar": 42}}} "#.data(using: .utf8)!,
                path: StoreKeyPath(["data", "nope", "bar"]),
                expectedErr: StoreError.self
            )
        ]
    }

    @Test(arguments: successCases)
    func testStoreReads(tc: TestCase) async throws {
        let root = try AST.RegoValue(fromJson: tc.data)
        let store = InMemoryStore(initialData: root)
        let actual = try await store.read(path: tc.path)

        print(actual)
        #expect(actual == tc.expected)
    }

    @Test(arguments: errorCases)
    func testStoreReadsFailures(tc: ErrorCase) async throws {
        let root = try AST.RegoValue(fromJson: tc.data)
        let store = InMemoryStore(initialData: root)

        await #expect() {
            let _ = try await store.read(path: tc.path)
        } throws: { error in
            let mirror = Mirror(reflecting: error)
            let b: Bool = mirror.subjectType == tc.expectedErr
            return b
        }
    }
}

extension StoreTests.TestCase: CustomTestStringConvertible {
    var testDescription: String { description }
}

extension StoreTests.ErrorCase: CustomTestStringConvertible {
    var testDescription: String { description }
}
