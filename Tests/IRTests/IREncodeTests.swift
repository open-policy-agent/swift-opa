import AST
import Foundation
import Testing

@testable import IR

// EncodeTests verify that the IR types produce JSON in a format that
// our decoder can understand.

@Test("roundtrip Operand cases")
func roundtripOperand() throws {
    let cases: [Operand] = [
        Operand(type: .local, value: .localIndex(0)),
        Operand(type: .local, value: .localIndex(42)),
        Operand(type: .bool, value: .bool(true)),
        Operand(type: .bool, value: .bool(false)),
        Operand(type: .stringIndex, value: .stringIndex(17)),
    ]
    for op in cases {
        let data = try JSONEncoder().encode(op)
        let decoded = try JSONDecoder().decode(Operand.self, from: data)
        #expect(decoded == op)
    }
}

@Test("encoded Operand matches expected format")
func encodedOperandShape() throws {
    let op = Operand(type: .local, value: .localIndex(7))
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try encoder.encode(op)
    let asString = String(data: data, encoding: .utf8)
    #expect(asString == #"{"type":"local","value":7}"#)

    let strOp = Operand(type: .stringIndex, value: .stringIndex(3))
    let strData = try encoder.encode(strOp)
    #expect(String(data: strData, encoding: .utf8) == #"{"type":"string_index","value":3}"#)

    let boolOp = Operand(type: .bool, value: .bool(true))
    let boolData = try encoder.encode(boolOp)
    #expect(String(data: boolData, encoding: .utf8) == #"{"type":"bool","value":true}"#)
}

@Test("roundtrip Block with representative statements")
func roundtripBlock() throws {
    let block = Block(
        statements: [
            .callStmt(
                CallStatement(
                    location: Location(row: 49, col: 10, file: 50),
                    callFunc: "plus",
                    args: [
                        Operand(type: .local, value: .localIndex(6)),
                        Operand(type: .local, value: .localIndex(7)),
                    ],
                    result: Local(8)
                )),
            .assignVarStmt(
                AssignVarStatement(
                    location: Location(row: 1, col: 2, file: 3),
                    source: Operand(type: .local, value: .localIndex(2)),
                    target: Local(3)
                )),
            .makeObjectStmt(
                MakeObjectStatement(
                    location: Location(row: 4, col: 5, file: 6),
                    target: Local(4)
                )),
            .objectInsertStmt(
                ObjectInsertStatement(
                    location: Location(row: 7, col: 8, file: 9),
                    key: Operand(type: .stringIndex, value: .stringIndex(0)),
                    value: Operand(type: .local, value: .localIndex(3)),
                    object: Local(4)
                )),
            .resultSetAddStmt(ResultSetAddStatement(value: Local(4))),
            // nop exercises the empty-body statement case
            .nopStmt(NopStatement()),
        ]
    )

    let encoded = try JSONEncoder().encode(block)
    let decoded = try JSONDecoder().decode(Block.self, from: encoded)
    #expect(decoded == block)
}

@Test("roundtrip Block with nested blocks (not/with/scan)")
func roundtripBlockNested() throws {
    let inner = Block(
        statements: [
            .assignVarOnceStmt(
                AssignVarOnceStatement(
                    location: Location(row: 30, col: 1, file: 0),
                    source: Operand(type: .local, value: .localIndex(19)),
                    target: Local(3)
                ))
        ]
    )

    let block = Block(
        statements: [
            .withStmt(
                WithStatement(
                    location: Location(row: 31, col: 9, file: 0),
                    local: Local(0),
                    path: [1, 2],
                    value: Operand(type: .local, value: .localIndex(8)),
                    block: inner
                )),
            .notStmt(
                NotStatement(
                    location: Location(row: 40, col: 2, file: 0),
                    block: inner
                )),
            .scanStmt(
                ScanStatement(
                    source: Local(1),
                    key: Local(2),
                    value: Local(3),
                    block: inner
                )),
        ]
    )

    let encoded = try JSONEncoder().encode(block)
    let decoded = try JSONDecoder().decode(Block.self, from: encoded)
    #expect(decoded == block)
}

@Test("Statement.unknown fails to encode")
func encodeUnknownFails() {
    let block = Block(statements: [.unknown(Location(row: 0, col: 0, file: 0))])
    #expect(throws: EncodingError.self) {
        _ = try JSONEncoder().encode(block)
    }
}

@Test("roundtrip full Policy with plan and funcs")
func roundtripPolicy() throws {
    let policy = Policy(
        staticData: Static(
            strings: [
                ConstString(value: "result"),
                ConstString(value: "message"),
            ],
            files: [ConstString(value: "example.rego")]
        ),
        plans: Plans(
            plans: [
                Plan(
                    name: "policy/hello",
                    blocks: [
                        Block(statements: [
                            .callStmt(
                                CallStatement(
                                    location: Location(row: 0, col: 8, file: 9),
                                    callFunc: "g0.data.policy.hello",
                                    args: [
                                        Operand(type: .local, value: .localIndex(0)),
                                        Operand(type: .local, value: .localIndex(1)),
                                    ],
                                    result: Local(2)
                                )),
                            .resultSetAddStmt(ResultSetAddStatement(value: Local(4))),
                        ])
                    ]
                )
            ]
        ),
        funcs: Funcs(
            funcs: [
                Func(
                    name: "g0.data.policy.hello",
                    path: ["g0", "policy", "hello"],
                    params: [Local(0), Local(1)],
                    returnVar: Local(2),
                    blocks: [
                        Block(statements: [
                            .returnLocalStmt(
                                ReturnLocalStatement(
                                    location: Location(row: 5, col: 9, file: 0),
                                    source: Local(2)
                                ))
                        ])
                    ]
                )
            ]
        )
    )

    let encoded = try JSONEncoder().encode(policy)
    let decoded = try JSONDecoder().decode(Policy.self, from: encoded)
    #expect(decoded == policy)
}
