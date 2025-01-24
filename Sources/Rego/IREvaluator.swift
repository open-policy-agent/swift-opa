import AST
import Foundation
import IR

let LOCAL_IDX_DATA = Local(0)
let LOCAL_IDX_INPUT = Local(1)

internal struct IREvaluator {
    private var policies: [IndexedIRPolicy] = []

    init(bundles: [String: Bundle]) async throws {
        for (bundleName, bundle) in bundles {
            for planFile in bundle.planFiles {
                do {
                    let parsed = try IR.Policy(fromJson: planFile.data)
                    self.policies.append(IndexedIRPolicy(policy: parsed))
                } catch {
                    throw EvaluatorError.bundleInitializationFailed(
                        bundle: bundleName,
                        reason: "IR plan file '\(planFile.url)' parsing failed: \(error)"
                    )
                }
            }
        }
    }
}

extension IREvaluator: Evaluator {
    func evaluate(withContext ctx: EvaluationContext) async throws -> ResultSet {
        // TODO: We're assuming that queries are only ever defined in a single policy... that _should_ hold true.. but who's checkin?
        for policy in policies {
            if let plan = policy.plans[ctx.query] {
                return try await evalPlan(
                    withContext: IREvaluationContext(ctx: ctx, policy: policy), plan: plan)
            }
        }
        throw EvaluationError.unknownQuery(query: ctx.query)
    }
}

// Policy wraps an IR.Policy with some more optimized accessors for use in evaluations.
private struct IndexedIRPolicy {
    // Original policy  TODO: we may not need this?
    var ir: IR.Policy

    // Policy plans indexed by plan name (aka query name)
    var plans: [String: IR.Plan] = [:]

    // Policy functions indexed by function name
    var funcs: [String: IR.Func] = [:]

    // Policy static values, indexes match original plan array
    var staticStrings: [String] = []

    // On init() we'll pre-process some of the raw parsed IR.Policy to structure it in
    // more convienent (and optimized) structures to evaluate queries.
    init(policy: IR.Policy) {
        self.ir = policy
        for plan in policy.plans?.plans ?? [] {
            // TODO: is plan.name actually the right string format to
            // match a query string? If no, convert it here.
            // TODO: validator should ensure these names were unique
            self.plans[plan.name] = plan
        }
        for funcDecl in policy.funcs?.funcs ?? [] {
            // TODO: validator should ensure these names were unique
            self.funcs[funcDecl.name] = funcDecl
        }
        for string in policy.staticData?.strings ?? [] {
            self.staticStrings.append(string.value)
        }
    }
}

private struct IREvaluationContext {
    var ctx: EvaluationContext
    var policy: IndexedIRPolicy
}

private typealias Locals = [IR.Local: AST.RegoValue]

// Frame represents a stack frame used during Rego IR evaluation. Each function call
// will prompt creation of a new stack frame.
private struct Frame {
    var scopeStack: [Ptr<Scope>] = []
    var results: ResultSet = ResultSet()

    init(blocks: [IR.Block], locals: Locals = [:]) {
        _ = self.pushScope(blocks: blocks, locals: locals)
    }

    func currentScope() throws -> Ptr<Scope> {
        guard !self.scopeStack.isEmpty else {
            throw EvaluationError.internalError(reason: "no scopes remain on the frame")
        }
        return self.scopeStack.last!
    }

    // Create a new Scope, seed with some locals, push it to the stack, and return it.
    mutating func pushScope(blocks: [IR.Block], locals: Locals = [:]) -> Ptr<Scope> {
        let scopePtr = Ptr(toCopyOf: Scope(blocks: blocks, locals: locals))
        self.scopeStack.append(scopePtr)
        return scopePtr
    }

    mutating func popScope() throws -> Ptr<Scope> {
        if self.scopeStack.count <= 1 {
            throw EvaluationError.internalError(reason: "attempted to pop with no scopes left")
        }
        self.scopeStack.removeLast()
        return self.scopeStack.last!
    }

    func resolveLocal(ctx: IREvaluationContext, idx: IR.Local) throws -> AST.RegoValue? {
        // walk the scope stack backwards looking for the first hit
        // stride sequence is empty if we gave an impossible range (-1..0 with -1 stride)
        // so we correctly don't enter the loop with an empty scopeStack.
        for i in stride(from: self.scopeStack.count - 1, through: 0, by: -1) {
            if let localValue = self.scopeStack[i].v.locals[idx] {
                return localValue
            }
        }

        return nil
    }

    mutating func assignLocal(idx: IR.Local, value: AST.RegoValue) throws {
        guard !self.scopeStack.isEmpty else {
            throw EvaluationError.internalError(
                reason: "attempted to assign local with no scope on the frame")
        }
        self.scopeStack.last!.v.locals[idx] = value
    }
}

// Scopes are children of a Frame, representing a logical Rego scope. Each time
// a statement has nested blocks a new Scope is pushed. These are primarily used
// for further protecting locals and tracking "with" value overrides.
private struct Scope {
    var blockIdx: Int = 0
    var statementIdx: Int = 0
    let blocks: [IR.Block]
    var locals: Locals

    // Initialize a fresh scope given a set of blocks to process
    // within the context of the Scope
    init(blocks: [IR.Block], locals: Locals = [:]) {
        self.locals = locals
        self.blocks = blocks
    }
}

