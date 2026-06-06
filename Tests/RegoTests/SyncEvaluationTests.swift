import AST
import Foundation
import IR
import Testing

@testable import Rego

@Suite("SyncEvaluation")
struct SyncEvaluationTests {
    /// One-plan policy: `local2 = <builtin>(input); result += local2`.
    /// With a doubling builtin and input `21` this yields a result set of `{42}`.
    static func doublingPolicy(builtin: String) -> IR.Policy {
        let block = IR.Block(statements: [
            .callStmt(
                IR.CallStatement(
                    callFunc: builtin,
                    args: [IR.Operand(type: .local, value: .localIndex(0))],
                    result: Local(2)
                )),
            .resultSetAddStmt(IR.ResultSetAddStatement(value: Local(2))),
        ])
        return IR.Policy(
            staticData: IR.Static(
                strings: [],
                builtinFuncs: [IR.BuiltinFunc(name: builtin, decl: AST.FunctionTypeDecl())],
                files: nil
            ),
            plans: IR.Plans(plans: [IR.Plan(name: "generated", blocks: [block])]),
            funcs: IR.Funcs(funcs: [])
        )
    }

    static func double(_ args: [AST.RegoValue]) throws -> AST.RegoValue {
        guard case .number(let n) = args[0] else {
            throw BuiltinError.argumentTypeMismatch(arg: "x", got: args[0].typeName, want: "number")
        }
        return .number(RegoNumber(n.decimalValue + n.decimalValue))
    }

    static func engine(builtin: String, sync: Bool) -> OPA.Engine {
        let sleepyAsync: Builtin = { _, args in
            try await Task.sleep(nanoseconds: 1_000_000)
            return try double(args)
        }
        let plainSync: SyncBuiltin = { _, args in try double(args) }
        return OPA.Engine(
            policies: [doublingPolicy(builtin: builtin)],
            store: OPA.InMemoryStore(initialData: .object([:])),
            customBuiltins: sync ? [:] : [builtin: sleepyAsync],
            customSyncBuiltins: sync ? [builtin: plainSync] : [:]
        )
    }

    @Test("evaluate and evaluateSync agree for a synchronous builtin")
    func syncParity() async throws {
        var engine = Self.engine(builtin: "my.double", sync: true)
        let pq = try await engine.prepareForEvaluation(query: "data.generated")

        let asyncResult = try await pq.evaluate(input: .number(21))
        let syncResult = try pq.evaluateSync(input: .number(21))

        #expect(asyncResult == [.number(42)])
        #expect(syncResult == asyncResult)
    }

    @Test("async builtin resolves through the suspending async path")
    func asyncBuiltinEvaluates() async throws {
        var engine = Self.engine(builtin: "my.async_double", sync: false)
        let pq = try await engine.prepareForEvaluation(query: "data.generated")

        let result = try await pq.evaluate(input: .number(21))
        #expect(result == [.number(42)])
    }

    @Test("evaluateSync rejects a query that needs an async builtin")
    func syncRejectsAsyncBuiltin() async throws {
        var engine = Self.engine(builtin: "my.async_double", sync: false)
        let pq = try await engine.prepareForEvaluation(query: "data.generated")

        #expect {
            _ = try pq.evaluateSync()
        } throws: { error in
            (error as? RegoError)?.code == .syncEvaluationUnsupported
        }
    }
}
