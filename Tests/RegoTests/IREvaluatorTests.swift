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
        var block = Block(statements: [stmt])

        // Synthesize building a resultset with the specified local
        if let returnIdx {
            let wrappedIdx = Local(7777)
            let returnBlock = Block(statements: [
                IR.MakeObjectStatement(target: wrappedIdx),
                IR.ObjectInsertStatement(
                    key: IR.Operand(type: .stringIndex, value: .stringIndex(0)),  // "results"
                    value: IR.Operand(type: .local, value: .localIndex(Int(returnIdx))),
                    object: wrappedIdx
                ),
                IR.ResultSetAddStatement(value: wrappedIdx),
            ])
            block.appendStatement(
                IR.BlockStatement(blocks: [returnBlock])
            )
        }

        let policy = IndexedIRPolicy(
            policy: IR.Policy(
                staticData: IR.Static(
                    strings: [
                        IR.ConstString(value: "results")
                    ]
                ),
                plans: Plans(
                    plans: [
                        Plan(name: "generated", blocks: [block])
                    ]
                ),
                funcs: nil
            ))
        let ctx = EvaluationContext(query: "", input: [:])
        let irCtx = IREvaluationContext(ctx: ctx, policy: policy)

        return (
            irCtx,
            Ptr(toCopyOf: Frame(locals: locals))
        )
    }

    static let allTests: [TestCase] = [
        dotStmtTests,
        lenStmtTests,
        objectInsertOnceStmtTests,
    ].flatMap { $0 }

    static let lenStmtTests: [TestCase] = [
        TestCase(
            description: "len of empty array is 0",
            stmt: IR.LenStatement(
                source: IR.Operand(type: .local, value: .localIndex(2)),
                target: Local(3)
            ),
            locals: [
                2: []
            ],
            returnIdx: Local(3),
            expectLocals: [
                3: 0
            ]
        ),
        TestCase(
            description: "len of non-empty array",
            stmt: IR.LenStatement(
                source: IR.Operand(type: .local, value: .localIndex(2)),
                target: Local(3)
            ),
            locals: [
                2: [1, 2, 3, 4, 5]
            ],
            returnIdx: Local(3),
            expectLocals: [
                3: 5
            ]
        ),
        TestCase(
            description: "len of empty set",
            stmt: IR.LenStatement(
                source: IR.Operand(type: .local, value: .localIndex(2)),
                target: Local(3)
            ),
            locals: [
                2: .set([])
            ],
            returnIdx: Local(3),
            expectLocals: [
                3: 0
            ]
        ),
        TestCase(
            description: "len of non-empty set",
            stmt: IR.LenStatement(
                source: IR.Operand(type: .local, value: .localIndex(2)),
                target: Local(3)
            ),
            locals: [
                2: .set([1, 2])
            ],
            returnIdx: Local(3),
            expectLocals: [
                3: 2
            ]
        ),
        TestCase(
            description: "len of empty string",
            stmt: IR.LenStatement(
                source: IR.Operand(type: .local, value: .localIndex(2)),
                target: Local(3)
            ),
            locals: [
                2: ""
            ],
            returnIdx: Local(3),
            expectLocals: [
                3: 0
            ]
        ),
        TestCase(
            description: "len of non-empty string",
            stmt: IR.LenStatement(
                source: IR.Operand(type: .local, value: .localIndex(2)),
                target: Local(3)
            ),
            locals: [
                2: "hello, world"
            ],
            returnIdx: Local(3),
            expectLocals: [
                3: 12
            ]
        ),
        TestCase(
            description: "len of empty object",
            stmt: IR.LenStatement(
                source: IR.Operand(type: .local, value: .localIndex(2)),
                target: Local(3)
            ),
            locals: [
                2: [:]
            ],
            returnIdx: Local(3),
            expectLocals: [
                3: 0
            ]
        ),
        TestCase(
            description: "len of non-empty object",
            stmt: IR.LenStatement(
                source: IR.Operand(type: .local, value: .localIndex(2)),
                target: Local(3)
            ),
            locals: [
                2: ["foo": "bar", "baz": "qux"]
            ],
            returnIdx: Local(3),
            expectLocals: [
                3: 2
            ]
        ),
        TestCase(
            description: "len of unsupported type - integer",
            stmt: IR.LenStatement(
                source: IR.Operand(type: .local, value: .localIndex(2)),
                target: Local(3)
            ),
            locals: [
                2: 42
            ],
            expectError: true
        ),
        TestCase(
            description: "len of unsupported type - null",
            stmt: IR.LenStatement(
                source: IR.Operand(type: .local, value: .localIndex(2)),
                target: Local(3)
            ),
            locals: [
                2: .null
            ],
            expectError: true
        ),
        TestCase(
            description: "len of undefined is undefined",
            stmt: IR.LenStatement(
                source: IR.Operand(type: .local, value: .localIndex(2)),
                target: Local(3)
            ),
            locals: [
                2: .undefined
            ],
            expectResult: .empty
        ),
    ]

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
    static let dotStmtTests: [TestCase] = [
        TestCase(
            description: "in-bounds array lookup",
            stmt: IR.DotStatement(
                source: IR.Operand(type: .local, value: .localIndex(2)),
                key: IR.Operand(type: .local, value: .localIndex(3)),
                target: Local(4)
            ),
            locals: [
                2: ["a", "b", "c"],
                3: 1,
            ],
            expectLocals: [
                4: "b"
            ],
            expectResult: .empty
        ),
        TestCase(
            description: "out-of-bounds array lookup is undefined",
            stmt: IR.DotStatement(
                source: IR.Operand(type: .local, value: .localIndex(2)),
                key: IR.Operand(type: .local, value: .localIndex(3)),
                target: Local(4)
            ),
            locals: [
                2: [0, 1, 2],
                3: 3,
            ],
            expectLocals: [:],
            expectResult: .empty
        ),
        TestCase(
            description: "negative out-of-bounds array lookup is undefined",
            stmt: IR.DotStatement(
                source: IR.Operand(type: .local, value: .localIndex(2)),
                key: IR.Operand(type: .local, value: .localIndex(3)),
                target: Local(4)
            ),
            locals: [
                2: [0, 1, 2],
                3: -1,
            ],
            expectLocals: [:],
            expectResult: .empty
        ),
        TestCase(
            description: "object lookup",
            stmt: IR.DotStatement(
                source: IR.Operand(type: .local, value: .localIndex(2)),
                key: IR.Operand(type: .local, value: .localIndex(3)),
                target: Local(4)
            ),
            locals: [
                2: ["a": "z"],
                3: "a",
            ],
            expectLocals: [
                4: "z"
            ],
            expectResult: .empty
        ),
        TestCase(
            description: "object lookup - key not found",
            stmt: IR.DotStatement(
                source: IR.Operand(type: .local, value: .localIndex(2)),
                key: IR.Operand(type: .local, value: .localIndex(3)),
                target: Local(4)
            ),
            locals: [
                2: ["a": "z"],
                3: "b",
            ],
            expectLocals: [:],
            expectResult: .empty
        ),
        TestCase(
            description: "set lookup",
            stmt: IR.DotStatement(
                source: IR.Operand(type: .local, value: .localIndex(2)),
                key: IR.Operand(type: .local, value: .localIndex(3)),
                target: Local(4)
            ),
            locals: [
                2: .set(["x", "y"]),
                3: "x",
            ],
            expectLocals: [
                4: "x"
            ],
            expectResult: .empty
        ),
        TestCase(
            description: "set lookup - not found",
            stmt: IR.DotStatement(
                source: IR.Operand(type: .local, value: .localIndex(2)),
                key: IR.Operand(type: .local, value: .localIndex(3)),
                target: Local(4)
            ),
            locals: [
                2: .set(["x", "y"]),
                3: "z",
            ],
            expectLocals: [:],
            expectResult: .empty
        ),
        TestCase(
            description: "unsupported type lookup - undefined",
            stmt: IR.DotStatement(
                source: IR.Operand(type: .local, value: .localIndex(2)),
                key: IR.Operand(type: .local, value: .localIndex(3)),
                target: Local(4)
            ),
            locals: [
                2: "double rainbow",
                3: "what does it mean??",
            ],
            expectLocals: [:],
            expectResult: .empty
        ),
    ]

    @Test(arguments: allTests)
    func testStatementEvaluation(tc: TestCase) async throws {
        // TODO - maybe add a ResultSetAdd always? and check for that?
        let (ctx, frame) = prepareFrame(forStatement: tc.stmt, withLocals: tc.locals, andReturn: tc.returnIdx)
        let blocks = ctx.policy.plans["generated"]?.blocks ?? []
        let stmt = IR.BlockStatement(blocks: blocks)
        let result = await Result {
            try await evalFrame(withContext: ctx, framePtr: frame, blocks: blocks, caller: stmt)
        }

        guard !tc.expectError else {
            #expect(throws: (any Error).self) {
                try result.get()
            }
            return
        }

        // Unwrap, ensuring no error was thrown
        let results = try result.get()

        // Check local expectations
        let scope = try frame.v.currentScope()
        let expectLocals = mergeLocals(tc.locals, tc.expectLocals)
        var gotLocals = scope.v.locals
        // Remove temporary local used for building ResultSet (see prepareFrame)
        gotLocals.removeValue(forKey: Local(7777))
        #expect(gotLocals == expectLocals, "comparing locals")

        // Check result expectations
        // If the test case doesn't explicitly say which results to expect, and
        // it does specity a return idx, expect that local.
        var expectResult: ResultSet
        if tc.expectResult == nil && tc.returnIdx != nil {
            expectResult = ResultSet()
            expectResult.insert(
                ["results": frame.v.resolveLocal(idx: tc.returnIdx!)]
            )
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
