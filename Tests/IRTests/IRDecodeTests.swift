import Foundation
import Testing

@testable import IR

struct DecodeIRTestCase {
    var name: String
    var json: String
    var policy: Policy
}
extension DecodeIRTestCase: CustomTestStringConvertible {
    var testDescription: String { name }
}

@Test(arguments: [
    DecodeIRTestCase(
        name: "static simple",
        json: #"""
            {
              "static": {
                "strings": [
                  {
                    "value": "result"
                  },
                  {
                    "value": "message"
                  },
                  {
                    "value": "world"
                  }
                ],
                "files": [
                  {
                    "value": "example.rego"
                  }
                ]
              }
            }
            """#,
        policy: Policy(
            staticData: Static(
                strings: [
                    ConstString(value: "result"),
                    ConstString(value: "message"),
                    ConstString(value: "world"),
                ],
                files: [
                    ConstString(value: "example.rego")
                ]
            )
        )
    )
]) func decodeIR(tc: DecodeIRTestCase) throws {
    let actual = try JSONDecoder().decode(Policy.self, from: tc.json.data(using: .utf8)!)
    #expect(actual == tc.policy)
}

@Test("decodeIR Statements")
func decodeIRStatements() throws {
    for tc in [
        DecodeIRTestCase(
            name: "simple",
            json: #"""
                {"plans":{"plans":[{"name":"policy/hello","blocks":[{"stmts":[{"type":"CallStmt","stmt":{"func":"g0.data.policy.hello","args":[{"type":"local","value":0},{"type":"local","value":1}],"result":2,"file":9,"col":8,"row":0}},{"type":"AssignVarStmt","stmt":{"source":{"type":"local","value":2},"target":3,"file":3,"col":2,"row":1}},{"type":"MakeObjectStmt","stmt":{"target":4,"file":0,"col":0,"row":0}},{"type":"ObjectInsertStmt","stmt":{"key":{"type":"string_index","value":0},"value":{"type":"local","value":3},"object":4,"file":0,"col":0,"row":0}},{"type":"ResultSetAddStmt","stmt":{"value":4,"file":0,"col":0,"row":0}}]}]}]}}
                """#,
            policy: Policy(
                plans: Plans(
                    plans: [
                        Plan(
                            name: "policy/hello",
                            blocks: [
                                Block(
                                    statements: [
                                        CallStatement(
                                            location: Location(row: 0, col: 8, file: 9),
                                            callFunc: "g0.data.policy.hello",
                                            args: [
                                                Argument(
                                                    type: "local",
                                                    value: 0
                                                ),
                                                Argument(
                                                    type: "local",
                                                    value: 1
                                                ),
                                            ]
                                        ),
                                        AssignVarStatement(
                                            location: Location(row: 1, col: 2, file: 3),
                                            source: Operand(
                                                type: .local,
                                                value: .number(2)
                                            ),
                                            target: 3
                                        ),
                                        MakeObjectStatement(
                                            location: Location(row: 0, col: 0, file: 0),
                                            target: 4
                                        ),
                                        ObjectInsertStatement(
                                            location: Location(row: 0, col: 0, file: 0),
                                            key: Operand(
                                                type: .stringIndex,
                                                value: .stringIndex(0)
                                            ),
                                            value: Operand(
                                                type: .local,
                                                value: .number(3)
                                            ),
                                            object: 4
                                        ),
                                        ResultSetAddStatement(
                                            location: Location(row: 0, col: 0, file: 0),
                                            value: 4
                                        ),
                                    ]
                                )
                            ]
                        )
                    ]
                )
            )
        )
    ] {
        let actual = try JSONDecoder().decode(Policy.self, from: tc.json.data(using: .utf8)!)
        #expect(actual == tc.policy)
    }
}

enum ResultExpectation<Success, Failure> {
    case success(Success)
    case failure(Failure)
}

@Test("decodeIR Operands")
func decodeIROperands() throws {
    struct TestCase {
        var name: String?
        var json: String
        var expected: ResultExpectation<Operand, any (Error.Type)>
    }

    for tc in [
        TestCase(
            name: "simple local",
            json: #"""
                {
                    "type": "local",
                    "value": 7
                }
                """#,
            expected: .success(Operand(type: .local, value: .number(7)))
        ),
        TestCase(
            name: "simple bool",
            json: #"""
                {
                    "type": "bool",
                    "value": true
                }
                """#,
            expected: .success(Operand(type: .bool, value: .bool(true)))
        ),
        TestCase(
            name: "simple string_index",
            json: #"""
                {
                    "type": "string_index",
                    "value": 123
                }
                """#,
            expected: .success(Operand(type: .stringIndex, value: .stringIndex(123)))
        ),
        TestCase(
            name: "invalid type",
            json: #"""
                {
                    "type": "invalid!",
                    "value": 7
                }
                """#,
            expected: .failure(DecodingError.self)
        ),
        TestCase(
            name: "missing type",
            json: #"""
                {
                    "value": 7
                }
                """#,
            expected: .failure(DecodingError.self)
        ),
        TestCase(
            name: "missing value field",
            json: #"""
                {
                    "type": "local",
                }
                """#,
            expected: .failure(DecodingError.self)
        ),
    ] {
        let result: Result<Operand, Error> = Result {
            try JSONDecoder()
                .decode(Operand.self, from: tc.json.data(using: .utf8)!)
        }

        switch tc.expected {
        case .success(let expectedValue):
            #expect(throws: Never.self, commentFor(tc.name)) {
                // Check for unexpected exceptions separately (otherwise we can't customize the comment)
                try result.get()
            }
            // TODO! Check with the Xcode folks - we don't seem to get the fancy comparison stuff
            // for failures when we do #expect(try result.get() == expectedValue)
            guard let actual = try? result.get() else {
                return
            }
            #expect(actual == expectedValue, commentFor(tc.name))
        case .failure(let expectedErr):
            #expect(commentFor(tc.name)) { try result.get() } throws: { error in
                let mirror = Mirror(reflecting: error)
                let b: Bool = mirror.subjectType == expectedErr
                return b
            }
        }
    }
}

struct TestCaseCompareBlocks: Sendable {
    let name: String
    let lhs: Block
    let rhs: Block
    let expected: Bool
}
extension TestCaseCompareBlocks: CustomTestStringConvertible {
    var testDescription: String { name }
}

@Test(arguments: [
    TestCaseCompareBlocks(
        name: "equal",
        lhs: Block(
            statements: [
                CallStatement(
                    location: Location(row: 0, col: 1, file: 2),
                    callFunc: "myfunc",
                    args: [
                        Argument(
                            type: "something",
                            value: 0
                        )
                    ]
                ),
                AssignVarStatement(
                    source: Operand(
                        type: .local,
                        value: .number(123)
                    ),
                    target: 456
                ),
            ]
        ),
        rhs: Block(
            statements: [
                CallStatement(
                    location: Location(row: 0, col: 1, file: 2),
                    callFunc: "myfunc",
                    args: [
                        Argument(
                            type: "something",
                            value: 0
                        )
                    ]
                ),
                AssignVarStatement(
                    source: Operand(
                        type: .local,
                        value: .number(123)
                    ),
                    target: 456
                ),
            ]
        ),
        expected: true
    ),
    TestCaseCompareBlocks(
        name: "swapped not equal",
        lhs: Block(
            statements: [
                AssignVarStatement(
                    source: Operand(
                        type: .local,
                        value: .number(123)
                    ),
                    target: 456
                ),
                CallStatement(
                    location: Location(row: 0, col: 1, file: 2),
                    callFunc: "myfunc",
                    args: [
                        Argument(
                            type: "something",
                            value: 0
                        )
                    ]
                ),
            ]
        ),
        rhs: Block(
            statements: [
                CallStatement(
                    location: Location(row: 0, col: 1, file: 2),
                    callFunc: "myfunc",
                    args: [
                        Argument(
                            type: "something",
                            value: 0
                        )
                    ]
                ),
                AssignVarStatement(
                    source: Operand(
                        type: .local,
                        value: .number(123)
                    ),
                    target: 456
                ),
            ]
        ),
        expected: false
    ),
    TestCaseCompareBlocks(
        name: "slightly different",
        lhs: Block(
            statements: [
                CallStatement(
                    location: Location(row: 0, col: 1, file: 2),
                    callFunc: "myfunc",
                    args: [
                        Argument(
                            type: "something",
                            value: 0
                        )
                    ]
                ),
                AssignVarStatement(
                    source: Operand(
                        type: .local,
                        value: .number(123)
                    ),
                    target: 456
                ),
            ]
        ),
        rhs: Block(
            statements: [
                CallStatement(
                    location: Location(row: 0, col: 1, file: 2),
                    callFunc: "myfunc",
                    args: [
                        Argument(
                            type: "something else",
                            value: 0
                        )
                    ]
                ),
                AssignVarStatement(
                    source: Operand(
                        type: .local,
                        value: .number(123)
                    ),
                    target: 456
                ),
            ]
        ),
        expected: false
    ),
])
func compareBlocks(_ tc: TestCaseCompareBlocks) {
    if tc.expected {
        #expect(tc.lhs == tc.rhs)
    } else {
        #expect(tc.lhs != tc.rhs)
    }
}

@Test
func decodeFuncs() throws {
    let input = #"""
        {"funcs":{"funcs":[{"name":"g0.data.policy.hello","params":[0,1],"return":2,"blocks":[{"stmts":[{"type":"ResetLocalStmt","stmt":{"target":3,"file":0,"col":1,"row":7}},{"type":"DotStmt","stmt":{"source":{"type":"local","value":0},"key":{"type":"string_index","value":1},"target":4,"file":0,"col":10,"row":7}},{"type":"EqualStmt","stmt":{"a":{"type":"local","value":4},"b":{"type":"string_index","value":2},"file":0,"col":10,"row":7}},{"type":"AssignVarOnceStmt","stmt":{"source":{"type":"bool","value":true},"target":3,"file":0,"col":1,"row":7}}]},{"stmts":[{"type":"IsDefinedStmt","stmt":{"source":3,"file":0,"col":1,"row":7}},{"type":"AssignVarOnceStmt","stmt":{"source":{"type":"local","value":3},"target":2,"file":0,"col":1,"row":7}}]},{"stmts":[{"type":"IsUndefinedStmt","stmt":{"source":2,"file":0,"col":9,"row":5}},{"type":"AssignVarOnceStmt","stmt":{"source":{"type":"bool","value":false},"target":2,"file":0,"col":9,"row":5}}]},{"stmts":[{"type":"ReturnLocalStmt","stmt":{"source":2,"file":0,"col":9,"row":5}}]}],"path":["g0","policy","hello"]}]}}
        """#

    _ = try JSONDecoder().decode(Policy.self, from: input.data(using: .utf8)!)
}

func commentFor(_ name: String?) -> Comment {
    guard let name else {
        return Comment("[failed testcase: unnamed]")
    }
    return Comment(rawValue: "[failed testcase: \(name)]")
}
