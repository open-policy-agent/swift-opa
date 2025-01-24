import AST
import Foundation
import IR

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
                return try evalPlan(
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
            // TODO: is plan.name actually the right string format to match a query string? If no, convert it here.
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

private struct WithPatch {
    var local: IR.Local
    var path: [Int32]
    var value: AST.RegoValue  // TODO: is this the right type?
}

// Frame represents a stack frame used during Rego IR evaluation. Each function call
// will prompt creation of a new stack frame.
private struct Frame {
    var locals: Locals = [:]  // Superset of frame locals
    var savedScopes: [Ptr<Scope>] = []
    var currentScope: Ptr<Scope>
    var results: ResultSet = ResultSet()

    init(blocks: [IR.Block], locals: Locals = [:]) {
        var initialScope = Scope(blocks: blocks, locals: locals)
        let initialScopePtr = Ptr(ref: &initialScope)
        for (idx, value) in initialScopePtr.v.locals {
            self.locals[idx] = value
        }
        self.currentScope = initialScopePtr
    }

    // Create a new Scope, seed with some locals, push it to the stack, and return it.
    mutating func pushScope(blocks: [IR.Block], locals: Locals = [:]) -> Ptr<Scope> {
        let scopePtr = Ptr(toCopyOf: Scope(blocks: blocks, locals: locals))
        self.savedScopes.append(scopePtr)
        for (idx, value) in scopePtr.v.locals {
            self.locals[idx] = value
        }
        return scopePtr
    }

    mutating func popScope() throws -> Ptr<Scope> {
        if self.savedScopes.count < 1 {
            throw EvaluationError.internalError(reason: "attempted to pop with no scopes left")
        }

        for (idx, value) in currentScope.v.locals {
            self.locals.removeValue(forKey: idx)
        }

        self.currentScope = self.savedScopes.removeLast()

        // TODO: Any "with" shadowing stuff to cleanup?
        return self.currentScope
    }

    func resolveLocal(idx: IR.Local) -> AST.RegoValue? {
        return locals[idx]
    }

    mutating func assignLocal(idx: IR.Local, value: AST.RegoValue) throws {
        self.currentScope.v.locals[idx] = value
        locals[idx] = value
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
private func evalPlan(withContext ctx: IREvaluationContext, plan: IR.Plan) throws -> ResultSet {
    // Initialize the starting Frame+Scope from the top level Plan blocks and kick off evaluation.
    return try evalFrame(withContext: ctx, framePtr: Ptr(toCopyOf: Frame(blocks: plan.blocks)))
}

// Evaluate a Frame from start to finish (respecting Task.isCancelled)
private func evalFrame(withContext ctx: IREvaluationContext, framePtr: Ptr<Frame>) throws
    -> ResultSet
{
    var currentScopePtr = framePtr.v.currentScope

    // To evaluate a Frame we iterate through each block of the current scope, evaluating
    // statements in the block one at a time. We will jump between blocks being executed but
    // never go backwards, only early exit maneuvers jumping "forward" in the plan.
    blockLoop: while currentScopePtr.v.blockIdx < currentScopePtr.v.blocks.count {
        stmtLoop: while currentScopePtr.v.statementIdx
            < currentScopePtr.v.blocks[currentScopePtr.v.blockIdx].statements.count
        {

            if Task.isCancelled {
                throw EvaluationError.evaluationCancelled(reason: "parent task cancelled")
            }

            let statement = currentScopePtr.v.blocks[currentScopePtr.v.blockIdx].statements[
                currentScopePtr.v.statementIdx]

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
                guard let value: AST.RegoValue = framePtr.v.resolveLocal(idx: stmt.value) else {
                    // undefined
                    currentScopePtr.v.blockIdx += 1
                    currentScopePtr.v.statementIdx = 0
                    break blockLoop
                }
                // TODO: what should the key be for these to match up with the go SDK? i _think_ query is right? it probably shouldn't be a String type though..
                framePtr.v.results.insert([ctx.ctx.query: value])
                break
            case let stmt as IR.ReturnLocalStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.ScanStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.SetAddStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.WithStatement:
                currentScopePtr = framePtr.v.pushScope(blocks: [stmt.block])
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
