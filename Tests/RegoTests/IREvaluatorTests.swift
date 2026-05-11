import AST
import Foundation
import Testing

@testable import Rego

@Suite("IREvaluatorTests")
struct IREvaluatorTests {
    struct TestCase: Sendable {
        let description: String
        let sourceBundles: [URL]
        let query: String
        let input: AST.RegoValue
        let expectedResult: Rego.ResultSet
    }

    struct ErrorCase {
        let description: String
        let sourceBundles: [URL]
        var query: String = ""
        var input: AST.RegoValue = [:]
        let expectedError: Rego.RegoError.Code
    }

    static func relPath(_ path: String) -> URL {
        let resourcesURL = Bundle.module.resourceURL!
        return resourcesURL.appending(path: path)
    }

    static var validTestCases: [TestCase] {
        return [
            TestCase(
                description: "happy path basic policy with input allow",
                sourceBundles: [relPath("TestData/Bundles/basic-policy-with-input-bundle")],
                query: "data.main.allow",
                input: [
                    "should_allow": true
                ],
                expectedResult: [
                    [
                        "result": true
                    ]
                ]
            ),
            TestCase(
                description: "happy path basic policy with input deny explicit",
                sourceBundles: [relPath("TestData/Bundles/basic-policy-with-input-bundle")],
                query: "data.main.allow",
                input: [
                    "should_allow": false
                ],
                expectedResult: Rego.ResultSet.empty
            ),
            TestCase(
                description: "happy path basic policy with input deny undefined input key",
                sourceBundles: [relPath("TestData/Bundles/basic-policy-with-input-bundle")],
                query: "data.main.allow",
                input: [:],
                expectedResult: Rego.ResultSet.empty
            ),
            TestCase(
                description: "happy path rbac allow non-admin",
                sourceBundles: [relPath("TestData/Bundles/simple-directory-bundle")],
                query: "data.app.rbac.allow",
                input: [
                    "user": "bob",
                    "type": "dog",
                    "action": "update",
                ],
                expectedResult: [
                    [
                        "result": true
                    ]
                ]
            ),
            TestCase(
                description: "happy path rbac allow admin",
                sourceBundles: [relPath("TestData/Bundles/simple-directory-bundle")],
                query: "data.app.rbac.allow",
                input: [
                    "user": "alice",
                    "type": "iMac",
                    "action": "purchase",
                ],
                expectedResult: [
                    [
                        "result": true
                    ]
                ]
            ),
            TestCase(
                description: "happy path rbac deny missing grant in data json",
                sourceBundles: [relPath("TestData/Bundles/simple-directory-bundle")],
                query: "data.app.rbac.allow",
                input: [
                    "user": "bob",
                    "type": "parakeet",
                    "action": "read",
                ],
                expectedResult: [
                    [
                        "result": false
                    ]
                ]
            ),
        ]
    }

    static var errorTestCases: [ErrorCase] {
        return [
            ErrorCase(
                description: "query not found in valid bundle",
                sourceBundles: [relPath("TestData/Bundles/simple-directory-bundle")],
                query: "data.not.found.query",
                input: [:],
                expectedError: Rego.RegoError.Code.unknownQuery
            ),
            ErrorCase(
                description: "duplicate valid bundles",
                sourceBundles: [
                    relPath("TestData/Bundles/simple-directory-bundle"),
                    // The test uses the last path element as the bundle name, so these collide.
                    relPath("TestData/Bundles/simple-directory-bundle"),
                ],
                query: "data.app.rbac.allow",
                expectedError: Rego.RegoError.Code.bundleNameConflictError
            ),
            ErrorCase(
                description: "bundle with rego but no plan json",
                sourceBundles: [relPath("TestData/Bundles/simple-directory-no-plan-bundle")],
                expectedError: Rego.RegoError.Code.noPlansFoundError
            ),
            ErrorCase(
                description: "all data no plan",
                sourceBundles: [
                    relPath("TestData/Bundles/nested-data-trees")
                ],
                expectedError: Rego.RegoError.Code.noPlansFoundError
            ),
            ErrorCase(
                description: "bundle with invalid plan json",
                sourceBundles: [relPath("TestData/Bundles/invalid-plan-json-bundle")],
                expectedError: Rego.RegoError.Code.bundleInitializationError
            ),
        ]
    }

    @Test(arguments: validTestCases)
    func testValidEvaluations(tc: TestCase) async throws {
        var engine = OPA.Engine(
            bundlePaths: tc.sourceBundles.map({ OPA.Engine.BundlePath(name: $0.lastPathComponent, url: $0) }))
        let bufferTracer = OPA.Trace.BufferedQueryTracer(level: .full)
        let actual = try await engine.prepareForEvaluation(query: tc.query).evaluate(
            input: tc.input,
            tracer: bufferTracer
        )
        if tc.expectedResult != actual {
            let tempDirectoryURL = FileManager.default.temporaryDirectory
            let tempFileURL = tempDirectoryURL.appendingPathComponent(UUID().uuidString)
            if !FileManager.default.createFile(atPath: tempFileURL.path, contents: Data(), attributes: nil) {
                print(
                    """
                    WARNING! Failed to create a temporary file in \(tempDirectoryURL).
                    Debug Trace will not be created.
                    """
                )
            } else {
                let tempFileHandle = try FileHandle(forWritingTo: tempFileURL)
                bufferTracer.prettyPrint(to: tempFileHandle)
                print("Debug Trace: \(tempFileURL.path)")
            }
        }
        #expect(tc.expectedResult == actual)
    }

    @Test(arguments: errorTestCases)
    func testInvalidEvaluations(tc: ErrorCase) async throws {
        var engine = OPA.Engine(
            bundlePaths: tc.sourceBundles.map({ OPA.Engine.BundlePath(name: $0.lastPathComponent, url: $0) }))

        await #expect(Comment(rawValue: tc.description)) {
            let _ = try await engine.prepareForEvaluation(query: tc.query).evaluate(input: tc.input)
            #expect(Bool(false), "expected evaluation to throw an error")
        } throws: { error in
            guard let regoError = error as? Rego.RegoError else {
                return false
            }
            return regoError.code == tc.expectedError
        }
    }
}

extension IREvaluatorTests.TestCase: CustomTestStringConvertible {
    var testDescription: String { description }
}
