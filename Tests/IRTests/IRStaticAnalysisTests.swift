import Foundation
import Testing

@testable import IR

@Suite("IRRenumberingTests")
struct IRRenumberingTests {

    struct TestCase {
        var name: String
        var policy: Policy
        var result: Policy
    }

    static let testcases = [
        TestCase(
            name: "simple correct",
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
                ),
                plans: Plans(
                    plans: [
                        Plan(
                            name: "policy/hello",
                            blocks: [
                                Block(
                                    statements: [
                                        .callStmt(
                                            CallStatement(
                                                location: Location(row: 0, col: 8, file: 9),
                                                callFunc: "g0.data.policy.hello",
                                                args: [
                                                    Operand(
                                                        type: .local,
                                                        value: .localIndex(0)
                                                    ),
                                                    Operand(
                                                        type: .local,
                                                        value: .localIndex(1)
                                                    ),
                                                ],
                                                result: 2
                                            )),
                                        .assignVarStmt(
                                            AssignVarStatement(
                                                location: Location(row: 1, col: 2, file: 3),
                                                source: Operand(
                                                    type: .local,
                                                    value: .localIndex(2)
                                                ),
                                                target: Local(3)
                                            )),
                                        .makeObjectStmt(
                                            MakeObjectStatement(
                                                location: Location(row: 0, col: 0, file: 0),
                                                target: Local(2000)
                                            )),
                                        .objectInsertStmt(
                                            ObjectInsertStatement(
                                                location: Location(row: 0, col: 0, file: 0),
                                                key: Operand(
                                                    type: .stringIndex,
                                                    value: .stringIndex(0)
                                                ),
                                                value: Operand(
                                                    type: .local,
                                                    value: .localIndex(3)
                                                ),
                                                object: Local(2000)
                                            )),
                                        .resultSetAddStmt(
                                            ResultSetAddStatement(
                                                value: Local(2000)
                                            )),
                                    ]
                                )
                            ]
                        )
                    ]
                )
            ),
            result: Policy(
                staticData: Static(
                    strings: [
                        ConstString(value: "result"),
                        ConstString(value: "message"),
                        ConstString(value: "world"),
                    ],
                    files: [
                        ConstString(value: "example.rego")
                    ]
                ),
                plans: Plans(
                    plans: [
                        Plan(
                            name: "policy/hello",
                            blocks: [
                                Block(
                                    statements: [
                                        .callStmt(
                                            CallStatement(
                                                location: Location(row: 0, col: 8, file: 9),
                                                callFunc: "g0.data.policy.hello",
                                                args: [
                                                    Operand(
                                                        type: .local,
                                                        value: .localIndex(0)
                                                    ),
                                                    Operand(
                                                        type: .local,
                                                        value: .localIndex(1)
                                                    ),
                                                ],
                                                result: 2
                                            )),
                                        .assignVarStmt(
                                            AssignVarStatement(
                                                location: Location(row: 1, col: 2, file: 3),
                                                source: Operand(
                                                    type: .local,
                                                    value: .localIndex(2)
                                                ),
                                                target: Local(3)
                                            )),
                                        .makeObjectStmt(
                                            MakeObjectStatement(
                                                location: Location(row: 0, col: 0, file: 0),
                                                target: Local(4)
                                            )),
                                        .objectInsertStmt(
                                            ObjectInsertStatement(
                                                location: Location(row: 0, col: 0, file: 0),
                                                key: Operand(
                                                    type: .stringIndex,
                                                    value: .stringIndex(0)
                                                ),
                                                value: Operand(
                                                    type: .local,
                                                    value: .localIndex(3)
                                                ),
                                                object: Local(4)
                                            )),
                                        .resultSetAddStmt(
                                            ResultSetAddStatement(
                                                value: Local(4)
                                            )),
                                    ]
                                )
                            ]
                        )
                    ]
                )
            )
        )
    ]

    @Test(arguments: testcases)
    func testAll(tc: IRRenumberingTests.TestCase) async throws {
        var policy = tc.policy
        try policy.prepareForExecution()
        let _ = try zip(policy.plans!.plans, tc.result.plans!.plans).map({
            (x: Plan, y: Plan) throws in
            #expect(x.name == y.name)
            #expect(x.blocks == y.blocks)
        })
    }
}

extension IRRenumberingTests.TestCase: CustomTestStringConvertible {
    var testDescription: String { name }
}
