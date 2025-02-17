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
        // If provided, expectLocals will be overlaid over locals and compared to the
        // state of the frame after evaluation.
        var expectLocals: Locals?
        // If provided, locals to ignore during comparison
        var ignoreLocals: [Local] = []
        // expectError, if true, means we expect the statement to throw and exception
        var expectError: Bool = false
        // expectResult - if an explicit value is set, we will compare that to the resultSet.
        var expectResult: ResultSet? = nil
    }

    func mergeLocals(_ lhs: Locals, _ rhs: Locals?) -> Locals {
        guard let rhs else {
            return lhs
        }
        return lhs.merging(rhs) { (_, new) in new }
    }

    func prepareFrame(forStatement stmt: any Statement, withLocals locals: Locals)
        -> (IREvaluationContext, Ptr<Frame>)
    {
        let block = Block(statements: [stmt])

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
        scanStmtTests,
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
            expectResult: .undefined
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
            expectError: false,
            expectResult: .undefined
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
            expectError: false,
            expectResult: .undefined
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
            ]
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
            expectResult: .undefined
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
            expectResult: .undefined
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
            ]
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
            expectResult: .undefined
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
            ]
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
            expectResult: .undefined
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
            expectResult: .undefined
        ),
    ]

    static let scanStmtTests: [TestCase] = [
        TestCase(
            description: "source undefined",
            stmt: IR.ScanStatement(
                source: Local(2),
                key: Local(3),
                value: Local(4),
                block: Block(statements: [])
            ),
            locals: [
                2: .undefined
            ],
            expectLocals: [:],
            expectResult: .undefined
        ),
        TestCase(
            description: "scalar - undefined",
            stmt: IR.ScanStatement(
                source: Local(2),
                key: Local(3),
                value: Local(4),
                block: Block(statements: [
                    // Copy value into resultset
                    ResultSetAddStatement(value: Local(4))
                ])
            ),
            locals: [
                // Can only scan collections
                2: "not a collection"
            ],
            expectLocals: [:],
            expectResult: .undefined
        ),
        TestCase(
            description: "empty array",
            stmt: IR.ScanStatement(
                source: Local(2),
                key: Local(3),
                value: Local(4),
                block: Block(statements: [
                    // if any (key == value)
                    EqualStatement(
                        a: IR.Operand(type: .local, value: .localIndex(3)),
                        b: IR.Operand(type: .local, value: .localIndex(4))
                    ),
                    AssignVarStatement(
                        source: IR.Operand(type: .bool, value: .bool(true)),
                        target: Local(5)
                    ),
                ])
            ),
            locals: [
                2: []
            ],
            expectLocals: [:]
        ),
        TestCase(
            description: "array - some iterations were truthy",
            stmt: IR.ScanStatement(
                source: Local(2),
                key: Local(3),
                value: Local(4),
                block: Block(statements: [
                    // if any (key == value)
                    EqualStatement(
                        a: IR.Operand(type: .local, value: .localIndex(3)),
                        b: IR.Operand(type: .local, value: .localIndex(4))
                    ),
                    AssignVarStatement(
                        source: IR.Operand(type: .bool, value: .bool(true)),
                        target: Local(5)
                    ),
                ])
            ),
            locals: [
                2: [9, 1, 8]
            ],
            expectLocals: [
                // key/value from the last iteration
                3: 2,
                4: 8,
                // The middle key/value pair were equal, so we set 5
                5: true,
            ]
        ),
        TestCase(
            description: "array - none were truthy",
            stmt: IR.ScanStatement(
                source: Local(2),
                key: Local(3),
                value: Local(4),
                block: Block(statements: [
                    // if any (key == value)
                    EqualStatement(
                        a: IR.Operand(type: .local, value: .localIndex(3)),
                        b: IR.Operand(type: .local, value: .localIndex(4))
                    ),
                    AssignVarStatement(
                        source: IR.Operand(type: .bool, value: .bool(true)),
                        target: Local(5)
                    ),
                ])
            ),
            locals: [
                2: [9, 9, 9]
            ],
            expectLocals: [
                // key/value from the last iteration
                3: 2,
                4: 9,
                    // none of the iterations were equal, so we never set 5
            ]
        ),
        TestCase(
            description: "object - copy key/values into results",
            stmt: IR.ScanStatement(
                source: Local(2),
                key: Local(3),
                value: Local(4),
                block: Block(statements: [
                    BlockStatement(blocks: [
                        Block(statements: [
                            // Copy key into resultset
                            ResultSetAddStatement(value: Local(3))
                        ]),
                        Block(statements: [
                            // Copy value into resultset
                            ResultSetAddStatement(value: Local(4))
                        ]),
                    ])
                ])
            ),
            locals: [
                2: [
                    "a": 1,
                    "b": 2,
                    "c": 3,
                ]
            ],
            expectLocals: [:],
            ignoreLocals: [3, 4],
            expectResult: ["a", "b", "c", 1, 2, 3]
        ),
        TestCase(
            description: "object - empty",
            stmt: IR.ScanStatement(
                source: Local(2),
                key: Local(3),
                value: Local(4),
                block: Block(statements: [
                    BlockStatement(blocks: [
                        Block(statements: [
                            // Copy key into resultset
                            ResultSetAddStatement(value: Local(3))
                        ]),
                        Block(statements: [
                            // Copy value into resultset
                            ResultSetAddStatement(value: Local(4))
                        ]),
                    ])
                ])
            ),
            locals: [
                // Empty object, so no iterations
                2: [:]
            ],
            expectLocals: [:],
            expectResult: .empty
        ),
        TestCase(
            description: "set - copy values into result",
            stmt: IR.ScanStatement(
                source: Local(2),
                key: Local(3),
                value: Local(4),
                block: Block(statements: [
                    // Copy value into resultset
                    ResultSetAddStatement(value: Local(4))
                ])
            ),
            locals: [
                // Empty set, so no iterations
                2: .set(["a", "b", "c"])
            ],
            expectLocals: [:],
            ignoreLocals: [3, 4],
            expectResult: ["a", "b", "c"]
        ),
        TestCase(
            description: "set - empty",
            stmt: IR.ScanStatement(
                source: Local(2),
                key: Local(3),
                value: Local(4),
                block: Block(statements: [
                    // Copy value into resultset
                    ResultSetAddStatement(value: Local(4))
                ])
            ),
            locals: [
                // Empty set, so no iterations
                2: .set([])
            ],
            expectLocals: [:],
            ignoreLocals: [3, 4],
            expectResult: .empty
        ),
    ]

    @Test(arguments: allTests)
    func testStatementEvaluation(tc: TestCase) async throws {
        let (ctx, frame) = prepareFrame(forStatement: tc.stmt, withLocals: tc.locals)
        let block = IR.Block(statements: [tc.stmt])

        let caller = IR.BlockStatement(blocks: [block])
        let result = await Result {
            try await evalBlock(withContext: ctx, framePtr: frame, caller: caller, block: block)
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
        let expectLocals = mergeLocals(tc.locals, tc.expectLocals)

        let scope = try frame.v.currentScope()
        var gotLocals = scope.v.locals
        for idx in tc.ignoreLocals {
            gotLocals[idx] = nil
        }
        #expect(gotLocals == expectLocals, "comparing locals")

        let expectResult = tc.expectResult ?? .empty

        #expect(results.results == expectResult, "comparing results")
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
