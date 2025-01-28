import AST
import Foundation
import IR

let localIdxData = Local(0)
let localIdxInput = Local(1)

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

    func resolveStaticString(_ index: Int) -> String? {
        guard case self.staticStrings.startIndex..<self.staticStrings.endIndex = index else {
            // Out-of-bounds
            return nil
        }

        return self.staticStrings[index]
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

    func resolveLocal(idx: IR.Local) -> AST.RegoValue {
        // walk the scope stack backwards looking for the first hit
        // stride sequence is empty if we gave an impossible range (-1..0 with -1 stride)
        // so we correctly don't enter the loop with an empty scopeStack.
        for i in stride(from: self.scopeStack.count - 1, through: 0, by: -1) {
            if let localValue = self.scopeStack[i].v.locals[idx] {
                return localValue
            }
        }

        return .undefined
    }

    mutating func assignLocal(idx: IR.Local, value: AST.RegoValue) throws {
        guard !self.scopeStack.isEmpty else {
            throw EvaluationError.internalError(
                reason: "attempted to assign local with no scope on the frame")
        }
        self.scopeStack.last!.v.locals[idx] = value
    }

    // TODO, should we throw or return optional on lookup failures?
    func resolveOperand(ctx: IREvaluationContext, _ op: IR.Operand) throws -> AST.RegoValue {
        switch op.value {
        case .localIndex(let idx):
            return resolveLocal(idx: Local(idx))
        case .bool(let boolValue):
            return .boolean(boolValue)
        case .stringIndex(let idx):
            return try .string(resolveStaticString(ctx: ctx, Int(idx)))
        }
    }

    func resolveStaticString(ctx: IREvaluationContext, _ idx: Int) throws -> String {
        guard let v = ctx.policy.resolveStaticString(idx) else {
            throw EvaluationError.invalidOperand(
                reason: "unable to resolve static string: \(idx)")
        }
        return v
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

    mutating func nextBlock() {
        self.blockIdx += 1
        self.statementIdx = 0
    }
}

// Evaluate an IR Plan from start to finish for the given IREvaluationContext
private func evalPlan(
    withContext ctx: IREvaluationContext,
    plan: IR.Plan
) async throws -> ResultSet {
    // Initialize the starting Frame+Scope from the top level Plan blocks and kick off evaluation.
    let frame = Frame(
        blocks: plan.blocks,
        locals: [
            // TODO: ?? are we going to hide stuff under special roots like OPA does?
            // TODO: We don't resolve refs with more complex paths very much... maybe we should
            // instead special case the DotStmt for local 0 and do a smaller read on the store?
            // ¯\_(ツ)_/¯ for now we'll just drop the whole thang in here as it simplifies the
            // other statments. We can refactor that part later to optimize.
            localIdxData: try await ctx.ctx.store.read(path: StoreKeyPath(segments: ["data"])),
            localIdxInput: ctx.ctx.input,
        ]
    )
    let pFrame = Ptr(toCopyOf: frame)
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

        while currentScopePtr.v.statementIdx < currentBlock.statements.count {

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
                let sourceValue = try framePtr.v.resolveOperand(ctx: ctx, stmt.source)
                let targetValue = framePtr.v.resolveLocal(idx: stmt.target)

                // if the target value is already defined, and not the same value as the source,
                // we should raise an exception
                if targetValue != .undefined && targetValue != sourceValue {
                    throw EvaluationError.assignOnceError(reason: "local already assigned")
                }
                try framePtr.v.assignLocal(idx: stmt.target, value: sourceValue)
            case let stmt as IR.AssignVarStatement:
                let sourceValue = try framePtr.v.resolveOperand(ctx: ctx, stmt.source)
                try framePtr.v.assignLocal(idx: stmt.target, value: sourceValue)
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
                try await evalCallStmt(ctx: ctx, frame: framePtr, stmt: stmt)

            case let stmt as IR.CallDynamicStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.DotStatement:
                let sourceValue = try framePtr.v.resolveOperand(ctx: ctx, stmt.source)
                let keyValue = try framePtr.v.resolveOperand(ctx: ctx, stmt.key)

                var targetValue: AST.RegoValue?
                switch sourceValue {
                case .object(let sourceObj):
                    targetValue = sourceObj[keyValue]
                case .array(let sourceArray):
                    if case .number(let numberValue) = keyValue {
                        let idx = numberValue.intValue
                        if idx < 0 || idx >= sourceArray.count {
                            throw EvaluationError.internalError(
                                reason: "DotStmt key array index out of bounds")
                        }
                        targetValue = sourceArray[idx]
                    }
                case .set(let sourceSet):
                    if sourceSet.contains(keyValue) {
                        targetValue = keyValue
                    }
                default:
                    throw EvaluationError.invalidDataType(
                        reason: "cannot perform DotStmt on \(type(of:sourceValue))")
                }

                // This statement is undefined if the key does not exist in the source value.
                guard let targetValue else {
                    // undefined
                    currentScopePtr.v.nextBlock()
                    break blockLoop
                }

                try framePtr.v.assignLocal(idx: stmt.target, value: targetValue)
            case let stmt as IR.EqualStatement:
                //This statement is undefined if a is not equal to b.
                let a = try framePtr.v.resolveOperand(ctx: ctx, stmt.a)
                let b = try framePtr.v.resolveOperand(ctx: ctx, stmt.b)
                if a == .undefined || b == .undefined || a != b {
                    currentScopePtr.v.nextBlock()
                    break blockLoop
                }
            case let stmt as IR.IsArrayStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.IsDefinedStatement:
                // This statement is undefined if source is undefined.
                if case .undefined = framePtr.v.resolveLocal(idx: stmt.source) {
                    currentScopePtr.v.nextBlock()
                    break blockLoop
                }
            case let stmt as IR.IsObjectStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.IsSetStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.IsUndefinedStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.LenStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.MakeArrayStatement:
                try framePtr.v.assignLocal(idx: stmt.target, value: .array([]))
            case let stmt as IR.MakeNullStatement:
                try framePtr.v.assignLocal(idx: stmt.target, value: .null)
            case let stmt as IR.MakeNumberStatement:
                try framePtr.v.assignLocal(
                    idx: stmt.target, value: .number(NSNumber(value: stmt.value)))
            case let stmt as IR.MakeNumberRefStatement:
                let sourceStringValue = try framePtr.v.resolveStaticString(
                    ctx: ctx, Int(stmt.index))
                let formatter = NumberFormatter()
                formatter.numberStyle = .decimal
                guard let n = formatter.number(from: sourceStringValue) else {
                    throw EvaluationError.invalidDataType(
                        reason: "invalid number literal with MakeNumberRefStatement")
                }
                try framePtr.v.assignLocal(idx: stmt.target, value: .number(n))
            case let stmt as IR.MakeObjectStatement:
                try framePtr.v.assignLocal(idx: stmt.target, value: .object([:]))
            case let stmt as IR.MakeSetStatement:
                try framePtr.v.assignLocal(idx: stmt.target, value: .set([]))
            case let stmt as IR.NopStatement:
                break
            case let stmt as IR.NotEqualStatement:
                //This statement is undefined if a is equal to b.
                let a = try framePtr.v.resolveOperand(ctx: ctx, stmt.a)
                let b = try framePtr.v.resolveOperand(ctx: ctx, stmt.b)
                if a == .undefined || b == .undefined || a == b {
                    currentScopePtr.v.nextBlock()
                    break blockLoop
                }
            case let stmt as IR.NotStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.ObjectInsertOnceStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.ObjectInsertStatement:
                let value = try framePtr.v.resolveOperand(ctx: ctx, stmt.value)
                let key = try framePtr.v.resolveOperand(ctx: ctx, stmt.key)
                let target = framePtr.v.resolveLocal(idx: stmt.object)
                guard value != .undefined && key != .undefined && target != .undefined else {
                    currentScopePtr.v.nextBlock()
                    break blockLoop
                }
                guard case .object(var targetObjectValue) = target else {
                    throw EvaluationError.invalidDataType(
                        reason:
                            "unable to perform ObjectInsertStatement on target value of type \(type(of: target))"
                    )
                }
                targetObjectValue[key] = value
                try framePtr.v.assignLocal(idx: stmt.object, value: .object(targetObjectValue))
            case let stmt as IR.ObjectMergeStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.ResetLocalStatement:
                try framePtr.v.assignLocal(idx: stmt.target, value: .undefined)
            case let stmt as IR.ResultSetAddStatement:
                let value = framePtr.v.resolveLocal(idx: stmt.value)
                guard value != .undefined else {
                    // undefined
                    currentScopePtr.v.nextBlock()
                    break blockLoop
                }
                guard case .object = value else {
                    // undefined
                    currentScopePtr.v.nextBlock()
                    break blockLoop
                }
                framePtr.v.results.insert(value)
            case let stmt as IR.ReturnLocalStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.ScanStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.SetAddStatement:
                throw EvaluationError.internalError(reason: "not implemented")
            case let stmt as IR.WithStatement:
                // First we need to resolve the value that will be upserted
                let overlayValue = try framePtr.v.resolveOperand(ctx: ctx, stmt.value)

                //                guard let overlayValue else {
                //                    throw EvaluationError.internalError(
                //                        reason: "unable to resolve target value for WithStmt patching")
                //                }

                // Next look up the object we'll be upserting into
                let toPatch = framePtr.v.resolveLocal(idx: stmt.local)

                // Resolve the patching path elements (composed of references to static strings
                let pathOfInts = stmt.path ?? []
                let path: [String] = pathOfInts.compactMap {
                    ctx.policy.resolveStaticString(Int($0))
                }
                if path.count != pathOfInts.count {
                    throw EvaluationError.internalError(
                        reason: "invalid path - some segments could not resolve to strings")
                }

                let patched = toPatch.patch(with: overlayValue, at: path)

                // Push a new scope that includes that patched local (likely shadowing a previous
                // scopes values) and start evaluating the new block
                var newLocals = currentScopePtr.v.locals
                newLocals[stmt.local] = patched
                currentScopePtr = framePtr.v.pushScope(
                    blocks: [stmt.block],
                    locals: newLocals
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

private func evalCallStmt(ctx: IREvaluationContext, frame: Ptr<Frame>, stmt: IR.CallStatement)
    async throws
{
    // Handle plan-defined functions first
    if ctx.policy.funcs[stmt.callFunc] != nil {
        try await callPlanFunc(ctx: ctx, frame: frame, stmt: stmt)
        return
    }

    // Handle built-in functions second
    let args = try stmt.args.map {
        try frame.v.resolveOperand(ctx: ctx, $0)
    }
    let result = try await ctx.ctx.builtins.invoke(name: stmt.callFunc, args: args)

    try frame.v.assignLocal(idx: stmt.result, value: result)

}

// callPlanFunc will evaluate calling a function defined on the plan
private func callPlanFunc(ctx: IREvaluationContext, frame: Ptr<Frame>, stmt: IR.CallStatement)
    async throws
{
    guard let fn = ctx.policy.funcs[stmt.callFunc] else {
        throw EvaluationError.internalError(
            reason: "function definition not found: \(stmt.callFunc)")
    }
    guard fn.params.count == stmt.args.count else {
        throw EvaluationError.internalError(
            reason: "mismatched argument count for function \(stmt.callFunc)")
    }

    let args = try stmt.args.map {
        try frame.v.resolveOperand(ctx: ctx, $0)
    }

    // Match source arguments to target params
    // to construct the locals map for the callee.
    // args are the resolved values to pass.
    // fn.params are the Local indecies to pass them in to
    // in the new frame.
    var callLocals: [IR.Local: AST.RegoValue] = zip(args, fn.params).reduce(into: [:]) {
        out, pair in
        out[pair.1] = pair.0
    }

    // Add in implicit input + data locals
    callLocals[localIdxInput] = frame.v.resolveLocal(idx: localIdxInput)
    callLocals[localIdxData] = frame.v.resolveLocal(idx: localIdxData)  // TODO deal with optional

    // Setup a new frame for the function call
    let callFrame = Frame(
        blocks: fn.blocks,
        locals: callLocals
    )
    let callFramePtr = Ptr(toCopyOf: callFrame)
    let resultSet = try await evalFrame(withContext: ctx, framePtr: callFramePtr)

    guard case 0...1 = resultSet.count else {
        throw EvaluationError.internalError(
            reason: "unexpected number of results from function call: \(resultSet.count)")
    }
    let result = resultSet.first ?? .undefined
    try frame.v.assignLocal(idx: stmt.result, value: result)
}
