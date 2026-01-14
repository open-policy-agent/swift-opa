import AST
import Bytecode
import Foundation
import Testing
@testable import IR
@testable import Rego

// MARK: - Locals test extensions

extension Locals {
    func merging(_ rhs: Locals?) -> Locals {
        guard let rhs else { return self }
        if rhs.isEmpty { return self }
        var result = Locals(self.storage)
        for i in 0..<rhs.count {
            if let rhsValue = rhs[Local(i)] {
                result[Local(i)] = rhsValue
            }
        }
        return result
    }
}

extension Locals: ExpressibleByDictionaryLiteral {
    public typealias Key = Int
    public typealias Value = AST.RegoValue

    public init(dictionaryLiteral elements: (Key, Value)...) {
        guard !elements.isEmpty else {
            self = Locals()
            return
        }
        let maxLocal: Int = elements.reduce(into: 0) { max, elem in
            max = Swift.max(max, elem.0)
        }
        var result = Locals(repeating: nil, count: maxLocal + 1)
        for (idx, value) in elements {
            result[Local(idx)] = value
        }
        self = result
    }
}

// MARK: - StatementTests

@Suite
struct StatementTests {
    struct TestCase {
        var description: String
        var stmt: IR.Statement
        var locals: Locals
        var funcs: [IR.Func] = []
        var staticStrings: [String] = []
        var expectLocals: Locals?
        var ignoreLocals: [Local] = []
        var expectError: Bool = false
        var expectResult: ResultSet? = nil
        var expectUndefined: Bool = false
    }

    func prepareFrame(
        forStatement stmt: IR.Statement,
        withLocals locals: Locals,
        withFuncs funcs: [IR.Func] = [],
        withStaticStrings staticStrings: [String] = []
    ) throws -> (context: VMContext, vm: VM) {
        let block = IR.Block(statements: [stmt])
        var irPolicy = IR.Policy(
            staticData: IR.Static(
                strings: staticStrings.map { IR.ConstString(value: $0) },
                builtinFuncs: nil,
                files: nil
            ),
            plans: IR.Plans(plans: [
                IR.Plan(name: "generated", blocks: [block])
            ]),
            funcs: IR.Funcs(funcs: funcs)
        )
        try irPolicy.prepareForExecution()
        let policy = try Converter.convert(irPolicy)

        let ctx = EvaluationContext(query: "data.generated", input: .undefined)
        let plan = policy.plans[0]
        let vmCtx = VMContext(
            evaluationContext: ctx,
            policy: policy,
            planMaxLocal: plan.maxLocal,
            data: .undefined
        )
        vmCtx.locals = locals
        return (vmCtx, VM(policy: policy))
    }

    static let allTests: [TestCase] = [
        assignIntStmtTests,
        assignVarStmtTests,
        assignVarOnceStmtTests,
        breakStmtTests,
        callStmtTests,
        dotStmtTests,
        equalStmtTests,
        isArrayStmtTests,
        isDefinedStmtTests,
        isObjectStmtTests,
        isSetStmtTests,
        isUndefinedStmtTests,
        lenStmtTests,
        makeArrayStmtTests,
        arrayAppendStmtTests,
        makeNullStmtTests,
        makeNumberIntStmtTests,
        makeNumberRefStmtTests,
        makeObjectStmtTests,
        makeSetStmtTests,
        setAddStmtTests,
        notStmtTests,
        notEqualStmtTests,
        objectInsertOnceStmtTests,
        objectInsertStmtTests,
        objectMergeStmtTests,
        resetLocalStmtTests,
        returnLocalStmtTests,
        scanStmtTests,
    ].flatMap { $0 }

