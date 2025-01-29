import AST
import Foundation
import Testing

@testable import Rego

@Suite("IREvaluatorTests")
struct IREvaluatorTests {
    struct TestCase: Sendable {
        let description: String
        let sourceBundle: URL
        let query: String
        let input: AST.RegoValue
        let expectedResult: Rego.ResultSet
    }

    struct ErrorCase {
        let description: String
        let sourceBundle: URL
        var query: String = ""
        var input: AST.RegoValue = .object([:])
        let expectedError: Error
    }

    static func relPath(_ path: String) -> URL {
        let resourcesURL = Bundle.module.resourceURL!
        return resourcesURL.appending(path: path)
    }

    static var validTestCases: [TestCase] {
        return [
            //            TestCase(
            //                description: "happy path basic policy with input allow",
            //                sourceBundle: relPath("TestData/Bundles/basic-policy-with-input-bundle"),
            //                query: "main/allow",
            //                input: AST.RegoValue([
            //                    "should_allow": AST.RegoValue.boolean(true)
            //                ]),
            //                expectedResult: Rego.ResultSet([
            //                    AST.RegoValue([
            //                        "result": AST.RegoValue.boolean(true)
            //                    ])
            //                ])
            //            ),
            //            TestCase(
            //                description: "happy path basic policy with input deny explicit",
            //                sourceBundle: relPath("TestData/Bundles/basic-policy-with-input-bundle"),
            //                query: "main/allow",
            //                input: AST.RegoValue([
            //                    "should_allow": AST.RegoValue.boolean(false)
            //                ]),
            //                expectedResult: Rego.ResultSet.empty
            //            ),
            //            TestCase(
            //                description: "happy path basic policy with input deny undefined input key",
            //                sourceBundle: relPath("TestData/Bundles/basic-policy-with-input-bundle"),
            //                query: "main/allow",
            //                input: AST.RegoValue.object([:]),
            //                expectedResult: Rego.ResultSet.empty
            //            ),
            TestCase(
                description: "happy path rbac allow non-admin",
                sourceBundle: relPath("TestData/Bundles/simple-directory-bundle"),
                query: "app/rbac/allow",
                input: AST.RegoValue([
                    "user": AST.RegoValue.string("bob"),
                    "type": AST.RegoValue.string("dog"),
                    "action": AST.RegoValue.string("update"),
                ]),
                expectedResult: Rego.ResultSet([
                    AST.RegoValue([
                        "result": AST.RegoValue.boolean(true)
                    ])
                ])
            )
            //            TestCase(
            //                description: "happy path rbac allow admin",
            //                sourceBundle: relPath("TestData/Bundles/simple-directory-bundle"),
            //                query: "app/rbac/allow",
            //                input: AST.RegoValue([
            //                    "user": AST.RegoValue.string("alice"),
            //                    "type": AST.RegoValue.string("iMac"),
            //                    "action": AST.RegoValue.string("purchase"),
            //                ]),
            //                expectedResult: Rego.ResultSet([
            //                    AST.RegoValue([
            //                        "result": AST.RegoValue.boolean(true)
            //                    ])
            //                ])
            //            ),
            //            TestCase(
            //                description: "happy path rbac deny missing grant in data json",
            //                sourceBundle: relPath("TestData/Bundles/simple-directory-bundle"),
            //                query: "app/rbac/allow",
            //                input: AST.RegoValue([
            //                    "user": AST.RegoValue.string("bob"),
            //                    "type": AST.RegoValue.string("parakeet"),
            //                    "action": AST.RegoValue.string("read"),
            //                ]),
            //                expectedResult: Rego.ResultSet([
            //                    AST.RegoValue([
            //                        "result": AST.RegoValue.boolean(false)
            //                    ])
            //                ])
            //            ),
        ]
    }

    static var errorTestCases: [ErrorCase] {
        return [
            //            ErrorCase(
            //                description: "query not found in valid bundle",
            //                sourceBundle: relPath("TestData/Bundles/simple-directory-bundle"),
            //                query: "not/found/query",
            //                input: AST.RegoValue.object([:]),
            //                expectedError: Rego.EvaluationError.unknownQuery(query: "not/found/query").self
            //            ),
            //            ErrorCase(
            //                description: "bundle with no plan json",
            //                sourceBundle: relPath("TestData/Bundles/simple-directory-no-plan-bundle"),
            //                query: "not/found/query",
            //                input: AST.RegoValue.object([:]),
            //                expectedError: Rego.EvaluationError.unknownQuery(query: "not/found/query").self
            //            ),
            //            ErrorCase(
            //                description: "bundle with invalid plan json",
            //                sourceBundle: relPath("TestData/Bundles/invalid-plan-json-bundle"),
            //                expectedError: Rego.EvaluatorError.bundleInitializationFailed(
            //                    bundle: "invalid-plan-json-bundle",
            //                    reason: ""
            //                ).self
            //            ),
        ]
    }

    @Test(arguments: validTestCases)
    func testValidEvaluations(tc: TestCase) async throws {
        var engine = try Engine(withBundlePaths: [Engine.BundlePath(name: "default", url: tc.sourceBundle)])
        try await engine.prepare()
        let bufferTracer = BufferedQueryTracer(level: .full)
        let actual = try await engine.evaluate(
            query: tc.query,
            input: tc.input,
            tracer: bufferTracer
        )
        if tc.expectedResult != actual {
            let tempDirectoryURL = FileManager.default.temporaryDirectory
            let tempFileURL = tempDirectoryURL.appendingPathComponent(UUID().uuidString)
            FileManager.default.createFile(atPath: tempFileURL.path, contents: Data(), attributes: nil)
            let tempFileHandle = try FileHandle(forWritingTo: tempFileURL)
            bufferTracer.prettyPrint(out: tempFileHandle)
            print("Debug Trace: \(tempFileURL.path)")
        }
        #expect(tc.expectedResult == actual)
    }

    @Test(arguments: errorTestCases)
    func testInvalidEvaluations(tc: ErrorCase) async throws {
        var engine = try Engine(withBundlePaths: [Engine.BundlePath(name: "default", url: tc.sourceBundle)])

        await #expect(Comment(rawValue: tc.description)) {
            try await engine.prepare()
            let _ = try await engine.evaluate(query: tc.query, input: tc.input)
            #expect(Bool(false), "expected evaluation to throw an error")
        } throws: { error in
            let gotMirror = Mirror(reflecting: error)
            let wantMirror = Mirror(reflecting: tc.expectedError)
            // TODO: Can/should we compare the actual error contents too?
            return gotMirror.subjectType == wantMirror.subjectType
        }
    }
}

extension IREvaluatorTests.TestCase: CustomTestStringConvertible {
    var testDescription: String { description }
}
