import Foundation
import Testing

@testable import Engine

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
                        // Empty roots is coerced into one root empty string
                        roots: [""],
                        regoVersion: .regoV1,
                        metadata: [:]
                    )
            ),
            TestCase(
                description: "missing revision",
                data: #"""
                    {
                      "roots": ["roles", "http/example/authz"]
                    }
                    """#.data(using: .utf8)!,
                expected:
                    Manifest(
                        revision: "",
                        roots: ["roles", "http/example/authz"],
                        regoVersion: .regoV1,
                        metadata: [:]
                    )
            ),
            TestCase(
                description: "missing roots",
                data: #"""
                    {
                      "revision" : "7864d60dd78d748dbce54b569e939f5b0dc07486"
                    }
                    """#.data(using: .utf8)!,
                expected:
                    Manifest(
                        revision: "7864d60dd78d748dbce54b569e939f5b0dc07486",
                        roots: [""]
                    )
            ),
            TestCase(
                description: "nil roots",
                data: #"""
                    {
                      "revision" : "7864d60dd78d748dbce54b569e939f5b0dc07486",
                      "roots": null
                    }
                    """#.data(using: .utf8)!,
                expected:
                    Manifest(
                        revision: "7864d60dd78d748dbce54b569e939f5b0dc07486",
                        roots: [""]
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
            )
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

@Suite("BundleDirectoryLoaderTests")
struct BundleDirectoryLoaderTests {
    struct TestCase {
        let bundleURL: URL
        let expected: [BundleFile]
    }
    
    static var testCases: [TestCase] {
        let resourcesURL = Bundle.module.resourceURL!
        
        return [
            TestCase(
                bundleURL: resourcesURL.appending(path: "TestData/Bundles/simple-directory-bundle"),
                expected: [
                    BundleFile(
                        url: resourcesURL.appending(path: "TestData/Bundles/simple-directory-bundle/data.json"),
                        data: Data()
                    )
                ]
            )
        ]
    }
    
    @Test(arguments: testCases)
    func testDirectoryLoader(tc: TestCase) throws {
        let valid = Set(["data.json", "plan.json", ".manifest"])
        let bdl = DirectorySequence(baseURL: tc.bundleURL)
        for entry in bdl.lazy.filter({ elem in
            switch elem {
            case .failure:
                return true
            case .success(let bundleFile):
                return valid.contains(bundleFile.url.lastPathComponent)
                    || bundleFile.url.pathExtension == "rego"
            }
        }) {
            switch entry {
            case .failure(let error):
                throw error
            case .success(let bundleFile):
                print(bundleFile.url)
            }
        }
    }
}

extension BundleDecodingTests.TestCase: CustomTestStringConvertible {
    var testDescription: String { description }
}

extension BundleDecodingTests.ErrorCase: CustomTestStringConvertible {
    var testDescription: String { description }
}
