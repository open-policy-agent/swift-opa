import AST
import Foundation
import IR
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
        var input: AST.RegoValue = [:]
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
                sourceBundle: relPath("TestData/Bundles/basic-policy-with-input-bundle"),
                query: "data.main.allow",
                input: [
                    "should_allow": false
                ],
                expectedResult: Rego.ResultSet.empty
            ),
            TestCase(
                description: "happy path basic policy with input deny undefined input key",
                sourceBundle: relPath("TestData/Bundles/basic-policy-with-input-bundle"),
                query: "data.main.allow",
                input: [:],
                expectedResult: Rego.ResultSet.empty
            ),
            TestCase(
                description: "happy path rbac allow non-admin",
                sourceBundle: relPath("TestData/Bundles/simple-directory-bundle"),
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
                sourceBundle: relPath("TestData/Bundles/simple-directory-bundle"),
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
                sourceBundle: relPath("TestData/Bundles/simple-directory-bundle"),
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
                sourceBundle: relPath("TestData/Bundles/simple-directory-bundle"),
                query: "data.not.found.query",
                input: [:],
                expectedError: Rego.EvaluationError.unknownQuery(query: "not/found/query").self
            ),
            ErrorCase(
                description: "bundle with no plan json",
                sourceBundle: relPath("TestData/Bundles/simple-directory-no-plan-bundle"),
                query: "data.not.found.query",
                input: [:],
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

@Suite
struct IRStatementTests {
    struct TestCase {
        var description: String
        // stmt is the statement to evaluation
        var stmt: any Statement
        // locals are the input locals state
        var locals: Locals
        // If provided, inject a ReturnSetStatment to return this local
        var returnIdx: Local?
        // If provided, expectLocals will be overlaid over locals and compared to the
        // state of the frame after evaluation.
        var expectLocals: Locals?
        // expectError, if true, means we expect the statement to throw and exception
        var expectError: Bool = false
        // expectResult - if an explicit value is set, we will compare that to the resultSet.
        // If this is left nil, and returnIdx was set, we will automatically compare to the
        // same local as returnIdx (which we expected to be returned)
        var expectResult: ResultSet? = nil
    }

    func mergeLocals(_ lhs: Locals, _ rhs: Locals?) -> Locals {
        guard let rhs else {
            return lhs
        }
        return lhs.merging(rhs) { (_, new) in new }
    }

    func prepareFrame(forStatement stmt: any Statement, withLocals locals: Locals, andReturn returnIdx: Local? = nil)
        -> (IREvaluationContext, Ptr<Frame>)
    {
        var blocks: [Block] = [
            Block(statements: [stmt])
        ]
        if let returnIdx {
            blocks[0].statements.append(
                IR.ResultSetAddStatement(value: returnIdx)
            )
        }

        let policy = IndexedIRPolicy(policy: IR.Policy())
        let ctx = EvaluationContext(query: "", input: [:])
        let irCtx = IREvaluationContext(ctx: ctx, policy: policy)

        return (
            irCtx,
            Ptr(toCopyOf: Frame(withCtx: irCtx, blocks: blocks, locals: locals))
        )
    }

    static let allTests: [TestCase] = [
        objectInsertOnceStmtTests
    ].flatMap { $0 }

    static let objectInsertOnceStmtTests: [TestCase] = [
        TestCase(
            description: "first insert succeeds",
            stmt: IR.ObjectInsertOnceStatement(
                key: IR.Operand(type: .local, value: .localIndex(2)),
                value: IR.Operand(type: .local, value: .localIndex(3)),
                object: IR.Local(4)
            ),
            locals: [
                2: "key",
                3: "value",
                4: [:],
            ],
            returnIdx: Local(4),
            expectLocals: [
                4: ["key": "value"]
            ]
        ),
        TestCase(
            description: "second insert with equal value succeeds",
            stmt: IR.ObjectInsertOnceStatement(
                key: IR.Operand(type: .local, value: .localIndex(2)),
                value: IR.Operand(type: .local, value: .localIndex(3)),
                object: IR.Local(4)
            ),
            locals: [
                2: "key",
                3: "prev_value",
                4: ["foo": "bar", "key": "prev_value"],
            ],
            returnIdx: Local(4),
            expectLocals: [
                4: ["foo": "bar", "key": "prev_value"]
            ]
        ),
        TestCase(
            description: "second insert with different values fails",
            stmt: IR.ObjectInsertOnceStatement(
                key: IR.Operand(type: .local, value: .localIndex(2)),
                value: IR.Operand(type: .local, value: .localIndex(3)),
                object: IR.Local(4)
            ),
            locals: [
                2: "key",
                3: "new_value",
                4: ["key": "prev_value"],
            ],
            expectError: true
        ),
        TestCase(
            description: "target is not an object",
            stmt: IR.ObjectInsertOnceStatement(
                key: IR.Operand(type: .local, value: .localIndex(2)),
                value: IR.Operand(type: .local, value: .localIndex(3)),
                object: IR.Local(4)
            ),
            locals: [
                2: "key",
                3: "new_value",
                4: "target: not an object",
            ],
            expectError: true
        ),
        TestCase(
            description: "key is undefined",
            stmt: IR.ObjectInsertOnceStatement(
                key: IR.Operand(type: .local, value: .localIndex(2)),
                value: IR.Operand(type: .local, value: .localIndex(3)),
                object: IR.Local(4)
            ),
            locals: [
                3: "new_value",
                4: [:],
            ],
            returnIdx: Local(4),
            expectError: false,
            expectResult: ResultSet.empty
        ),
        TestCase(
            description: "value is undefined",
            stmt: IR.ObjectInsertOnceStatement(
                key: IR.Operand(type: .local, value: .localIndex(2)),
                value: IR.Operand(type: .local, value: .localIndex(3)),
                object: IR.Local(4)
            ),
            locals: [
                2: "key",
                4: [:],
            ],
            returnIdx: Local(4),
            expectError: false,
            expectResult: ResultSet.empty
        ),
    ]

    @Test(arguments: allTests)
    func testStatmentEvaluation(tc: TestCase) async throws {
        // TODO - maybe add a ResultSetAdd always? and check for that?
        let (ctx, frame) = prepareFrame(forStatement: tc.stmt, withLocals: tc.locals, andReturn: tc.returnIdx)
        let result = await Result {
            try await evalFrame(withContext: ctx, framePtr: frame)
        }

        guard !tc.expectError else {
            #expect(throws: (any Error).self) {
                try result.get()
            }
            return
        }

        #expect(throws: Never.self) {
            try result.get()
        }
        let results = try! result.get()

        // Check local expectations
        let scope = try frame.v.currentScope()
        let expectLocals = mergeLocals(tc.locals, tc.expectLocals)
        #expect(scope.v.locals == expectLocals, "comparing locals")

        // Check result expectations
        // If the test case doesn't explicitly say which results to expect, and
        // it does specity a return idx, expect that local.
        var expectResult: ResultSet
        if tc.expectResult == nil && tc.returnIdx != nil {
            expectResult = ResultSet()
            expectResult.insert(frame.v.resolveLocal(idx: tc.returnIdx!))
        } else {
            expectResult = tc.expectResult ?? .empty
        }

        #expect(results == expectResult, "comparing results")
    }
}

extension IREvaluatorTests.TestCase: CustomTestStringConvertible {
    var testDescription: String { description }
}

extension IRStatementTests.TestCase: CustomTestStringConvertible {
    var testDescription: String {
        let mirror = Mirror(reflecting: self.stmt)
        return "\(mirror.subjectType): \(description)"
    }
}
