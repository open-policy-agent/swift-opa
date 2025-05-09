import AST
import Foundation
import IR
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
        var engine = OPA.Engine(bundlePaths: tc.sourceBundles.map({ OPA.Engine.BundlePath(name: $0.lastPathComponent, url: $0) }))
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
        var engine = OPA.Engine(bundlePaths: tc.sourceBundles.map({ OPA.Engine.BundlePath(name: $0.lastPathComponent, url: $0) }))

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
        var funcs: [IR.Func] = []
        var staticStrings: [String] = []
        var expectLocals: Locals?
        // If provided, locals to ignore during comparison
        var ignoreLocals: [Local] = []
        // expectError, if true, means we expect the statement to throw and exception
        var expectError: Bool = false
        // expectResult - if an explicit value is set, we will compare that to the resultSet.
        var expectResult: ResultSet? = nil
        var expectUndefined: Bool = false
    }

    func mergeLocals(_ lhs: Locals, _ rhs: Locals?) -> Locals {
        guard let rhs else {
            return lhs
        }
        return lhs.merging(rhs) { (_, new) in new }
    }

    func prepareFrame(
        forStatement stmt: any Statement,
        withLocals locals: Locals,
        withFuncs funcs: [IR.Func] = [],
        withStaticStrings staticStrings: [String] = []
    )
        -> (IREvaluationContext, Ptr<Frame>)
    {
        let block = Block(statements: [stmt])

        let policy = IndexedIRPolicy(
            policy: IR.Policy(
                staticData: IR.Static(
                    strings: staticStrings.map { IR.ConstString(value: $0) }
                ),
                plans: Plans(
                    plans: [
                        Plan(name: "generated", blocks: [block])
                    ]
                ),
                funcs: IR.Funcs(funcs: funcs)
            ))
        let ctx = EvaluationContext(query: "", input: .undefined)
        let irCtx = IREvaluationContext(ctx: ctx, policy: policy)

        return (
            irCtx,
            Ptr(toCopyOf: Frame(locals: locals))
        )
    }

    static let allTests: [TestCase] = [
        assignVarStmtTests,
        assignVarOnceStmtTests,
        breakStmtTests,
        callStmtTests,
        dotStmtTests,
        lenStmtTests,
        objectInsertOnceStmtTests,
        scanStmtTests,
    ].flatMap { $0 }

    static let assignVarStmtTests: [TestCase] = [
        TestCase(
            description: "assign local",
            stmt: IR.AssignVarStatement(
                source: Operand(type: .local, value: .localIndex(0)),
                target: Local(1)
            ),
            locals: [
                0: ["some": "local"]
            ],
            expectLocals: [
                1: ["some": "local"]
            ]
        ),
        TestCase(
            description: "assign local - source undefined",
            stmt: IR.AssignVarStatement(
                source: Operand(type: .local, value: .localIndex(42)),
                target: Local(1)
            ),
            locals: [
                0: "unrelated",
                1: "will be overwritten",
            ],
            expectLocals: [
                1: .undefined
            ]
        ),
        TestCase(
            description: "assign local - overwrite",
            stmt: IR.AssignVarStatement(
                source: Operand(type: .local, value: .localIndex(0)),
                target: Local(1)
            ),
            locals: [
                0: ["a", "b", "c"],
                1: "will be overwritten",
            ],
            expectLocals: [
                1: ["a", "b", "c"]
            ]
        ),
        TestCase(
            description: "assign local - constant",
            stmt: IR.AssignVarStatement(
                source: Operand(type: .bool, value: .bool(true)),
                target: Local(0)
            ),
            locals: [:],
            expectLocals: [
                0: true
            ]
        ),
        TestCase(
            description: "assign local - string ref",
            stmt: IR.AssignVarStatement(
                source: Operand(type: .stringIndex, value: .stringIndex(0)),
                target: Local(0)
            ),
            locals: [:],
            staticStrings: ["hello, world"],
            expectLocals: [
                0: "hello, world"
            ]
        ),
    ]

    static let assignVarOnceStmtTests: [TestCase] = [
        TestCase(
            description: "initial assign local",
            stmt: IR.AssignVarOnceStatement(
                source: Operand(type: .local, value: .localIndex(0)),
                target: Local(1)
            ),
            locals: [
                0: "target value"
            ],
            expectLocals: [
                1: "target value"
            ]
        ),
        TestCase(
            description: "assign local - source undefined",
            stmt: IR.AssignVarOnceStatement(
                source: Operand(type: .local, value: .localIndex(42)),
                target: Local(1)
            ),
            locals: [
                0: "unrelated"
            ],
            expectLocals: [
                1: .undefined
            ]
        ),
        TestCase(
            description: "reassign string ref - same value allowed",
            stmt: IR.AssignVarOnceStatement(
                source: Operand(type: .stringIndex, value: .stringIndex(0)),
                target: Local(1)
            ),
            locals: [
                1: "will be overwritten"
            ],
            staticStrings: ["will be overwritten"],
            expectLocals: [
                1: "will be overwritten"
            ]
        ),
        TestCase(
            description: "reassign string ref - different value is an error",
            stmt: IR.AssignVarOnceStatement(
                source: Operand(type: .stringIndex, value: .stringIndex(0)),
                target: Local(1)
            ),
            locals: [
                1: "initial value"
            ],
            staticStrings: ["will trigger an error"],
            expectError: true
        ),
    ]

    static let breakStmtTests: [TestCase] = [
        TestCase(
            description: "break makes the block undefined",
            stmt: IR.BreakStatement(index: 0),
            locals: [:],
            expectUndefined: true
        ),
        TestCase(
            description: "breaking out of call frame is an error",
            stmt: IR.CallStatement(
                callFunc: "g0.f",
                args: [
                    Operand(type: .local, value: .localIndex(0)),
                    Operand(type: .local, value: .localIndex(1)),
                ],
                result: Local(2)
            ),
            locals: [:],
            funcs: [
                IR.Func(
                    name: "g0.f",
                    path: ["g0", "f"],
                    params: [
                        Local(0),
                        Local(1),
                    ],
                    returnVar: Local(2),
                    blocks: [
                        IR.Block(statements: [
                            IR.BreakStatement(index: 2)
                        ])
                    ]
                )
            ],
            expectError: true
        ),
    ]

    static let callStmtTests: [TestCase] = [
        TestCase(
            description: "infinite recursion",
            stmt: IR.CallStatement(
                callFunc: "g0.f",
                args: [
                    Operand(type: .local, value: .localIndex(0)),
                    Operand(type: .local, value: .localIndex(1)),
                ],
                result: Local(2)
            ),
            locals: [
                0: [:],
                1: [:],
            ],
            funcs: [
                IR.Func(
                    name: "g0.f",
                    path: ["g0", "f"],
                    params: [
                        Local(0),
                        Local(1),
                    ],
                    returnVar: Local(2),
                    blocks: [
                        IR.Block(statements: [
                            IR.CallStatement(
                                callFunc: "g0.f",
                                args: [
                                    Operand(type: .local, value: .localIndex(0)),
                                    Operand(type: .local, value: .localIndex(1)),
                                ],
                                result: Local(2)
                            )
                        ])
                    ]
                )
            ],
            expectError: true  // EvaluationError.maxCallDepthExceeded
        )
    ]

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
            expectResult: [],
            expectUndefined: true
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
            expectResult: [],
            expectUndefined: true
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
            expectResult: [],
            expectUndefined: true
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
            expectResult: [],
            expectUndefined: true
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
            expectResult: [],
            expectUndefined: true
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
            expectResult: [],
            expectUndefined: true
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
            expectResult: [],
            expectUndefined: true
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
            expectResult: [],
            expectUndefined: true
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
            expectResult: [],
            expectUndefined: true
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
            expectResult: [],
            expectUndefined: true
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
        let (ctx, frame) = prepareFrame(
            forStatement: tc.stmt,
            withLocals: tc.locals,
            withFuncs: tc.funcs,
            withStaticStrings: tc.staticStrings
        )
        let block = IR.Block(statements: [tc.stmt])

        let caller = IR.AnyStatement(IR.BlockStatement(blocks: [block]))
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

        #expect(results.isUndefined == tc.expectUndefined, "comparing undefined")
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
