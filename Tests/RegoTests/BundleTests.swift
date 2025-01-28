import AST
import Foundation
import Testing

@testable import Rego

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
                        metadata: .null
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
                        metadata: .object([
                            .string("foo"): .string("bar"),
                            .string("number"): .number(42),
                        ])
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
                        metadata: .null
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
                        metadata: .null
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
                        metadata: .null
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
                        metadata: .null
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
        let sourceBundle: URL
        let expected: [BundleFile]
    }

    static func relPath(_ path: String) -> URL {
        let resourcesURL = Bundle.module.resourceURL!
        return resourcesURL.appending(path: path)
    }

    static var testCases: [TestCase] {
        return [
            TestCase(
                sourceBundle: relPath("TestData/Bundles/simple-directory-bundle"),
                expected: [
                    BundleFile(
                        url: relPath("TestData/Bundles/simple-directory-bundle/.manifest"),
                        data: Data()
                    ),
                    BundleFile(
                        url: relPath("TestData/Bundles/simple-directory-bundle/data.json"),
                        data: Data()
                    ),
                    BundleFile(
                        url: relPath("TestData/Bundles/simple-directory-bundle/plan.json"),
                        data: Data()
                    ),
                    BundleFile(
                        url: relPath("TestData/Bundles/simple-directory-bundle/app/rbac.rego"),
                        data: Data()
                    ),
                ]
            )
        ]
    }

    @Test(arguments: testCases)
    func testDirectoryLoader(tc: TestCase) throws {
        let bdl = DirectoryLoader(baseURL: tc.sourceBundle)

        let results: [BundleFile] = bdl.compactMap { try? $0.get() }  // Unwrap the success values, nils will get dumped by compactMap

        let actualPaths = results.map { $0.url.path }.sorted()
        let expectedPaths = tc.expected.map { $0.url.path }.sorted()
        #expect(actualPaths == expectedPaths)
    }
}

@Suite
struct BundleLoaderTests {
    struct TestCase {
        let sourceBundle: URL
        let expected: Rego.Bundle
    }

    static func relPath(_ path: String) -> URL {
        let resourcesURL = Bundle.module.resourceURL!
        return resourcesURL.appending(path: path)
    }

    static var testCases: [TestCase] {
        return [
            TestCase(
                sourceBundle: relPath("TestData/Bundles/simple-directory-bundle"),
                expected: Rego.Bundle(
                    manifest: Rego.Manifest(
                        revision: "e6f1a8ad-5b47-498f-a6eb-d1ecc86b63ae",
                        roots: [""], regoVersion: Rego.Manifest.Version.regoV1,
                        metadata: .object([.string("name"): AST.RegoValue.string("example-rbac")])),

                    planFiles: [
                        Rego.BundleFile(
                            url: relPath("TestData/Bundles/simple-directory-bundle/plan.json"),
                            data: Data()
                        )
                    ],
                    regoFiles: [
                        Rego.BundleFile(
                            url: relPath("TestData/Bundles/simple-directory-bundle/rbac.rego"),
                            data: Data()
                        )
                    ],
                    data:
                        AST.RegoValue.object([
                            .string("user_roles"): .object([
                                .string("eve"): .array([
                                    .string("customer")
                                ]),
                                .string("bob"): AST.RegoValue.array([
                                    .string("employee"),
                                    .string("billing"),
                                ]),
                                .string("alice"): AST.RegoValue.array([
                                    .string("admin")
                                ]),
                            ]),
                            .string("role_grants"): .object([
                                .string("billing"): .array([
                                    .object([
                                        .string("action"): .string("read"),
                                        .string("type"): .string("finance"),
                                    ]),
                                    .object([
                                        .string("type"): .string("finance"),
                                        .string("action"): .string("update"),
                                    ]),
                                ]),
                                .string("customer"): .array([
                                    .object([
                                        .string("type"): .string("dog"),
                                        .string("action"): .string("read"),
                                    ]),
                                    .object([
                                        .string("action"): .string("read"),
                                        .string("type"): .string("cat"),
                                    ]),
                                    .object([
                                        .string("action"): .string("adopt"),
                                        .string("type"): .string("dog"),
                                    ]),
                                    .object([
                                        .string("type"): .string("cat"),
                                        .string("action"): .string("adopt"),
                                    ]),
                                ]),
                                .string("employee"): .array([
                                    .object([
                                        .string("action"): .string("read"),
                                        .string("type"): .string("dog"),
                                    ]),
                                    .object([
                                        .string("type"): .string("cat"),
                                        .string("action"): .string("read"),
                                    ]),
                                    .object([
                                        .string("action"): .string("update"),
                                        .string("type"): .string("dog"),
                                    ]),
                                    .object([
                                        .string("action"): .string("update"),
                                        .string("type"): .string("cat"),
                                    ]),
                                ]),
                            ]),
                        ])
                )
            )
        ]
    }

    @Test(arguments: testCases)
    func testLoadingBundleFromDirectory(tc: TestCase) async throws {
        let b = try BundleLoader.load(fromDirectory: tc.sourceBundle)
        // #expect(b == tc.expected)
        #expect(fuzzyBundleEquals(b, tc.expected))
    }

    func fuzzyBundleEquals(_ lhs: Rego.Bundle, _ rhs: Rego.Bundle) -> Bool {
        guard lhs.manifest == rhs.manifest else {
            return false
        }

        guard lhs.planFiles.count == rhs.planFiles.count else {
            return false
        }

        for (lhsFile, rhsFile) in zip(lhs.planFiles, rhs.planFiles) {
            guard fuzzyBundleFileEquals(lhsFile, rhsFile) else {
                return false
            }
        }

        guard lhs.regoFiles.count == rhs.regoFiles.count else {
            return false
        }

        for (lhsFile, rhsFile) in zip(lhs.regoFiles, rhs.regoFiles) {
            guard fuzzyBundleFileEquals(lhsFile, rhsFile) else {
                return false
            }
        }

        guard lhs.data == rhs.data else {
            return false
        }

        return true
    }

    func fuzzyBundleFileEquals(_ lhs: BundleFile, _ rhs: BundleFile) -> Bool {
        // TODO check paths relative to the bundle base
        guard lhs.url.lastPathComponent == rhs.url.lastPathComponent else {
            print("\(lhs.url.lastPathComponent) != \(rhs.url.lastPathComponent)")
            return false
        }

        // TODO ignore data for now
        return true
    }

}

extension BundleDecodingTests.TestCase: CustomTestStringConvertible {
    var testDescription: String { description }
}

extension BundleDecodingTests.ErrorCase: CustomTestStringConvertible {
    var testDescription: String { description }
}

extension BundleDirectoryLoaderTests.TestCase: CustomTestStringConvertible {
    var testDescription: String { sourceBundle.lastPathComponent }
}

extension BundleLoaderTests.TestCase: CustomTestStringConvertible {
    var testDescription: String { sourceBundle.lastPathComponent }
}