// Evaluate an IR Plan from start to finish for the given IREvaluationContext
private func evalPlan(
    withContext ctx: IREvaluationContext,
    plan: IR.Plan
) async throws -> ResultSet {
    // Initialize the starting Frame+Scope from the top level Plan blocks and kick off evaluation.
    var frame = Frame(
        blocks: plan.blocks,
        locals: [
            // TODO: ?? are we going to hide stuff under special roots like OPA does?
            // TODO: We don't resolve refs with more complex paths very much... maybe we should
            // instead special case the DotStmt for local 0 and do a smaller read on the store?
            // ¯\_(ツ)_/¯ for now we'll just drop the whole thang in here as it simplifies the
            // other statments. We can refactor that part later to optimize.
            LOCAL_IDX_DATA: try await ctx.ctx.store.read(path: StoreKeyPath(segments: ["data"])),
            LOCAL_IDX_INPUT: ctx.ctx.input,
        ]
    )
    var pFrame = Ptr(toCopyOf: frame)
    return try await evalFrame(withContext: ctx, framePtr: pFrame)
}

// Evaluate a Frame from start to finish (respecting Task.isCancelled)
private func evalFrame(
    withContext ctx: IREvaluationContext,
    framePtr: Ptr<Frame>
) async throws -> ResultSet {
    var currentScopePtr = try framePtr.v.currentScope()

    // To evaluate a Frame we iterate through each block of the current scope, evaluating
    // statements in the block one at a time. We will jump between blocks being executed but
    // never go backwards, only early exit maneuvers jumping "forward" in the plan.
    blockLoop: while currentScopePtr.v.blockIdx < currentScopePtr.v.blocks.count {

        let currentBlock = currentScopePtr.v.blocks[currentScopePtr.v.blockIdx]

        stmtLoop: while currentScopePtr.v.statementIdx < currentBlock.statements.count {

            if Task.isCancelled {
                throw EvaluationError.evaluationCancelled(reason: "parent task cancelled")
            }

            let statement = currentBlock.statements[currentScopePtr.v.statementIdx]

            switch statement {
            case let stmt as IR.AssignAppendStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.AssignIntStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.AssignVarOnceStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.AssignVarStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.BlockStatement:
                currentScopePtr = framePtr.v.pushScope(blocks: stmt.blocks)
                break blockLoop
            case let stmt as IR.BreakStatement:
                // Pop N scopes for the "index" and resume processing from
                // that saved scope. Drop all scopes that are popped.
                for _ in 0...stmt.index {
                    currentScopePtr = try framePtr.v.popScope()
                }
                break blockLoop
            case let stmt as IR.CallStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.CallDynamicStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.DotStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.EqualStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.IsArrayStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.IsDefinedStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.IsObjectStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.IsSetStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.IsUndefinedStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.LenStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.MakeArrayStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.MakeNullStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.MakeNumberStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.MakeNumberRefStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.MakeObjectStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.MakeSetStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.NopStatement:
                break
            case let stmt as IR.NotEqualStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.NotStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.ObjectInsertOnceStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.ObjectInsertStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.ObjectMergeStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.ResetLocalStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.ResultSetAddStatement:
                guard let value = try framePtr.v.resolveLocal(ctx: ctx, idx: stmt.value) else {
                    // undefined
                    currentScopePtr.v.blockIdx += 1
                    currentScopePtr.v.statementIdx = 0
                    break blockLoop
                }
                guard case .object(let objValue) = value else {
                    // undefined
                    currentScopePtr.v.blockIdx += 1
                    currentScopePtr.v.statementIdx = 0
                    break blockLoop
                }
                framePtr.v.results.insert(objValue)
            case let stmt as IR.ReturnLocalStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.ScanStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.SetAddStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.WithStatement:
                // First we need to resolve the value that will be upserted
                var value: AST.RegoValue?
                switch stmt.value.value {
                case .localIndex(let numberValue):
                    value = try framePtr.v.resolveLocal(ctx: ctx, idx: Local(numberValue))
                case .bool(let boolValue):
                    value = AST.RegoValue.boolean(boolValue)
                case .stringIndex(let stringIdx):
                    guard stringIdx >= 0 && stringIdx < ctx.policy.staticStrings.endIndex else {
                        throw EvaluationError.invalidOperand(
                            reason:
                                "string index out of bounds 0..\(stringIdx)..\(ctx.policy.staticStrings.endIndex)"
                        )
                    }
                    value = AST.RegoValue.string(ctx.policy.staticStrings[stringIdx])
                }

                guard let value else {
                    throw EvaluationError.internalError(
                        reason: "unable to resolve target value for WithStmt patching")
                }
                // TODO what do we do with the value now?

                // Next look up the object we'll be upserting in to
                guard let patched = try framePtr.v.resolveLocal(ctx: ctx, idx: stmt.local) else {
                    // undefined // TODO: is this the right behavior? Or we should just "patch" a fresh empty object?
                    currentScopePtr.v.blockIdx += 1
                    currentScopePtr.v.statementIdx = 0
                    break blockLoop
                }

                guard case .object(var patchedObj) = patched else {
                    throw EvaluationError.internalError(
                        reason: "unexpected value type \(type(of: statement)) for WithStmt patch")
                }

                // TODO: patch that object at the specified path
                // I guess this only works on objects? Is it possible to "with" something else in rego?

                // Push a new scope that includes that patched local (likely shadowing a previous
                // scopes values) and start evaluating the new block
                currentScopePtr = framePtr.v.pushScope(
                    blocks: [stmt.block],
                    locals: [stmt.local: patched]  // TODO figure out how to coerce RegoValue.object regoValue
                )
                break blockLoop
            default:
                throw EvaluationError.internalError(
                    reason: "unexpected statement type \(type(of: statement))")
            }
            currentScopePtr.v.statementIdx += 1
        }
        currentScopePtr.v.blockIdx += 1
        currentScopePtr.v.statementIdx = 0
    }

    return framePtr.v.results
}
