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

    /// `local2 = <slow async builtin>(input); local3 = echo(local2); result += local3`.
    /// The user-function call after the builtin gives a block entry where cancellation is observed.
    static func cancellablePolicy(builtin: String) -> IR.Policy {
        let echo = IR.Func(
            name: "echo", path: ["echo"], params: [Local(0)], returnVar: Local(1),
            blocks: [IR.Block(statements: [])])
        let block = IR.Block(statements: [
            .callStmt(
                IR.CallStatement(
                    callFunc: builtin, args: [IR.Operand(type: .local, value: .localIndex(0))], result: Local(2))),
            .callStmt(
                IR.CallStatement(
                    callFunc: "echo", args: [IR.Operand(type: .local, value: .localIndex(2))], result: Local(3))),
            .resultSetAddStmt(IR.ResultSetAddStatement(value: Local(3))),
        ])
        return IR.Policy(
            staticData: IR.Static(
                strings: [],
                builtinFuncs: [IR.BuiltinFunc(name: builtin, decl: AST.FunctionTypeDecl())],
                files: nil
            ),
            plans: IR.Plans(plans: [IR.Plan(name: "generated", blocks: [block])]),
            funcs: IR.Funcs(funcs: [echo])
        )
    }

    @Test("evaluate honors task cancellation on the async-builtin (dedicated-thread) path")
    func asyncCancellation() async throws {
        let slow: Builtin = { _, args in
            try await Task.sleep(nanoseconds: 50_000_000)
            return args[0]
        }
        var engine = OPA.Engine(
            policies: [Self.cancellablePolicy(builtin: "test.slow")],
            store: OPA.InMemoryStore(initialData: .object([:])),
            customBuiltins: ["test.slow": slow]
        )
        let pq = try await engine.prepareForEvaluation(query: "data.generated")

        let task = Task { try await pq.evaluate(input: .number(1)) }
        try await Task.sleep(nanoseconds: 10_000_000)  // let the VM reach the slow builtin
        task.cancel()

        await #expect {
            _ = try await task.value
        } throws: { error in
            (error as? RegoError)?.code == .evaluationCancelled
        }
    }

    /// Runs `work` on a thread with the given stack size and returns its result/throw.
    static func onThread<T: Sendable>(
        stackSize: Int, _ work: @escaping @Sendable () throws -> T
    ) async throws -> T {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<T, Swift.Error>) in
            let thread = Thread {
                do { cont.resume(returning: try work()) } catch { cont.resume(throwing: error) }
            }
            thread.stackSize = stackSize
            thread.start()
        }
    }

    @Test("evaluateSync runs a shallow query on a small-stack caller thread")
    func syncSmallStackCaller() async throws {
        var engine = Self.engine(builtin: "my.double", sync: true)
        let pq = try await engine.prepareForEvaluation(query: "data.generated")

        let result = try await Self.onThread(stackSize: 256 * 1024) {
            try pq.evaluateSync(input: .number(21))
        }
        #expect(result == [.number(42)])
    }

    /// One-plan policy whose only function calls itself unconditionally — unbounded recursion.
    static func recursivePolicy() -> IR.Policy {
        let selfCall = IR.CallStatement(
            callFunc: "recurse",
            args: [IR.Operand(type: .local, value: .localIndex(0)), IR.Operand(type: .local, value: .localIndex(1))],
            result: Local(2))
        let recurse = IR.Func(
            name: "recurse", path: ["recurse"], params: [Local(0), Local(1)], returnVar: Local(2),
            blocks: [IR.Block(statements: [.callStmt(selfCall)])])
        return IR.Policy(
            staticData: IR.Static(strings: [], builtinFuncs: nil, files: nil),
            plans: IR.Plans(plans: [
                IR.Plan(
                    name: "generated",
                    blocks: [
                        IR.Block(statements: [
                            .callStmt(selfCall), .resultSetAddStmt(IR.ResultSetAddStatement(value: Local(2))),
                        ])
                    ])
            ]),
            funcs: IR.Funcs(funcs: [recurse])
        )
    }

    @Test("evaluateSync bounds unbounded recursion with a graceful error rather than a stack overflow")
    func syncRecursionGuard() async throws {
        // Low limit so the bound trips before the unbounded recursion can overflow the stack.
        var engine = OPA.Engine(
            policies: [Self.recursivePolicy()], store: OPA.InMemoryStore(initialData: .object([:])),
            maxCallDepth: 16)
        let pq = try await engine.prepareForEvaluation(query: "data.generated")

        await #expect {
            _ = try await Self.onThread(stackSize: 1 << 20) {
                try pq.evaluateSync(input: .object([:]))
            }
        } throws: { error in
            (error as? RegoError)?.code == .maxCallDepthExceeded
        }
    }

    /// One-plan policy with a `f0 -> f1 -> ... -> f(depth-1)` call chain, i.e. an exact call depth.
    static func chainPolicy(depth: Int) -> IR.Policy {
        let args = [
            IR.Operand(type: .local, value: .localIndex(0)),
            IR.Operand(type: .local, value: .localIndex(1)),
        ]
        var funcs: [IR.Func] = []
        for i in 0..<depth {
            let body: IR.Block
            if i < depth - 1 {
                body = IR.Block(statements: [
                    .callStmt(IR.CallStatement(callFunc: "f\(i + 1)", args: args, result: Local(2)))
                ])
            } else {
                body = IR.Block(statements: [])  // leaf: returns undefined
            }
            funcs.append(
                IR.Func(
                    name: "f\(i)", path: ["f\(i)"], params: [Local(0), Local(1)],
                    returnVar: Local(2), blocks: [body]))
        }
        return IR.Policy(
            staticData: IR.Static(strings: [], builtinFuncs: nil, files: nil),
            plans: IR.Plans(plans: [
                IR.Plan(
                    name: "generated",
                    blocks: [
                        IR.Block(statements: [
                            .callStmt(IR.CallStatement(callFunc: "f0", args: args, result: Local(2))),
                            .resultSetAddStmt(IR.ResultSetAddStatement(value: Local(2))),
                        ])
                    ])
            ]),
            funcs: IR.Funcs(funcs: funcs)
        )
    }

    @Test("maxCallDepth is configurable: a chain deeper than the limit throws, raising it succeeds")
    func maxCallDepthIsConfigurable() async throws {
        // A 40-deep call chain: exceeds the default (32), fits a raised limit.
        func prepared(maxCallDepth: Int) async throws -> OPA.Engine.PreparedQuery {
            var engine = OPA.Engine(
                policies: [Self.chainPolicy(depth: 40)],
                store: OPA.InMemoryStore(initialData: .object([:])),
                maxCallDepth: maxCallDepth)
            return try await engine.prepareForEvaluation(query: "data.generated")
        }

        let tooShallow = try await prepared(maxCallDepth: OPA.Engine.defaultMaxCallDepth)
        await #expect {
            _ = try await Self.onThread(stackSize: 16 << 20) { try tooShallow.evaluateSync() }
        } throws: { ($0 as? RegoError)?.code == .maxCallDepthExceeded }

        let deepEnough = try await prepared(maxCallDepth: 64)
        let result = try await Self.onThread(stackSize: 16 << 20) { try deepEnough.evaluateSync() }
        #expect(result == ResultSet.empty)  // leaf returns undefined
    }

    // MARK: - Builtin coverage: default builtins + sync/async error handling

    @Test("a default (sync) builtin evaluates identically via evaluate and evaluateSync")
    func defaultBuiltinParity() async throws {
        // `count` is a default, synchronous builtin.
        var engine = OPA.Engine(
            policies: [Self.doublingPolicy(builtin: "count")],
            store: OPA.InMemoryStore(initialData: .object([:])))
        let pq = try await engine.prepareForEvaluation(query: "data.generated")
        let input: AST.RegoValue = .array([1, 2, 3])

        let asyncResult = try await pq.evaluate(input: input)
        let syncResult = try pq.evaluateSync(input: input)
        #expect(asyncResult == [.number(3)])
        #expect(syncResult == asyncResult)
    }

    static let boomError = BuiltinError.argumentTypeMismatch(arg: "x", got: "x", want: "y")

    @Test("a throwing sync builtin is undefined in non-strict mode and propagates in strict mode")
    func syncBuiltinErrorHandling() async throws {
        let boom: SyncBuiltin = { _, _ in throw Self.boomError }
        var engine = OPA.Engine(
            policies: [Self.doublingPolicy(builtin: "boom")],
            store: OPA.InMemoryStore(initialData: .object([:])),
            customSyncBuiltins: ["boom": boom])
        let pq = try await engine.prepareForEvaluation(query: "data.generated")

        #expect(try pq.evaluateSync(input: .number(1)) == [])  // non-strict: error -> undefined
        #expect {
            _ = try pq.evaluateSync(input: .number(1), strictBuiltins: true)
        } throws: { ($0 as? RegoError)?.code == .argumentTypeMismatch }
    }

    @Test("a throwing async builtin is undefined in non-strict mode and propagates in strict mode")
    func asyncBuiltinErrorHandling() async throws {
        let boom: Builtin = { _, _ in throw Self.boomError }
        var engine = OPA.Engine(
            policies: [Self.doublingPolicy(builtin: "boom")],
            store: OPA.InMemoryStore(initialData: .object([:])),
            customBuiltins: ["boom": boom])
        let pq = try await engine.prepareForEvaluation(query: "data.generated")

        #expect(try await pq.evaluate(input: .number(1)) == [])  // non-strict: error -> undefined
        await #expect {
            _ = try await pq.evaluate(input: .number(1), strictBuiltins: true)
        } throws: { ($0 as? RegoError)?.code == .argumentTypeMismatch }
    }

    @Test("evaluateSync rejects a store that is not a SyncStore")
    func syncRejectsNonSyncStore() async throws {
        var engine = OPA.Engine(
            policies: [Self.doublingPolicy(builtin: "count")],
            store: AsyncOnlyStore())
        let pq = try await engine.prepareForEvaluation(query: "data.generated")

        #expect {
            _ = try pq.evaluateSync(input: .array([1, 2, 3]))
        } throws: { ($0 as? RegoError)?.code == .syncEvaluationUnsupported }
    }

    @Test("a builtin name in both customBuiltins and customSyncBuiltins is rejected")
    func builtinNameConflict() async throws {
        var engine = OPA.Engine(
            policies: [Self.doublingPolicy(builtin: "dup")],
            store: OPA.InMemoryStore(initialData: .object([:])),
            customBuiltins: ["dup": { _, args in args[0] }],
            customSyncBuiltins: ["dup": { _, args in args[0] }])

        await #expect {
            _ = try await engine.prepareForEvaluation(query: "data.generated")
        } throws: { ($0 as? RegoError)?.code == .ambiguousBuiltinError }
    }
}

/// A store that conforms only to ``OPA/Store`` (not ``OPA/SyncStore``), used to verify the
/// `evaluateSync` store gate.
private struct AsyncOnlyStore: OPA.Store {
    func read(from: StoreKeyPath) async throws -> AST.RegoValue { .object([:]) }
    mutating func write(to: StoreKeyPath, value: AST.RegoValue) async throws {}
    mutating func remove(at: StoreKeyPath) async throws {}
}
