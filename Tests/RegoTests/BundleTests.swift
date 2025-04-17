import AST
import Foundation
import Testing

@testable import Rego

@Suite("BundleDecodingTests")
struct BundleDecodingTests {
    struct TestCase: Sendable {
        let description: String
        let data: Data
        let expected: OPA.Manifest
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
                    OPA.Manifest(
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
                    OPA.Manifest(
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
                    OPA.Manifest(
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
                    OPA.Manifest(
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
                    OPA.Manifest(
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
                    OPA.Manifest(
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
                    OPA.Manifest(
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
                    OPA.Manifest(
                        revision: "7864d60dd78d748dbce54b569e939f5b0dc07486",
                        roots: [""]
                    )
            ),
        ]
    }

    @Test(arguments: validTestCases)
    func testValidDecodeManifests(tc: TestCase) throws {
        let manifest = try OPA.Manifest(from: tc.data)
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
            try OPA.Manifest(from: tc.data)
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

        // Unwrap the success values, nils will get dumped by compactMap
        let results: [BundleFile] = bdl.compactMap { try? $0.get() }

        let actualPaths = results.map { $0.url.path }.sorted()
        let expectedPaths = tc.expected.map { $0.url.path }.sorted()
        #expect(actualPaths == expectedPaths)
    }
}

@Suite
struct BundleLoaderTests {
    struct TestCase {
        let sourceBundle: URL
        let expected: Rego.OPA.Bundle
    }
    struct ErrorCase {
        let sourceBundle: URL
        let expectedError: Error
    }

    static func relPath(_ path: String) -> URL {
        let resourcesURL = Bundle.module.resourceURL!
        return resourcesURL.appending(path: path)
    }

    static var testCases: [TestCase] {
        get throws {
            return [
                TestCase(
                    sourceBundle: relPath("TestData/Bundles/simple-directory-bundle"),
                    expected: try Rego.OPA.Bundle(
                        manifest: Rego.OPA.Manifest(
                            revision: "e6f1a8ad-5b47-498f-a6eb-d1ecc86b63ae",
                            roots: [""],
                            regoVersion: Rego.OPA.Manifest.Version.regoV1,
                            metadata: ["name": "example-rbac"]
                        ),
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
                        data: [
                            "user_roles": [
                                "eve": [
                                    "customer"
                                ],
                                "bob": [
                                    "employee",
                                    "billing",
                                ],
                                "alice": [
                                    "admin"
                                ],
                            ],
                            "role_grants": [
                                "billing": [
                                    [
                                        "action": "read",
                                        "type": "finance",
                                    ],
                                    [
                                        "type": "finance",
                                        "action": "update",
                                    ],
                                ],
                                "customer": [
                                    [
                                        "type": "dog",
                                        "action": "read",
                                    ],
                                    [
                                        "action": "read",
                                        "type": "cat",
                                    ],
                                    [
                                        "action": "adopt",
                                        "type": "dog",
                                    ],
                                    [
                                        "type": "cat",
                                        "action": "adopt",
                                    ],
                                ],
                                "employee": [
                                    [
                                        "action": "read",
                                        "type": "dog",
                                    ],
                                    [
                                        "type": "cat",
                                        "action": "read",
                                    ],
                                    [
                                        "action": "update",
                                        "type": "dog",
                                    ],
                                    [
                                        "action": "update",
                                        "type": "cat",
                                    ],
                                ],
                            ],
                        ]
                    )
                ),
                TestCase(
                    sourceBundle: relPath("TestData/Bundles/nested-data-trees"),
                    expected: try Rego.OPA.Bundle(
                        manifest: OPA.Manifest(
                            revision: "",
                            roots: [""],
                            regoVersion: Rego.OPA.Manifest.Version.regoV1,
                            metadata: .null
                        ),
                        data: [
                            "roles": [
                                "admin",
                                "readonly",
                                "readwrite",
                            ],
                            "users": [
                                "alice",
                                "bob",
                                "mary",
                            ],
                            "extras": [
                                "metadata": [
                                    "version": "1.2.3"
                                ]
                            ],
                        ]
                    )
                ),
            ]
        }
    }

    static var errorCases: [ErrorCase] {
        [
            ErrorCase(
                sourceBundle: relPath("TestData/Bundles/invalid-manifest-not-in-root"),
                expectedError: BundleLoader.LoadError.unexpectedManifest(URL(string: "/")!)
            ),
            ErrorCase(
                sourceBundle: relPath("TestData/Bundles/invalid-data-escaped-chroot"),
                expectedError: BundleLoader.LoadError.dataEscapedRoot
            ),
        ]
    }

    @Test(arguments: try testCases)
    func testLoadingBundleFromDirectory(tc: TestCase) throws {
        let b = try BundleLoader.load(fromDirectory: tc.sourceBundle)
        // #expect(b == tc.expected)
        #expect(fuzzyBundleEquals(b, tc.expected))
    }

    @Test(arguments: errorCases)
    func testInvalidLoadingBundleFromDirectory(tc: ErrorCase) throws {
        #expect {
            let _ = try BundleLoader.load(fromDirectory: tc.sourceBundle)
        } throws: { error in
            print("Caught error: \(error)")
            let gotMirror = Mirror(reflecting: error)
            let wantMirror = Mirror(reflecting: tc.expectedError)
            return gotMirror.subjectType == wantMirror.subjectType
        }
    }

    func fuzzyBundleEquals(_ lhs: Rego.OPA.Bundle, _ rhs: Rego.OPA.Bundle) -> Bool {
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

    // TODO rework this to compare absolutePath?
    func fuzzyBundleFileEquals(_ lhs: BundleFile, _ rhs: BundleFile) -> Bool {
        // TODO check paths relative to the bundle base
        guard lhs.url.lastPathComponent == rhs.url.lastPathComponent else {
            print("\(lhs.url.lastPathComponent) != \(rhs.url.lastPathComponent)")
            return false
        }

        // TODO ignore data for now
        return true
    }

    struct BundleConsistencyTestCase {
        let description: String
        let sourceBundle: URL
        let rootsOverride: [String]
        let isValid: Bool
    }
    static var consistencyTests: [BundleConsistencyTestCase] {
        [
            BundleConsistencyTestCase(
                description: "simple bundle, roots allow all",
                sourceBundle: relPath("TestData/Bundles/simple-directory-bundle"),
                rootsOverride: [""],
                isValid: true
            ),
            BundleConsistencyTestCase(
                description: "be explicit about the roots within data.json",
                sourceBundle: relPath("TestData/Bundles/simple-directory-bundle"),
                rootsOverride: ["role_grants", "user_roles"],
                isValid: true
            ),
            BundleConsistencyTestCase(
                description: "be explicit about the roots one is out of bounds",
                sourceBundle: relPath("TestData/Bundles/simple-directory-bundle"),
                rootsOverride: ["not_role_grants", "user_roles"],
                isValid: false
            ),
            BundleConsistencyTestCase(
                description: "roots internal conflict with wildcard",
                sourceBundle: relPath("TestData/Bundles/simple-directory-bundle"),
                rootsOverride: ["", "user_roles"],
                isValid: false
            ),
            BundleConsistencyTestCase(
                // TODO we might decide to make this legal in the future (within a bundle, not across bundles)
                // and double check upstream reference architecture behavior
                description: "roots internal conflict",
                sourceBundle: relPath("TestData/Bundles/simple-directory-bundle"),
                rootsOverride: ["role_grants", "user_roles", "user_roles/uh-oh"],
                isValid: false
            ),
        ]
    }

    @Test(arguments: consistencyTests)
    func testBundleConsistency(tc: BundleConsistencyTestCase) throws {
        let result = Result {
            // Intercept .manifest files in the sequence and rewrite their data according to the test case
            let files: any Sequence<Result<BundleFile, any Error>> = try DirectoryLoader(baseURL: tc.sourceBundle).lazy
                .map { fileResult in
                    let file = try fileResult.get()
                    if file.url.lastPathComponent == ".manifest" {
                        // Serialize a new manifest with the roots override
                        let d = ["roots": tc.rootsOverride]
                        let manifestData = try JSONEncoder().encode(d)

                        return .success(
                            BundleFile(url: file.url, data: manifestData)
                        )
                    }
                    return .success(file)
                }

            let loader = BundleLoader(fromFileSequence: files)
            _ = try loader.load()
        }

        if !tc.isValid {
            #expect(throws: (any Error).self, "expected error, but got none") {
                try result.get()
            }
        } else {
            #expect(throws: Never.self, "expected sucess, but got unexpected error") {
                try result.get()
            }
        }

    }

}

@Suite
struct RelativePathTests {
    struct TestCase {
        var description: String
        var baseURL: URL
        var childURL: URL
        var expected: String
    }

    static var allTests: [TestCase] {
        return [
            TestCase(
                description: "simple relative",
                baseURL: URL(fileURLWithPath: "/foo/bar"),
                childURL: URL(fileURLWithPath: "/foo/bar/baz/qux"),
                expected: "baz/qux"
            ),
            TestCase(
                description: "simple relative with trailing slash",
                baseURL: URL(fileURLWithPath: "/foo/bar/"),
                childURL: URL(fileURLWithPath: "/foo/bar/baz/qux"),
                expected: "baz/qux"
            ),
            TestCase(
                description: "not file urls",
                baseURL: URL(string: "http://localhost:8080/foo/bar")!,
                childURL: URL(string: "http://localhost:8080/foo/bar/baz/qux")!,
                expected: ""
            ),
            TestCase(
                description: "not an descendent path",
                baseURL: URL(fileURLWithPath: "/foo/bar"),
                childURL: URL(fileURLWithPath: "/nope/bar/baz/qux"),
                expected: ""
            ),
            TestCase(
                description: "equal",
                baseURL: URL(fileURLWithPath: "/foo/bar"),
                childURL: URL(fileURLWithPath: "/foo/bar"),
                expected: "."
            ),
        ]
    }

    @Test(arguments: allTests)
    func testRelativePath(_ tc: TestCase) {
        let actual = makeRelativeURL(from: tc.baseURL, to: tc.childURL)
        let relPath = actual?.relativePath ?? ""
        #expect(relPath == tc.expected)
    }

}

@Suite
struct PathTests {
    struct TestCase {
        var paths: [[String]]
        var otherPaths: [[String]]
        var hasConflict: Bool
    }

    static var testCases: [TestCase] {
        [
            TestCase(
                paths: [
                    ["a", "b"]
                ],
                otherPaths: [
                    ["c", "d"]
                ],
                hasConflict: false
            ),
            TestCase(
                paths: [
                    ["a", "b"]
                ],
                otherPaths: [
                    ["a", "d"]
                ],
                hasConflict: false
            ),
            TestCase(
                paths: [
                    ["a", "b"]
                ],
                otherPaths: [
                    ["a", "b", "c"]
                ],
                hasConflict: true
            ),
            TestCase(
                paths: [
                    ["a", "b", "c"]
                ],
                otherPaths: [
                    ["a", "b"]
                ],
                hasConflict: true
            ),
            TestCase(
                paths: [
                    ["a", "b"],
                    ["a", "c"],
                ],
                otherPaths: [
                    ["a", "d"],
                    ["a", "e"],
                ],
                hasConflict: false
            ),
            TestCase(
                paths: [
                    ["a", "b"],
                    ["a", "c"],
                ],
                otherPaths: [
                    ["a", "c"],
                    ["a", "e"],
                ],
                hasConflict: true
            ),
            TestCase(
                paths: [
                    ["a", "b"],
                    ["a", "c"],
                ],
                otherPaths: [
                    ["a", "c", "z"],
                    ["a", "e"],
                ],
                hasConflict: true
            ),
            TestCase(
                paths: [
                    ["a"]
                ],
                otherPaths: [
                    ["a", "c", "z"]
                ],
                hasConflict: true
            ),
            TestCase(
                paths: [
                    ["a", "b"],
                    ["a", "b", "c"],
                ],
                otherPaths: [
                    ["a", "c", "z"]
                ],
                hasConflict: false
            ),
        ]
    }

    // This test verifies whether multiple sets of root path segments conflict with
    // each other.
    // Root paths conflict if one is a strict prefix of the other.
    @Test(arguments: testCases)
    func testOverlap(tc: TestCase) {
        let trieA: TrieNode = tc.paths.reduce(into: TrieNode(value: "data", isLeaf: false, children: [:])) {
            (node, path) in
            let (merged, _) = TrieNode.merge(node: node, withSegments: path[...])
            node = merged
        }
        let trieB: TrieNode = tc.otherPaths.reduce(into: TrieNode(value: "data", isLeaf: false, children: [:])) {
            (node, path) in
            let (merged, _) = TrieNode.merge(node: node, withSegments: path[...])
            node = merged
        }

        #expect(trieA.overlaps(with: trieB) == tc.hasConflict)
    }

    struct DataTreeContainedTestCase {
        var paths: [[String]]
        var data: AST.RegoValue
        var isValid: Bool
    }

    static var dataTreeContainedTests: [DataTreeContainedTestCase] {
        [
            DataTreeContainedTestCase(
                paths: [["foo", "bar"]],
                data: [
                    "foo": [
                        "bar": 42
                    ]
                ],
                isValid: true
            ),
            DataTreeContainedTestCase(
                paths: [[""]],
                data: [
                    "foo": [
                        "bar": 42
                    ],
                    "baz": 777,
                ],
                isValid: true
            ),
            DataTreeContainedTestCase(
                paths: [["foo", "bar"]],
                data: [
                    "foo": [
                        "bar": 42
                    ],
                    "baz": 777,
                ],
                isValid: false
            ),
            DataTreeContainedTestCase(
                paths: [["foo", "bar"]],
                data: [
                    "foo": [
                        "baz": 42
                    ]
                ],
                isValid: false
            ),
            DataTreeContainedTestCase(
                paths: [["foo", "bar"]],
                data: [:],
                isValid: true
            ),
            DataTreeContainedTestCase(
                paths: [[""]],
                data: ["foo": 42],
                isValid: true
            ),
            DataTreeContainedTestCase(
                paths: [],
                data: ["foo": 42],
                isValid: true
            ),
        ]
    }

    // Verify whether data trees fall under defined roots path segments.
    // A data tree is valid if all its keys fall within the scope of the roots.
    @Test(arguments: dataTreeContainedTests)
    func testDataTreeContained(tc: DataTreeContainedTestCase) {
        var trie: TrieNode = tc.paths.reduce(into: TrieNode(value: "data", isLeaf: false, children: [:])) {
            (node, path) in
            // NOTE! We filter out empty string paths and address them below if needed
            let (merged, _) = TrieNode.merge(node: node, withSegments: path.filter { $0 != "" }[...])
            node = merged
        }
        // Hack for when we have no paths at all
        if trie.children.isEmpty {
            trie.isLeaf = true
        }

        #expect(trie.contains(dataTree: tc.data) == tc.isValid)
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
