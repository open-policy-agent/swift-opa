import AST
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

    // Helpers to keep the cases concise.
    private static func op(_ idx: Int) -> Operand {
        Operand(type: .local, value: .localIndex(idx))
    }
    private static func strOp(_ idx: Int) -> Operand {
        Operand(type: .stringIndex, value: .stringIndex(idx))
    }
    private static func plan(_ name: String, _ stmts: [Statement]) -> Plan {
        Plan(name: name, blocks: [Block(statements: stmts)])
    }
    private static func fn(
        _ name: String,
        params: [Local],
        returnVar: Local,
        _ stmts: [Statement]
    ) -> Func {
        Func(
            name: name, path: name.split(separator: "/").map(String.init), params: params, returnVar: returnVar,
            blocks: [Block(statements: stmts)])
    }
    private static func staticData(strings: Int = 0, files: Int = 1) -> Static {
        Static(
            strings: (0..<strings).map { ConstString(value: "s\($0)") },
            files: (0..<files).map { ConstString(value: "f\($0).rego") }
        )
    }

    static let testcases: [TestCase] = [
        // Original case: a sparse Local(2000) is compacted down to Local(4).
        TestCase(
            name: "simple correct",
            policy: Policy(
                staticData: staticData(strings: 3),
                plans: Plans(plans: [
                    plan(
                        "policy/hello",
                        [
                            .callStmt(
                                CallStatement(
                                    location: Location(row: 0, col: 8, file: 9),
                                    callFunc: "g0.data.policy.hello",
                                    args: [op(0), op(1)],
                                    result: Local(2)
                                )),
                            .assignVarStmt(
                                AssignVarStatement(
                                    location: Location(row: 1, col: 2, file: 3),
                                    source: op(2),
                                    target: Local(3)
                                )),
                            .makeObjectStmt(MakeObjectStatement(target: Local(2000))),
                            .objectInsertStmt(
                                ObjectInsertStatement(
                                    key: strOp(0),
                                    value: op(3),
                                    object: Local(2000)
                                )),
                            .resultSetAddStmt(ResultSetAddStatement(value: Local(2000))),
                        ])
                ])
            ),
            result: Policy(
                staticData: staticData(strings: 3),
                plans: Plans(plans: [
                    plan(
                        "policy/hello",
                        [
                            .callStmt(
                                CallStatement(
                                    location: Location(row: 0, col: 8, file: 9),
                                    callFunc: "g0.data.policy.hello",
                                    args: [op(0), op(1)],
                                    result: Local(2)
                                )),
                            .assignVarStmt(
                                AssignVarStatement(
                                    location: Location(row: 1, col: 2, file: 3),
                                    source: op(2),
                                    target: Local(3)
                                )),
                            .makeObjectStmt(MakeObjectStatement(target: Local(4))),
                            .objectInsertStmt(
                                ObjectInsertStatement(
                                    key: strOp(0),
                                    value: op(3),
                                    object: Local(4)
                                )),
                            .resultSetAddStmt(ResultSetAddStatement(value: Local(4))),
                        ])
                ])
            )
        ),

        // Already-compact plan: pass should be a no-op.
        TestCase(
            name: "no-op identity for already-compact plan",
            policy: Policy(
                staticData: staticData(),
                plans: Plans(plans: [
                    plan(
                        "policy/identity",
                        [
                            .makeObjectStmt(MakeObjectStatement(target: Local(2))),
                            .assignVarStmt(
                                AssignVarStatement(source: op(2), target: Local(3))
                            ),
                            .resultSetAddStmt(ResultSetAddStatement(value: Local(3))),
                        ])
                ])
            ),
            result: Policy(
                staticData: staticData(),
                plans: Plans(plans: [
                    plan(
                        "policy/identity",
                        [
                            .makeObjectStmt(MakeObjectStatement(target: Local(2))),
                            .assignVarStmt(
                                AssignVarStatement(source: op(2), target: Local(3))
                            ),
                            .resultSetAddStmt(ResultSetAddStatement(value: Local(3))),
                        ])
                ])
            )
        ),

        // Multiple sparse locals are compacted in sorted order, preserving relative
        // order and packing into [2, 3, 4] after the reserved input/data slots.
        TestCase(
            name: "multiple sparse locals compact in sorted order",
            policy: Policy(
                staticData: staticData(),
                plans: Plans(plans: [
                    plan(
                        "policy/sparse",
                        [
                            .makeObjectStmt(MakeObjectStatement(target: Local(50))),
                            .makeObjectStmt(MakeObjectStatement(target: Local(100))),
                            .assignVarStmt(
                                AssignVarStatement(source: op(50), target: Local(200))
                            ),
                            .resultSetAddStmt(ResultSetAddStatement(value: Local(100))),
                        ])
                ])
            ),
            result: Policy(
                staticData: staticData(),
                plans: Plans(plans: [
                    plan(
                        "policy/sparse",
                        [
                            .makeObjectStmt(MakeObjectStatement(target: Local(2))),
                            .makeObjectStmt(MakeObjectStatement(target: Local(3))),
                            .assignVarStmt(
                                AssignVarStatement(source: op(2), target: Local(4))
                            ),
                            .resultSetAddStmt(ResultSetAddStatement(value: Local(3))),
                        ])
                ])
            )
        ),

        // Renumbering walks into nested blocks (scan body, with body, not body).
        TestCase(
            name: "nested blocks: scan/with/not bodies are renumbered",
            policy: Policy(
                staticData: staticData(strings: 1),
                plans: Plans(plans: [
                    plan(
                        "policy/nested",
                        [
                            .makeObjectStmt(MakeObjectStatement(target: Local(500))),
                            .scanStmt(
                                ScanStatement(
                                    source: Local(500),
                                    key: Local(501),
                                    value: Local(502),
                                    block: Block(statements: [
                                        .objectInsertStmt(
                                            ObjectInsertStatement(
                                                key: op(501),
                                                value: op(502),
                                                object: Local(500)
                                            ))
                                    ])
                                )),
                            .resultSetAddStmt(ResultSetAddStatement(value: Local(500))),
                        ])
                ])
            ),
            result: Policy(
                staticData: staticData(strings: 1),
                plans: Plans(plans: [
                    plan(
                        "policy/nested",
                        [
                            .makeObjectStmt(MakeObjectStatement(target: Local(2))),
                            .scanStmt(
                                ScanStatement(
                                    source: Local(2),
                                    key: Local(3),
                                    value: Local(4),
                                    block: Block(statements: [
                                        .objectInsertStmt(
                                            ObjectInsertStatement(
                                                key: op(3),
                                                value: op(4),
                                                object: Local(2)
                                            ))
                                    ])
                                )),
                            .resultSetAddStmt(ResultSetAddStatement(value: Local(2))),
                        ])
                ])
            )
        ),

        // Func with conventional params [0,1] / returnVar 2 keeps its interface
        // and compacts other locals around it.
        TestCase(
            name: "func compacts non-reserved locals; preserves params/returnVar",
            policy: Policy(
                staticData: staticData(strings: 2),
                funcs: Funcs(funcs: [
                    fn(
                        "g0/hello", params: [Local(0), Local(1)], returnVar: Local(2),
                        [
                            .resetLocalStmt(ResetLocalStatement(target: Local(99))),
                            .makeNumberRefStmt(MakeNumberRefStatement(index: 1, target: Local(100))),
                            .assignVarOnceStmt(
                                AssignVarOnceStatement(source: op(100), target: Local(99))
                            ),
                            .isDefinedStmt(IsDefinedStatement(source: Local(99))),
                            .assignVarOnceStmt(
                                AssignVarOnceStatement(source: op(99), target: Local(2))
                            ),
                            .returnLocalStmt(ReturnLocalStatement(source: Local(2))),
                        ])
                ])
            ),
            result: Policy(
                staticData: staticData(strings: 2),
                funcs: Funcs(funcs: [
                    fn(
                        "g0/hello", params: [Local(0), Local(1)], returnVar: Local(2),
                        [
                            .resetLocalStmt(ResetLocalStatement(target: Local(3))),
                            .makeNumberRefStmt(MakeNumberRefStatement(index: 1, target: Local(4))),
                            .assignVarOnceStmt(
                                AssignVarOnceStatement(source: op(4), target: Local(3))
                            ),
                            .isDefinedStmt(IsDefinedStatement(source: Local(3))),
                            .assignVarOnceStmt(
                                AssignVarOnceStatement(source: op(3), target: Local(2))
                            ),
                            .returnLocalStmt(ReturnLocalStatement(source: Local(2))),
                        ])
                ])
            )
        ),

        // Func with unconventional params: reserved indices are preserved,
        // other locals fill the lowest non-reserved indices.
        TestCase(
            name: "func with unconventional params: reserved indices preserved",
            policy: Policy(
                staticData: staticData(),
                funcs: Funcs(funcs: [
                    fn(
                        "g0/oddparams", params: [Local(3), Local(5)], returnVar: Local(7),
                        [
                            .makeObjectStmt(MakeObjectStatement(target: Local(20))),
                            .assignVarOnceStmt(
                                AssignVarOnceStatement(source: op(20), target: Local(7))
                            ),
                            .returnLocalStmt(ReturnLocalStatement(source: Local(7))),
                        ])
                ])
            ),
            // Reserved = {3, 5, 7}.  Other locals (just 20) fill the lowest
            // non-reserved slot, which is 0.
            result: Policy(
                staticData: staticData(),
                funcs: Funcs(funcs: [
                    fn(
                        "g0/oddparams", params: [Local(3), Local(5)], returnVar: Local(7),
                        [
                            .makeObjectStmt(MakeObjectStatement(target: Local(0))),
                            .assignVarOnceStmt(
                                AssignVarOnceStatement(source: op(0), target: Local(7))
                            ),
                            .returnLocalStmt(ReturnLocalStatement(source: Local(7))),
                        ])
                ])
            )
        ),
    ]

    @Test(arguments: testcases)
    func testRenumber(tc: IRRenumberingTests.TestCase) async throws {
        var policy = tc.policy
        try policy.prepareForExecution()

        let gotPlans = policy.plans?.plans ?? []
        let wantPlans = tc.result.plans?.plans ?? []
        #expect(gotPlans.count == wantPlans.count, "plan count")
        for (got, want) in zip(gotPlans, wantPlans) {
            #expect(got.name == want.name)
            #expect(got.blocks == want.blocks, "plan '\(want.name)' blocks differ")
        }

        let gotFuncs = policy.funcs?.funcs ?? []
        let wantFuncs = tc.result.funcs?.funcs ?? []
        #expect(gotFuncs.count == wantFuncs.count, "func count")
        for (got, want) in zip(gotFuncs, wantFuncs) {
            #expect(got.name == want.name)
            #expect(got.params == want.params, "func '\(want.name)' params differ")
            #expect(got.returnVar == want.returnVar, "func '\(want.name)' returnVar differs")
            #expect(got.blocks == want.blocks, "func '\(want.name)' blocks differ")
        }
    }

    // The renumbering pass should be idempotent across runs.
    @Test(arguments: testcases)
    func testIdempotent(tc: IRRenumberingTests.TestCase) async throws {
        var once = tc.policy
        try once.prepareForExecution()

        var twice = tc.policy
        try twice.prepareForExecution()
        try twice.prepareForExecution()

        let oncePlans = once.plans?.plans ?? []
        let twicePlans = twice.plans?.plans ?? []
        for (a, b) in zip(oncePlans, twicePlans) {
            #expect(a.blocks == b.blocks, "plan '\(a.name)' diverged after second pass")
        }

        let onceFuncs = once.funcs?.funcs ?? []
        let twiceFuncs = twice.funcs?.funcs ?? []
        for (a, b) in zip(onceFuncs, twiceFuncs) {
            #expect(a.blocks == b.blocks, "func '\(a.name)' diverged after second pass")
            #expect(a.params == b.params, "func '\(a.name)' params diverged after second pass")
            #expect(a.returnVar == b.returnVar, "func '\(a.name)' returnVar diverged after second pass")
        }
    }

    // Decode an OPA-compiled plan from JSON and verify the renumbering pass
    // leaves an already-compact, real-world policy unchanged.  This guards
    // against regressions where decoding + prepareForExecution might mangle
    // statements that don't need rewriting.
    @Test
    func testRealOPAPlanIsNoOp() async throws {
        let json = #"""
            {
              "static": {
                "strings": [{"value":"result"},{"value":"1"}],
                "files": [{"value":"bar.rego"}]
              },
              "plans": {"plans": [{"name":"foo/hello","blocks":[{"stmts":[
                {"type":"CallStmt","stmt":{"func":"g0.data.foo.hello","args":[{"type":"local","value":0},{"type":"local","value":1}],"result":2,"file":0,"col":0,"row":0}},
                {"type":"AssignVarStmt","stmt":{"source":{"type":"local","value":2},"target":3,"file":0,"col":0,"row":0}},
                {"type":"MakeObjectStmt","stmt":{"target":4,"file":0,"col":0,"row":0}},
                {"type":"ObjectInsertStmt","stmt":{"key":{"type":"string_index","value":0},"value":{"type":"local","value":3},"object":4,"file":0,"col":0,"row":0}},
                {"type":"ResultSetAddStmt","stmt":{"value":4,"file":0,"col":0,"row":0}}
              ]}]}]},
              "funcs": {"funcs": [{"name":"g0.data.foo.hello","params":[0,1],"return":2,"blocks":[
                {"stmts":[
                  {"type":"ResetLocalStmt","stmt":{"target":3,"file":0,"col":1,"row":3}},
                  {"type":"MakeNumberRefStmt","stmt":{"Index":1,"target":4,"file":0,"col":1,"row":3}},
                  {"type":"AssignVarOnceStmt","stmt":{"source":{"type":"local","value":4},"target":3,"file":0,"col":1,"row":3}}
                ]},
                {"stmts":[
                  {"type":"IsDefinedStmt","stmt":{"source":3,"file":0,"col":1,"row":3}},
                  {"type":"AssignVarOnceStmt","stmt":{"source":{"type":"local","value":3},"target":2,"file":0,"col":1,"row":3}}
                ]},
                {"stmts":[
                  {"type":"ReturnLocalStmt","stmt":{"source":2,"file":0,"col":1,"row":3}}
                ]}
              ],"path":["g0","foo","hello"]}]}
            }
            """#
        // Decode raw (without prepareForExecution).
        let raw = try JSONDecoder().decode(Policy.self, from: Data(json.utf8))
        // Decode + prepareForExecution (this runs renumbering).
        let prepared = try Policy(jsonData: Data(json.utf8))

        // Plans/funcs should be byte-for-byte identical: the input is already
        // compact, so the pass should not rewrite anything.
        let rawPlans = raw.plans?.plans ?? []
        let preparedPlans = prepared.plans?.plans ?? []
        for (r, p) in zip(rawPlans, preparedPlans) {
            #expect(r.blocks == p.blocks, "plan '\(r.name)' was unexpectedly rewritten")
        }
        let rawFuncs = raw.funcs?.funcs ?? []
        let preparedFuncs = prepared.funcs?.funcs ?? []
        for (r, p) in zip(rawFuncs, preparedFuncs) {
            #expect(r.blocks == p.blocks, "func '\(r.name)' was unexpectedly rewritten")
        }

        // maxLocal should be set after preparation.
        #expect(preparedPlans.first?.maxLocal == 4)
        #expect(preparedFuncs.first?.maxLocal == 4)
    }
}

extension IRRenumberingTests.TestCase: CustomTestStringConvertible {
    var testDescription: String { name }
}
