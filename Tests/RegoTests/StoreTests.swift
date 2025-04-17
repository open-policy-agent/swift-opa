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
            )
        ]
    }

    private static var errorCases: [ErrorCase] {
        return [
            ErrorCase(
                description: "key not found",
                data: #" {"data": {"foo": {"bar": 42}}} "#.data(using: .utf8)!,
                path: StoreKeyPath(["data", "nope", "bar"]),
                expectedErr: RegoError.Code.storePathNotFound
            )
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
}

extension StoreTests.TestCase: CustomTestStringConvertible {
    var testDescription: String { description }
}

extension StoreTests.ErrorCase: CustomTestStringConvertible {
    var testDescription: String { description }
}