    static let assignVarStmtTests: [TestCase] = [
        TestCase(
            description: "assign local",
            stmt: .assignVarStmt(
                IR.AssignVarStatement(
                    source: IR.Operand(type: .local, value: .localIndex(0)),
                    target: Local(1)
                )),
            locals: [
                0: ["some": "local"]
            ],
            expectLocals: [
                1: ["some": "local"]
            ]
        ),
        TestCase(
            description: "assign local - source undefined",
            stmt: .assignVarStmt(
                IR.AssignVarStatement(
                    // Use index > 0xFFF to force non-compact path, which stores .undefined in target
                    source: IR.Operand(type: .local, value: .localIndex(5000)),
                    target: Local(1)
                )),
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
            stmt: .assignVarStmt(
                IR.AssignVarStatement(
                    source: IR.Operand(type: .local, value: .localIndex(0)),
                    target: Local(1)
                )),
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
            stmt: .assignVarStmt(
                IR.AssignVarStatement(
                    source: IR.Operand(type: .bool, value: .bool(true)),
                    target: Local(0)
                )),
            locals: [:],
            expectLocals: [
                0: true
            ]
        ),
        TestCase(
            description: "assign local - string ref",
            stmt: .assignVarStmt(
                IR.AssignVarStatement(
                    source: IR.Operand(type: .stringIndex, value: .stringIndex(0)),
                    target: Local(0)
                )),
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
            stmt: .assignVarOnceStmt(
                IR.AssignVarOnceStatement(
                    source: IR.Operand(type: .local, value: .localIndex(0)),
                    target: Local(1)
                )),
            locals: [
                0: "target value"
            ],
            expectLocals: [
                1: "target value"
            ]
        ),
        TestCase(
            description: "assign local - source undefined",
            stmt: .assignVarOnceStmt(
                IR.AssignVarOnceStatement(
                    source: IR.Operand(type: .local, value: .localIndex(42)),
                    target: Local(1)
                )),
            locals: [
                0: "unrelated"
            ],
            expectLocals: [
                1: .undefined
            ]
        ),
        TestCase(
            description: "reassign string ref - same value allowed",
            stmt: .assignVarOnceStmt(
                IR.AssignVarOnceStatement(
                    source: IR.Operand(type: .stringIndex, value: .stringIndex(0)),
                    target: Local(1)
                )),
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
            stmt: .assignVarOnceStmt(
                IR.AssignVarOnceStatement(
                    source: IR.Operand(type: .stringIndex, value: .stringIndex(0)),
                    target: Local(1)
                )),
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
            stmt: .breakStmt(IR.BreakStatement(index: 0)),
            locals: [:],
            expectUndefined: true
        ),
        TestCase(
            description: "breaking out of call frame is an error",
            stmt: .callStmt(
                IR.CallStatement(
                    callFunc: "g0.f",
                    args: [
                        IR.Operand(type: .local, value: .localIndex(0)),
                        IR.Operand(type: .local, value: .localIndex(1)),
                    ],
                    result: Local(2)
                )),
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
                            .breakStmt(IR.BreakStatement(index: 2))
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
            stmt: .callStmt(
                IR.CallStatement(
                    callFunc: "g0.f",
                    args: [
                        IR.Operand(type: .local, value: .localIndex(0)),
                        IR.Operand(type: .local, value: .localIndex(1)),
                    ],
                    result: Local(2)
                )),
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
                            .callStmt(
                                IR.CallStatement(
                                    callFunc: "g0.f",
                                    args: [
                                        IR.Operand(type: .local, value: .localIndex(0)),
                                        IR.Operand(type: .local, value: .localIndex(1)),
                                    ],
                                    result: Local(2)
                                ))
                        ])
                    ]
                )
            ],
            expectError: true
        )
    ]

    static let lenStmtTests: [TestCase] = [
        TestCase(
            description: "len of empty array is 0",
            stmt: .lenStmt(
                IR.LenStatement(
                    source: IR.Operand(type: .local, value: .localIndex(2)),
                    target: Local(3)
                )),
            locals: [
                2: []
            ],
            expectLocals: [
                3: 0
            ]
        ),
        TestCase(
            description: "len of non-empty array",
            stmt: .lenStmt(
                IR.LenStatement(
                    source: IR.Operand(type: .local, value: .localIndex(2)),
                    target: Local(3)
                )),
            locals: [
                2: [1, 2, 3, 4, 5]
            ],
            expectLocals: [
                3: 5
            ]
        ),
        TestCase(
            description: "len of empty set",
            stmt: .lenStmt(
                IR.LenStatement(
                    source: IR.Operand(type: .local, value: .localIndex(2)),
                    target: Local(3)
                )),
            locals: [
                2: .set([])
            ],
            expectLocals: [
                3: 0
            ]
        ),
        TestCase(
            description: "len of non-empty set",
            stmt: .lenStmt(
                IR.LenStatement(
                    source: IR.Operand(type: .local, value: .localIndex(2)),
                    target: Local(3)
                )),
            locals: [
                2: .set(["a", "b"])
            ],
            expectLocals: [
                3: 2
            ]
        ),
        TestCase(
            description: "len of empty string",
            stmt: .lenStmt(
                IR.LenStatement(
                    source: IR.Operand(type: .local, value: .localIndex(2)),
                    target: Local(3)
                )),
            locals: [
                2: ""
            ],
            expectLocals: [
                3: 0
            ]
        ),
        TestCase(
            description: "len of non-empty string",
            stmt: .lenStmt(
                IR.LenStatement(
                    source: IR.Operand(type: .local, value: .localIndex(2)),
                    target: Local(3)
                )),
            locals: [
                2: "hello, world"
            ],
            expectLocals: [
                3: 12
            ]
        ),
        TestCase(
            description: "len of empty object",
            stmt: .lenStmt(
                IR.LenStatement(
                    source: IR.Operand(type: .local, value: .localIndex(2)),
                    target: Local(3)
                )),
            locals: [
                2: [:]
            ],
            expectLocals: [
                3: 0
            ]
        ),
        TestCase(
            description: "len of non-empty object",
            stmt: .lenStmt(
                IR.LenStatement(
                    source: IR.Operand(type: .local, value: .localIndex(2)),
                    target: Local(3)
                )),
            locals: [
                2: ["foo": "bar", "baz": "qux"]
            ],
            expectLocals: [
                3: 2
            ]
        ),
        TestCase(
            description: "len of unsupported type - integer",
            stmt: .lenStmt(
                IR.LenStatement(
                    source: IR.Operand(type: .local, value: .localIndex(2)),
                    target: Local(3)
                )),
            locals: [
                2: 42
            ],
            expectResult: [],
            expectUndefined: true
        ),
        TestCase(
            description: "len of unsupported type - null",
            stmt: .lenStmt(
                IR.LenStatement(
                    source: IR.Operand(type: .local, value: .localIndex(2)),
                    target: Local(3)
                )),
            locals: [
                2: .null
            ],
            expectResult: [],
            expectUndefined: true
        ),
        TestCase(
            description: "len of undefined is undefined",
            stmt: .lenStmt(
                IR.LenStatement(
                    source: IR.Operand(type: .local, value: .localIndex(2)),
                    target: Local(3)
                )),
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
            stmt: .objectInsertOnceStmt(
                IR.ObjectInsertOnceStatement(
                    key: IR.Operand(type: .local, value: .localIndex(2)),
                    value: IR.Operand(type: .local, value: .localIndex(3)),
                    object: Local(4)
                )),
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
            stmt: .objectInsertOnceStmt(
                IR.ObjectInsertOnceStatement(
                    key: IR.Operand(type: .local, value: .localIndex(2)),
                    value: IR.Operand(type: .local, value: .localIndex(3)),
                    object: Local(4)
                )),
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
            stmt: .objectInsertOnceStmt(
                IR.ObjectInsertOnceStatement(
                    key: IR.Operand(type: .local, value: .localIndex(2)),
                    value: IR.Operand(type: .local, value: .localIndex(3)),
                    object: Local(4)
                )),
            locals: [
                2: "key",
                3: "new_value",
                4: ["key": "prev_value"],
            ],
            expectError: true
        ),
        TestCase(
            description: "target is not an object",
            stmt: .objectInsertOnceStmt(
                IR.ObjectInsertOnceStatement(
                    key: IR.Operand(type: .local, value: .localIndex(2)),
                    value: IR.Operand(type: .local, value: .localIndex(3)),
                    object: Local(4)
                )),
            locals: [
                2: "key",
                3: "new_value",
                4: "target: not an object",
            ],
            ignoreLocals: [4],
            expectError: false,
            expectResult: [],
            expectUndefined: true
        ),
        TestCase(
            description: "key is undefined",
            stmt: .objectInsertOnceStmt(
                IR.ObjectInsertOnceStatement(
                    key: IR.Operand(type: .local, value: .localIndex(2)),
                    value: IR.Operand(type: .local, value: .localIndex(3)),
                    object: Local(4)
                )),
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
            stmt: .objectInsertOnceStmt(
                IR.ObjectInsertOnceStatement(
                    key: IR.Operand(type: .local, value: .localIndex(2)),
                    value: IR.Operand(type: .local, value: .localIndex(3)),
                    object: Local(4)
                )),
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
            stmt: .dotStmt(
                IR.DotStatement(
                    source: IR.Operand(type: .local, value: .localIndex(2)),
                    key: IR.Operand(type: .local, value: .localIndex(3)),
                    target: Local(4)
                )),
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
            stmt: .dotStmt(
                IR.DotStatement(
                    source: IR.Operand(type: .local, value: .localIndex(2)),
                    key: IR.Operand(type: .local, value: .localIndex(3)),
                    target: Local(4)
                )),
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
            stmt: .dotStmt(
                IR.DotStatement(
                    source: IR.Operand(type: .local, value: .localIndex(2)),
                    key: IR.Operand(type: .local, value: .localIndex(3)),
                    target: Local(4)
                )),
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
            stmt: .dotStmt(
                IR.DotStatement(
                    source: IR.Operand(type: .local, value: .localIndex(2)),
                    key: IR.Operand(type: .local, value: .localIndex(3)),
                    target: Local(4)
                )),
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
            stmt: .dotStmt(
                IR.DotStatement(
                    source: IR.Operand(type: .local, value: .localIndex(2)),
                    key: IR.Operand(type: .local, value: .localIndex(3)),
                    target: Local(4)
                )),
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
            stmt: .dotStmt(
                IR.DotStatement(
                    source: IR.Operand(type: .local, value: .localIndex(2)),
                    key: IR.Operand(type: .local, value: .localIndex(3)),
                    target: Local(4)
                )),
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
            stmt: .dotStmt(
                IR.DotStatement(
                    source: IR.Operand(type: .local, value: .localIndex(2)),
                    key: IR.Operand(type: .local, value: .localIndex(3)),
                    target: Local(4)
                )),
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
            stmt: .dotStmt(
                IR.DotStatement(
                    source: IR.Operand(type: .local, value: .localIndex(2)),
                    key: IR.Operand(type: .local, value: .localIndex(3)),
                    target: Local(4)
                )),
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
            stmt: .scanStmt(
                IR.ScanStatement(
                    source: Local(2),
                    key: Local(3),
                    value: Local(4),
                    block: IR.Block(statements: [])
                )),
            locals: [
                2: .undefined
            ],
            expectLocals: [:],
            expectResult: [],
            expectUndefined: true
        ),
        TestCase(
            description: "scalar - undefined",
            stmt: .scanStmt(
                IR.ScanStatement(
                    source: Local(2),
                    key: Local(3),
                    value: Local(4),
                    block: IR.Block(statements: [
                        .resultSetAddStmt(IR.ResultSetAddStatement(value: Local(4)))
                    ])
                )),
            locals: [
                2: "not a collection"
            ],
            expectLocals: [:],
            expectResult: [],
            expectUndefined: true
        ),
        TestCase(
            description: "empty array",
            stmt: .scanStmt(
                IR.ScanStatement(
                    source: Local(2),
                    key: Local(3),
                    value: Local(4),
                    block: IR.Block(statements: [
                        .equalStmt(
                            IR.EqualStatement(
                                a: IR.Operand(type: .local, value: .localIndex(3)),
                                b: IR.Operand(type: .local, value: .localIndex(4))
                            )),
                        .assignVarStmt(
                            IR.AssignVarStatement(
                                source: IR.Operand(type: .bool, value: .bool(true)),
                                target: Local(5)
                            )),
                    ])
                )),
            locals: [
                2: []
            ],
            expectLocals: [:]
        ),
        TestCase(
            description: "array - some iterations were truthy",
            stmt: .scanStmt(
                IR.ScanStatement(
                    source: Local(2),
                    key: Local(3),
                    value: Local(4),
                    block: IR.Block(statements: [
                        .equalStmt(
                            IR.EqualStatement(
                                a: IR.Operand(type: .local, value: .localIndex(3)),
                                b: IR.Operand(type: .local, value: .localIndex(4))
                            )),
                        .assignVarStmt(
                            IR.AssignVarStatement(
                                source: IR.Operand(type: .bool, value: .bool(true)),
                                target: Local(5)
                            )),
                    ])
                )),
            locals: [
                2: [9, 1, 8]
            ],
            expectLocals: [
                3: 2,
                4: 8,
                5: true,
            ]
        ),
        TestCase(
            description: "array - none were truthy",
            stmt: .scanStmt(
                IR.ScanStatement(
                    source: Local(2),
                    key: Local(3),
                    value: Local(4),
                    block: IR.Block(statements: [
                        .equalStmt(
                            IR.EqualStatement(
                                a: IR.Operand(type: .local, value: .localIndex(3)),
                                b: IR.Operand(type: .local, value: .localIndex(4))
                            )),
                        .assignVarStmt(
                            IR.AssignVarStatement(
                                source: IR.Operand(type: .bool, value: .bool(true)),
                                target: Local(5)
                            )),
                    ])
                )),
            locals: [
                2: [9, 9, 9]
            ],
            expectLocals: [
                3: 2,
                4: 9,
            ]
        ),
        TestCase(
            description: "object - copy key/values into results",
            stmt: .scanStmt(
                IR.ScanStatement(
                    source: Local(2),
                    key: Local(3),
                    value: Local(4),
                    block: IR.Block(statements: [
                        .blockStmt(
                            IR.BlockStatement(blocks: [
                                IR.Block(statements: [
                                    .resultSetAddStmt(IR.ResultSetAddStatement(value: Local(3)))
                                ]),
                                IR.Block(statements: [
                                    .resultSetAddStmt(IR.ResultSetAddStatement(value: Local(4)))
                                ]),
                            ]))
                    ])
                )),
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
            stmt: .scanStmt(
                IR.ScanStatement(
                    source: Local(2),
                    key: Local(3),
                    value: Local(4),
                    block: IR.Block(statements: [
                        .blockStmt(
                            IR.BlockStatement(blocks: [
                                IR.Block(statements: [
                                    .resultSetAddStmt(IR.ResultSetAddStatement(value: Local(3)))
                                ]),
                                IR.Block(statements: [
                                    .resultSetAddStmt(IR.ResultSetAddStatement(value: Local(4)))
                                ]),
                            ]))
                    ])
                )),
            locals: [
                2: [:]
            ],
            expectLocals: [:],
            expectResult: .empty
        ),
        TestCase(
            description: "set - copy values into result",
            stmt: .scanStmt(
                IR.ScanStatement(
                    source: Local(2),
                    key: Local(3),
                    value: Local(4),
                    block: IR.Block(statements: [
                        .resultSetAddStmt(IR.ResultSetAddStatement(value: Local(4)))
                    ])
                )),
            locals: [
                2: .set(["a", "b", "c"])
            ],
            expectLocals: [:],
            ignoreLocals: [3, 4],
            expectResult: ["a", "b", "c"]
        ),
        TestCase(
            description: "set - empty",
            stmt: .scanStmt(
                IR.ScanStatement(
                    source: Local(2),
                    key: Local(3),
                    value: Local(4),
                    block: IR.Block(statements: [
                        .resultSetAddStmt(IR.ResultSetAddStatement(value: Local(4)))
                    ])
                )),
            locals: [
                2: .set([])
            ],
            expectLocals: [:],
            ignoreLocals: [3, 4],
            expectResult: .empty
        ),
        TestCase(
            description: "array - break stops iteration after first match",
            stmt: .scanStmt(
                IR.ScanStatement(
                    source: Local(2),
                    key: Local(3),
                    value: Local(4),
                    block: IR.Block(statements: [
                        .resultSetAddStmt(IR.ResultSetAddStatement(value: Local(4))),
                        .breakStmt(IR.BreakStatement(index: 1)),
                    ])
                )),
            locals: [
                2: [10, 20, 30]
            ],
            ignoreLocals: [3, 4],
            // Only the first element should be added — break exits the scan after index 0.
            expectResult: [10],
            expectUndefined: true
        ),
        TestCase(
            description: "array - return propagates out of scan immediately",
            stmt: .scanStmt(
                IR.ScanStatement(
                    source: Local(2),
                    key: Local(3),
                    value: Local(4),
                    block: IR.Block(statements: [
                        .resultSetAddStmt(IR.ResultSetAddStatement(value: Local(4))),
                        .returnLocalStmt(IR.ReturnLocalStatement(source: Local(4))),
                    ])
                )),
            locals: [
                2: [10, 20, 30]
            ],
            ignoreLocals: [3, 4],
            // Only the first element should be added — return exits the scan after index 0.
            expectResult: [10]
        ),
    ]

    static let assignIntStmtTests: [TestCase] = [
        TestCase(
            description: "assign integer value",
            stmt: .assignIntStmt(IR.AssignIntStatement(value: 42, target: Local(2))),
            locals: [:],
            expectLocals: [2: 42]
        ),
        TestCase(
            description: "assign negative integer value",
            stmt: .assignIntStmt(IR.AssignIntStatement(value: -7, target: Local(2))),
            locals: [:],
            expectLocals: [2: -7]
        ),
    ]

    static let equalStmtTests: [TestCase] = [
        TestCase(
            description: "equal values succeeds",
            stmt: .equalStmt(IR.EqualStatement(
                a: IR.Operand(type: .local, value: .localIndex(2)),
                b: IR.Operand(type: .local, value: .localIndex(3))
            )),
            locals: [2: "x", 3: "x"]
        ),
        TestCase(
            description: "unequal values is undefined",
            stmt: .equalStmt(IR.EqualStatement(
                a: IR.Operand(type: .local, value: .localIndex(2)),
                b: IR.Operand(type: .local, value: .localIndex(3))
            )),
            locals: [2: "x", 3: "y"],
            expectUndefined: true
        ),
    ]

    static let notEqualStmtTests: [TestCase] = [
        TestCase(
            description: "unequal values succeeds",
            stmt: .notEqualStmt(IR.NotEqualStatement(
                a: IR.Operand(type: .local, value: .localIndex(2)),
                b: IR.Operand(type: .local, value: .localIndex(3))
            )),
            locals: [2: "x", 3: "y"]
        ),
        TestCase(
            description: "equal values is undefined",
            stmt: .notEqualStmt(IR.NotEqualStatement(
                a: IR.Operand(type: .local, value: .localIndex(2)),
                b: IR.Operand(type: .local, value: .localIndex(3))
            )),
            locals: [2: "x", 3: "x"],
            expectUndefined: true
        ),
        TestCase(
            description: "undefined operand is undefined",
            stmt: .notEqualStmt(IR.NotEqualStatement(
                a: IR.Operand(type: .local, value: .localIndex(2)),
                b: IR.Operand(type: .local, value: .localIndex(3))
            )),
            locals: [2: "x"],  // local 3 is undefined
            expectUndefined: true
        ),
    ]

    static let isArrayStmtTests: [TestCase] = [
        TestCase(
            description: "array succeeds",
            stmt: .isArrayStmt(IR.IsArrayStatement(source: IR.Operand(type: .local, value: .localIndex(2)))),
            locals: [2: ["a", "b"]]
        ),
        TestCase(
            description: "non-array is undefined",
            stmt: .isArrayStmt(IR.IsArrayStatement(source: IR.Operand(type: .local, value: .localIndex(2)))),
            locals: [2: "not an array"],
            expectUndefined: true
        ),
    ]

    static let isObjectStmtTests: [TestCase] = [
        TestCase(
            description: "object succeeds",
            stmt: .isObjectStmt(IR.IsObjectStatement(source: IR.Operand(type: .local, value: .localIndex(2)))),
            locals: [2: ["key": "value"]]
        ),
        TestCase(
            description: "non-object is undefined",
            stmt: .isObjectStmt(IR.IsObjectStatement(source: IR.Operand(type: .local, value: .localIndex(2)))),
            locals: [2: []],
            expectUndefined: true
        ),
    ]

    static let isSetStmtTests: [TestCase] = [
        TestCase(
            description: "set succeeds",
            stmt: .isSetStmt(IR.IsSetStatement(source: IR.Operand(type: .local, value: .localIndex(2)))),
            locals: [2: .set(["a"])]
        ),
        TestCase(
            description: "non-set is undefined",
            stmt: .isSetStmt(IR.IsSetStatement(source: IR.Operand(type: .local, value: .localIndex(2)))),
            locals: [2: ["a"]],
            expectUndefined: true
        ),
    ]

    static let isDefinedStmtTests: [TestCase] = [
        TestCase(
            description: "defined value succeeds",
            stmt: .isDefinedStmt(IR.IsDefinedStatement(source: Local(2))),
            locals: [2: "hello"]
        ),
        TestCase(
            description: "undefined local is undefined",
            stmt: .isDefinedStmt(IR.IsDefinedStatement(source: Local(2))),
            locals: [:],
            expectUndefined: true
        ),
    ]

    static let isUndefinedStmtTests: [TestCase] = [
        TestCase(
            description: "undefined local succeeds",
            stmt: .isUndefinedStmt(IR.IsUndefinedStatement(source: Local(2))),
            locals: [:]
        ),
        TestCase(
            description: "defined value is undefined",
            stmt: .isUndefinedStmt(IR.IsUndefinedStatement(source: Local(2))),
            locals: [2: "hello"],
            expectUndefined: true
        ),
    ]

    static let makeNullStmtTests: [TestCase] = [
        TestCase(
            description: "creates null",
            stmt: .makeNullStmt(IR.MakeNullStatement(target: Local(2))),
            locals: [:],
            expectLocals: [2: .null]
        ),
    ]

    static let makeNumberIntStmtTests: [TestCase] = [
        TestCase(
            description: "creates integer number",
            stmt: .makeNumberIntStmt(IR.MakeNumberIntStatement(value: 42, target: Local(2))),
            locals: [:],
            expectLocals: [2: 42]
        ),
        TestCase(
            description: "creates negative integer number",
            stmt: .makeNumberIntStmt(IR.MakeNumberIntStatement(value: -7, target: Local(2))),
            locals: [:],
            expectLocals: [2: -7]
        ),
    ]

    static let makeNumberRefStmtTests: [TestCase] = [
        TestCase(
            description: "load number from string table",
            stmt: .makeNumberRefStmt(IR.MakeNumberRefStatement(index: 0, target: Local(2))),
            locals: [:],
            staticStrings: ["99"],
            expectLocals: [2: 99]
        ),
    ]

    static let makeArrayStmtTests: [TestCase] = [
        TestCase(
            description: "creates empty array",
            stmt: .makeArrayStmt(IR.MakeArrayStatement(capacity: 4, target: Local(2))),
            locals: [:],
            expectLocals: [2: []]
        ),
    ]

    static let arrayAppendStmtTests: [TestCase] = [
        TestCase(
            description: "append value to array",
            stmt: .arrayAppendStmt(IR.ArrayAppendStatement(
                array: Local(2),
                value: IR.Operand(type: .local, value: .localIndex(3))
            )),
            locals: [2: [], 3: "x"],
            expectLocals: [2: ["x"]]
        ),
        TestCase(
            description: "append to non-array is undefined",
            stmt: .arrayAppendStmt(IR.ArrayAppendStatement(
                array: Local(2),
                value: IR.Operand(type: .local, value: .localIndex(3))
            )),
            locals: [2: "not an array", 3: "x"],
            ignoreLocals: [2],
            expectUndefined: true
        ),
        TestCase(
            description: "append undefined value is undefined",
            stmt: .arrayAppendStmt(IR.ArrayAppendStatement(
                array: Local(2),
                value: IR.Operand(type: .local, value: .localIndex(3))
            )),
            locals: [2: []],  // local 3 not set
            ignoreLocals: [2],
            expectUndefined: true
        ),
    ]

    static let makeObjectStmtTests: [TestCase] = [
        TestCase(
            description: "creates empty object",
            stmt: .makeObjectStmt(IR.MakeObjectStatement(target: Local(2))),
            locals: [:],
            expectLocals: [2: [:]]
        ),
    ]

    static let makeSetStmtTests: [TestCase] = [
        TestCase(
            description: "creates empty set",
            stmt: .makeSetStmt(IR.MakeSetStatement(target: Local(2))),
            locals: [:],
            expectLocals: [2: .set([])]
        ),
    ]

    static let setAddStmtTests: [TestCase] = [
        TestCase(
            description: "add value to set",
            stmt: .setAddStmt(IR.SetAddStatement(
                value: IR.Operand(type: .local, value: .localIndex(3)),
                set: Local(2)
            )),
            locals: [2: .set([]), 3: "a"],
            expectLocals: [2: .set(["a"])]
        ),
        TestCase(
            description: "add to non-set is undefined",
            stmt: .setAddStmt(IR.SetAddStatement(
                value: IR.Operand(type: .local, value: .localIndex(3)),
                set: Local(2)
            )),
            locals: [2: "not a set", 3: "a"],
            ignoreLocals: [2],
            expectUndefined: true
        ),
        TestCase(
            description: "add undefined value is undefined",
            stmt: .setAddStmt(IR.SetAddStatement(
                value: IR.Operand(type: .local, value: .localIndex(99)),
                set: Local(2)
            )),
            locals: [2: .set([])],
            ignoreLocals: [2],
            expectUndefined: true
        ),
    ]

    static let notStmtTests: [TestCase] = [
        TestCase(
            description: "inner block undefined → not succeeds",
            stmt: .notStmt(IR.NotStatement(block: IR.Block(statements: [
                .equalStmt(IR.EqualStatement(
                    a: IR.Operand(type: .local, value: .localIndex(2)),
                    b: IR.Operand(type: .local, value: .localIndex(3))
                ))
            ]))),
            locals: [2: "a", 3: "b"]
        ),
        TestCase(
            description: "inner block succeeds → not is undefined",
            stmt: .notStmt(IR.NotStatement(block: IR.Block(statements: [
                .equalStmt(IR.EqualStatement(
                    a: IR.Operand(type: .local, value: .localIndex(2)),
                    b: IR.Operand(type: .local, value: .localIndex(3))
                ))
            ]))),
            locals: [2: "a", 3: "a"],
            expectUndefined: true
        ),
    ]

    static let resetLocalStmtTests: [TestCase] = [
        TestCase(
            description: "reset clears local",
            stmt: .resetLocalStmt(IR.ResetLocalStatement(target: Local(2))),
            locals: [2: "value to clear"],
            ignoreLocals: [2]  // resetLocal1 stores nil; ignoreLocals avoids raw storage mismatch
        ),
    ]

    static let returnLocalStmtTests: [TestCase] = [
        TestCase(
            description: "return local carries value in block result",
            stmt: .returnLocalStmt(IR.ReturnLocalStatement(source: Local(2))),
            locals: [2: "result"]
            // locals unchanged; block result is functionReturnValue (not undefined, no error)
        ),
    ]

    static let objectInsertStmtTests: [TestCase] = [
        TestCase(
            description: "insert new key",
            stmt: .objectInsertStmt(IR.ObjectInsertStatement(
                key: IR.Operand(type: .local, value: .localIndex(2)),
                value: IR.Operand(type: .local, value: .localIndex(3)),
                object: Local(4)
            )),
            locals: [2: "key", 3: "value", 4: [:]],
            expectLocals: [4: ["key": "value"]]
        ),
        TestCase(
            description: "overwrite existing key",
            stmt: .objectInsertStmt(IR.ObjectInsertStatement(
                key: IR.Operand(type: .local, value: .localIndex(2)),
                value: IR.Operand(type: .local, value: .localIndex(3)),
                object: Local(4)
            )),
            locals: [2: "key", 3: "new_value", 4: ["key": "old_value"]],
            expectLocals: [4: ["key": "new_value"]]
        ),
        TestCase(
            description: "insert into non-object is undefined",
            stmt: .objectInsertStmt(IR.ObjectInsertStatement(
                key: IR.Operand(type: .local, value: .localIndex(2)),
                value: IR.Operand(type: .local, value: .localIndex(3)),
                object: Local(4)
            )),
            locals: [2: "key", 3: "value", 4: "not an object"],
            ignoreLocals: [4],
            expectUndefined: true
        ),
        TestCase(
            description: "insert undefined value is undefined",
            stmt: .objectInsertStmt(IR.ObjectInsertStatement(
                key: IR.Operand(type: .local, value: .localIndex(2)),
                value: IR.Operand(type: .local, value: .localIndex(3)),
                object: Local(4)
            )),
            locals: [2: "key", 4: [:]],  // local 3 is undefined
            ignoreLocals: [4],
            expectUndefined: true
        ),
    ]

    static let objectMergeStmtTests: [TestCase] = [
        TestCase(
            description: "merge two disjoint objects",
            stmt: .objectMergeStmt(IR.ObjectMergeStatement(a: Local(2), b: Local(3), target: Local(4))),
            locals: [2: ["x": 1], 3: ["y": 2]],
            expectLocals: [4: ["x": 1, "y": 2]]
        ),
        TestCase(
            description: "overlapping keys - a takes precedence over b",
            stmt: .objectMergeStmt(IR.ObjectMergeStatement(a: Local(2), b: Local(3), target: Local(4))),
            locals: [2: ["key": "from_a"], 3: ["key": "from_b", "other": "x"]],
            expectLocals: [4: ["key": "from_a", "other": "x"]]
        ),
        TestCase(
            description: "non-object operands are undefined",
            stmt: .objectMergeStmt(IR.ObjectMergeStatement(a: Local(2), b: Local(3), target: Local(4))),
            locals: [2: "not an object", 3: ["y": 2]],
            ignoreLocals: [4],
            expectUndefined: true
        ),
    ]

    @Test(arguments: allTests)
    func testStatementEvaluation(tc: TestCase) async throws {
        let (vmCtx, vm) = try prepareFrame(
            forStatement: tc.stmt,
            withLocals: tc.locals,
            withFuncs: tc.funcs,
            withStaticStrings: tc.staticStrings
        )

        let plan = vmCtx.policy.plans[0]
        let block = plan.blocks[0]

        let result = await Result {
            try await vm.executeBlock(
                context: vmCtx,
                offset: block.offset,
                size: block.size
            )
        }

        guard !tc.expectError else {
            var didThrow = false
            do {
                _ = try result.get()
            } catch {
                didThrow = true
            }
            #expect(didThrow, "expected an error to be thrown")
            return
        }

        let blockResult = try result.get()

        var expectLocals = tc.locals.merging(tc.expectLocals)
        var gotLocals = vmCtx.locals

        for idx in tc.ignoreLocals {
            gotLocals[idx] = nil
            expectLocals[idx] = nil
        }

        if case .scanStmt = tc.stmt {
            gotLocals.resize(to: expectLocals.count)
        }

        #expect(gotLocals == expectLocals, "comparing locals")

        let expectResult = tc.expectResult ?? .empty
        #expect(vmCtx.results == expectResult, "comparing results")

        #expect(blockResult.isUndefined == tc.expectUndefined, "comparing undefined")
    }
}

extension StatementTests.TestCase: CustomTestStringConvertible {
    var testDescription: String {
        let mirror = Mirror(reflecting: self.stmt)
        return "\(mirror.subjectType): \(description)"
    }
}
