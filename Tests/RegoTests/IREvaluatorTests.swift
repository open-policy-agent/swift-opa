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
            TestCase(
                description: "happy path basic policy with input allow",
                sourceBundle: relPath("TestData/Bundles/basic-policy-with-input-bundle"),
                query: "main/allow",
                input: AST.RegoValue([
                    "should_allow": AST.RegoValue.boolean(true)
                ]),
                expectedResult: Rego.ResultSet([
                    AST.RegoValue([
                        "allow": AST.RegoValue.boolean(true)
                    ])
                ])
            ),
            TestCase(
                description: "happy path basic policy with input deny explicit",
                sourceBundle: relPath("TestData/Bundles/basic-policy-with-input-bundle"),
                query: "main/allow",
                input: AST.RegoValue([
                    "should_allow": AST.RegoValue.boolean(false)
                ]),
                expectedResult: Rego.ResultSet([
                    AST.RegoValue([
                        "allow": AST.RegoValue.boolean(false)
                    ])
                ])
            ),
            TestCase(
                description: "happy path basic policy with input deny undefined input key",
                sourceBundle: relPath("TestData/Bundles/basic-policy-with-input-bundle"),
                query: "main/allow",
                input: AST.RegoValue.object([:]),
                expectedResult: Rego.ResultSet([
                    AST.RegoValue([
                        "allow": AST.RegoValue.boolean(false)
                    ])
                ])
            ),
            TestCase(
                // Requires..
                //
                // Statements:
                //     AssignVarOnceStmt
                //     AssignVarStmt
                //     BlockStmt
                //     BreakStmt
                //     CallStmt
                //     DotStmt
                //     EqualStmt
                //     IsDefinedStmt
                //     IsUndefinedStmt
                //     MakeObjectStmt
                //     MakeSetStmt
                //     NotEqualStmt
                //     ObjectInsertStmt
                //     ResetLocalStmt
                //     ResultSetAddStmt
                //     ReturnLocalStmt
                //     ScanStmt
                //     SetAddStmt
                //
                // Builtins:
                //    internal.member_2 (aka "in", ref https://github.com/open-policy-agent/opa/blob/6e83f2ac535b501d8d26859f71d32e31ec931ca6/v1/ast/builtins.go#L351-L362)
                //
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
                        "allow": AST.RegoValue.boolean(true)
                    ])
                ])
            ),
            TestCase(
                description: "happy path rbac allow admin",
                sourceBundle: relPath("TestData/Bundles/simple-directory-bundle"),
                query: "app/rbac/allow",
                input: AST.RegoValue([
                    "user": AST.RegoValue.string("alice"),
                    "type": AST.RegoValue.string("iMac"),
                    "action": AST.RegoValue.string("purchase"),
                ]),
                expectedResult: Rego.ResultSet([
                    AST.RegoValue([
                        "allow": AST.RegoValue.boolean(true)
                    ])
                ])
            ),
            TestCase(
                description: "happy path rbac deny missing grant in data json",
                sourceBundle: relPath("TestData/Bundles/simple-directory-bundle"),
                query: "app/rbac/allow",
                input: AST.RegoValue([
                    "user": AST.RegoValue.string("bob"),
                    "type": AST.RegoValue.string("parakeet"),
                    "action": AST.RegoValue.string("read"),
                ]),
                expectedResult: Rego.ResultSet([
                    AST.RegoValue([
                        "allow": AST.RegoValue.boolean(false)
                    ])
                ])
            ),
        ]
    }

    static var errorTestCases: [ErrorCase] {
        return [
            ErrorCase(
                description: "query not found in valid bundle",
                sourceBundle: relPath("TestData/Bundles/simple-directory-bundle"),
                query: "not/found/query",
                input: AST.RegoValue.object([:]),
                expectedError: Rego.EvaluationError.unknownQuery(query: "not/found/query").self
            ),
            ErrorCase(
                description: "bundle with no plan json",
                sourceBundle: relPath("TestData/Bundles/simple-directory-no-plan-bundle"),
                query: "not/found/query",
                input: AST.RegoValue.object([:]),
                expectedError: Rego.EvaluationError.unknownQuery(query: "not/found/query").self
            ),
            ErrorCase(
                description: "bundle with invalid plan json",
                sourceBundle: relPath("TestData/Bundles/invalid-plan-json-bundle"),
                expectedError: Rego.EvaluatorError.bundleInitializationFailed(
                    bundle: "invalid-plan-json-bundle",
                    reason: ""
                ).self
            ),
        ]
    }

    @Test(arguments: validTestCases)
    func testValidEvaluations(tc: TestCase) async throws {
        let b = try BundleLoader.load(fromDirectory: tc.sourceBundle)
        let e = try await IREvaluator(bundles: [tc.sourceBundle.lastPathComponent: b])
        let actual = try await e.evaluate(
            withContext: Rego.EvaluationContext(
                // TODO: How do we get the store set on here hydrated from the bundle?
                // I guess we need a step after loading the bundle but before making this eval context?
                query: tc.query,
                input: tc.input
            )
        )
        #expect(tc.expectedResult == actual)
    }

    @Test(arguments: errorTestCases)
    func testInvalidEvaluations(tc: ErrorCase) async throws {
        let b = try BundleLoader.load(fromDirectory: tc.sourceBundle)
        await #expect(Comment(rawValue: tc.description)) {
            let e = try await IREvaluator(bundles: [tc.sourceBundle.lastPathComponent: b])
            let _ = try await e.evaluate(
                withContext: Rego.EvaluationContext(
                    // TODO: How do we get the store set on here hydrated from the bundle?
                    // I guess we need a step after loading the bundle but before making this eval context?
                    query: tc.query,
                    input: tc.input
                )
            )
        } throws: { error in
            let gotMirror = Mirror(reflecting: error)
            let wantMirror = Mirror(reflecting: tc.expectedError)
            // TODO: Can/should we compare the actual error contents too?
            return gotMirror.subjectType == wantMirror.subjectType
        }
    }
}
