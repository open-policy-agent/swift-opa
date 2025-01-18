import Foundation
import Testing

@testable import Runtime

@Suite("BundleDecodingTests")
struct BundleDecodingTests {
    struct TestCase: Sendable {
        let description: String
        let data: Data
        let expected: Manifest
    }
    struct ErrorCase {
        let description: String
        let data: Data
        let expectedErr: any (Error.Type)
    }

    static var validTestCases: [TestCase] {
        return [
            TestCase(
                description: "simple",
                data: #"""
                    {
                      "revision" : "7864d60dd78d748dbce54b569e939f5b0dc07486",
                      "roots": ["roles", "http/example/authz"]
                    }
                    """#.data(using: .utf8)!,
                expected:
                    Manifest(
                        revision: "7864d60dd78d748dbce54b569e939f5b0dc07486",
                        roots: ["roles", "http/example/authz"],
                        regoVersion: .regoV1,
                        metadata: [:]
                    )
            ),
            TestCase(
                description: "with metadata",
                data: #"""
                    {
                      "revision" : "7864d60dd78d748dbce54b569e939f5b0dc07486",
                      "roots": ["roles", "http/example/authz"],
                      "metadata": {
                        "foo": "bar",
                        "number": 42,
                      }
                    }
                    """#.data(using: .utf8)!,
                expected:
                    Manifest(
                        revision: "7864d60dd78d748dbce54b569e939f5b0dc07486",
                        roots: ["roles", "http/example/authz"],
                        regoVersion: .regoV1,
                        metadata: [
                            "foo": .string("bar"),
                            "number": .number(42),
                        ]
                    )
            ),
            TestCase(
                description: "rego v0",
                data: #"""
                    {
                      "revision" : "7864d60dd78d748dbce54b569e939f5b0dc07486",
                      "roots": ["roles", "http/example/authz"],
                      "rego_version": 0
                    }
                    """#.data(using: .utf8)!,
                expected:
                    Manifest(
                        revision: "7864d60dd78d748dbce54b569e939f5b0dc07486",
                        roots: ["roles", "http/example/authz"],
                        regoVersion: .regoV0,
                        metadata: [:]
                    )
            ),
            TestCase(
                description: "rego v1",
                data: #"""
                    {
                      "revision" : "7864d60dd78d748dbce54b569e939f5b0dc07486",
                      "roots": ["roles", "http/example/authz"],
                      "rego_version": 1
                    }
                    """#.data(using: .utf8)!,
                expected:
                    Manifest(
                        revision: "7864d60dd78d748dbce54b569e939f5b0dc07486",
                        roots: ["roles", "http/example/authz"],
                        regoVersion: .regoV1,
                        metadata: [:]
                    )
            ),
            TestCase(
                description: "empty roots",
                data: #"""
                    {
                      "revision" : "7864d60dd78d748dbce54b569e939f5b0dc07486",
                      "roots": [],
                    }
                    """#.data(using: .utf8)!,
                expected:
                    Manifest(
                        revision: "7864d60dd78d748dbce54b569e939f5b0dc07486",
                        roots: [],
                        regoVersion: .regoV1,
                        metadata: [:]
                    )
            ),
        ]
    }

    @Test(arguments: validTestCases)
    func testValidDecodeManifests(tc: TestCase) throws {
        let manifest = try Manifest(from: tc.data)
        #expect(manifest == tc.expected)
    }

    static var invalidTestCases: [ErrorCase] {
        return [
            ErrorCase(
                description: "invalid rego version",
                data: #"""
                    {
                      "revision" : "7864d60dd78d748dbce54b569e939f5b0dc07486",
                      "roots": ["roles", "http/example/authz"],
                      "rego_version": 42
                    }
                    """#.data(using: .utf8)!,
                expectedErr: DecodingError.self
            ),
            ErrorCase(
                description: "missing revision",
                data: #"""
                    {
                      "roots": ["roles", "http/example/authz"]
                    }
                    """#.data(using: .utf8)!,
                expectedErr: DecodingError.self
            ),
            ErrorCase(
                description: "missing roots",
                data: #"""
                    {
                      "revision" : "7864d60dd78d748dbce54b569e939f5b0dc07486"
                    }
                    """#.data(using: .utf8)!,
                expectedErr: DecodingError.self
            ),
            ErrorCase(
                description: "nil roots",
                data: #"""
                    {
                      "revision" : "7864d60dd78d748dbce54b569e939f5b0dc07486",
                      "roots": null
                    }
                    """#.data(using: .utf8)!,
                expectedErr: DecodingError.self
            ),
        ]
    }

    @Test(arguments: invalidTestCases)
    func testInvalidDecodeManifests(tc: ErrorCase) throws {
        #expect() {
            try Manifest(from: tc.data)
        } throws: { error in
            let mirror = Mirror(reflecting: error)
            let b: Bool = mirror.subjectType == tc.expectedErr
            return b
        }
    }
}

extension BundleDecodingTests.TestCase: CustomTestStringConvertible {
    var testDescription: String { description }
}

extension BundleDecodingTests.ErrorCase: CustomTestStringConvertible {
    var testDescription: String { description }
}
