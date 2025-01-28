import AST
import Foundation
import IR

let localIdxInput = Local(0)
let localIdxData = Local(1)

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
            localIdxInput: ctx.ctx.input,
            localIdxData: try await ctx.ctx.store.read(path: StoreKeyPath(segments: ["data"])),
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
            case let stmt as IR.ArrayAppendStatement:
                let array = framePtr.v.resolveLocal(idx: stmt.array)
                let value = try framePtr.v.resolveOperand(ctx: ctx, stmt.value)
                guard case .array(var arrayValue) = array, value != .undefined else {
                    currentScopePtr.v.nextBlock()
                    break blockLoop
                }
                arrayValue.append(value)
                try framePtr.v.assignLocal(idx: stmt.array, value: .array(arrayValue))

            case let stmt as IR.AssignIntStatement:
                try framePtr.v.assignLocal(
                    idx: stmt.target, value: .number(NSNumber(value: stmt.value)))

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
                currentScopePtr = framePtr.v.pushScope(
                    blocks: stmt.blocks, locals: currentScopePtr.v.locals)
                break blockLoop

            case let stmt as IR.BreakStatement:
                // Pop N scopes for the "index" and resume processing from
                // that saved scope. Drop all scopes that are popped.
                for _ in 0...stmt.index {
                    currentScopePtr = try framePtr.v.popScope()
                }
                break blockLoop

            case let stmt as IR.CallDynamicStatement:
                var path: [String] = []
                for p in stmt.path {
                    let segment = try framePtr.v.resolveOperand(ctx: ctx, p)
                    guard case .string(let stringValue) = segment else {
                        currentScopePtr.v.nextBlock()
                        break blockLoop
                    }
                    path.append(stringValue)
                }

                let funcName = path.joined(separator: ".")

                try await evalCall(
                    ctx: ctx,
                    frame: framePtr,
                    funcName: funcName,
                    args: stmt.args.map {  // (╯°□°)╯︵ ┻━┻
                        // TODO: make the CallDynamicStatement "args" match the CallStatement ones upstream..
                        IR.Operand(
                            type: Operand.OpType.local, value: Operand.Value.localIndex(Int($0)))
                    },
                    resultIdx: stmt.result
                )

            case let stmt as IR.CallStatement:
                try await evalCall(
                    ctx: ctx,
                    frame: framePtr,
                    funcName: stmt.callFunc,
                    args: stmt.args,
                    resultIdx: stmt.result
                )

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
                guard case .array = try framePtr.v.resolveOperand(ctx: ctx, stmt.source) else {
                    currentScopePtr.v.nextBlock()
                    break blockLoop
                }

            case let stmt as IR.IsDefinedStatement:
                // This statement is undefined if source is undefined.
                if case .undefined = framePtr.v.resolveLocal(idx: stmt.source) {
                    currentScopePtr.v.nextBlock()
                    break blockLoop
                }

            case let stmt as IR.IsObjectStatement:
                guard case .object = try framePtr.v.resolveOperand(ctx: ctx, stmt.source) else {
                    currentScopePtr.v.nextBlock()
                    break blockLoop
                }

            case let stmt as IR.IsSetStatement:
                guard case .set = try framePtr.v.resolveOperand(ctx: ctx, stmt.source) else {
                    currentScopePtr.v.nextBlock()
                    break blockLoop
                }

            case let stmt as IR.IsUndefinedStatement:
                // This statement is undefined if source is not undefined.
                guard case .undefined = framePtr.v.resolveLocal(idx: stmt.source) else {
                    currentScopePtr.v.nextBlock()
                    break blockLoop
                }

            case let stmt as IR.LenStatement:
                let sourceValue = try framePtr.v.resolveOperand(ctx: ctx, stmt.source)
                guard case .undefined = sourceValue else {
                    currentScopePtr.v.nextBlock()
                    break blockLoop
                }
                var len: Int = 0
                switch sourceValue {
                case let c as any Collection:
                    len = c.count
                default:
                    throw EvaluationError.invalidOperand(
                        reason: "len source must be a collection, got \(type(of: sourceValue))")
                }
                try framePtr.v.assignLocal(idx: stmt.target, value: .number(NSNumber(value: len)))

            case let stmt as IR.MakeArrayStatement:
                var arr: [AST.RegoValue] = []
                arr.reserveCapacity(Int(stmt.capacity))
                try framePtr.v.assignLocal(idx: stmt.target, value: .array(arr))

            case let stmt as IR.MakeNullStatement:
                try framePtr.v.assignLocal(idx: stmt.target, value: .null)

            case let stmt as IR.MakeNumberIntStatement:
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
                // TODO: oh no.. does this mean we should refactor to something like an `evalBlock()` helper that
                // can indicate if it was undefined? .. this might impact how we do ScanStmt too
                throw EvaluationError.internalError(reason: "NotStatement not implemented")

            case let stmt as IR.ObjectInsertOnceStatement:
                let targetValue = try framePtr.v.resolveOperand(ctx: ctx, stmt.value)
                let key = try framePtr.v.resolveOperand(ctx: ctx, stmt.key)
                let target = framePtr.v.resolveLocal(idx: stmt.object)
                guard targetValue != .undefined && key != .undefined && target != .undefined else {
                    currentScopePtr.v.nextBlock()
                    break blockLoop
                }
                guard case .object(var targetObjectValue) = target else {
                    throw EvaluationError.invalidDataType(
                        reason:
                            "unable to perform ObjectInsertStatement on target value of type \(type(of: target))"
                    )
                }
                guard let currentValue = targetObjectValue[key], currentValue != targetValue else {
                    throw EvaluationError.objectInsertOnceError(
                        reason: "key '\(key)' already exists in object")
                }
                targetObjectValue[key] = targetValue
                try framePtr.v.assignLocal(idx: stmt.object, value: .object(targetObjectValue))

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
                let a = framePtr.v.resolveLocal(idx: stmt.a)
                let b = framePtr.v.resolveLocal(idx: stmt.b)
                if a == .undefined || b == .undefined {
                    currentScopePtr.v.nextBlock()
                    break blockLoop
                }
                guard case .object(var objectValueA) = a, case .object(var objectValueB) = b else {
                    throw EvaluationError.invalidDataType(
                        reason:
                            "unable to perform ObjectMergeStatement with types \(type(of: a)) and \(type(of: b))"
                    )
                }
                let merged = objectValueA.merge(with: objectValueB)
                try framePtr.v.assignLocal(idx: stmt.target, value: .object(merged))

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
                let result = framePtr.v.resolveLocal(idx: stmt.source)
                return ResultSet([result])

            case let stmt as IR.ScanStatement:
                // This statement is undefined if source is a scalar value or empty collection.
                let source = framePtr.v.resolveLocal(idx: stmt.source)
                guard let sourceCollection = source as? any Collection<AST.RegoValue> else {
                    currentScopePtr.v.nextBlock()
                    break blockLoop
                }

                for i in sourceCollection.indices {
                    let currentKey = try AST.RegoValue(from: i)

                    var currentValue: AST.RegoValue?
                    switch source {
                    case .array(let sourceArray):
                        guard case .number(let keyInt) = currentKey else {
                            throw EvaluationError.internalError(
                                reason: "ScanStatement: array index must be an integer"
                            )
                        }
                        guard keyInt.intValue > 0 && keyInt.intValue < sourceArray.count else {
                            throw EvaluationError.internalError(
                                reason: "ScanStatement: index out of bounds"
                            )
                        }
                        currentValue = sourceArray[keyInt.intValue]
                    case .object(let sourceObject):
                        currentValue = sourceObject[currentKey]
                    case .set:
                        // TODO: Is this right? What would be the key and value for a set?
                        currentValue = currentKey
                    default:
                        // let it fall through to the guard below
                        break
                    }

                    guard let currentValue = currentValue else {
                        currentScopePtr.v.nextBlock()
                        break blockLoop
                    }

                    // Treat each block we iterate over as a frame and let it evaluate to completion. This
                    // lets us drop any state on it and work around trying to jump around in this loop.
                    // Note: This is assuming that the ".locals" on a scope is a full set we can propagate.
                    // TODO: verify that this is OK to do... I _think_ we've pushed all the state we needed through... maybe..
                    var subFrame = Frame(
                        blocks: [stmt.block],
                        locals: currentScopePtr.v.locals
                    )
                    try subFrame.assignLocal(idx: stmt.key, value: currentKey)
                    try subFrame.assignLocal(idx: stmt.value, value: currentValue)
                    let subFramePtr = Ptr(toCopyOf: subFrame)
                    let resultSet = try await evalFrame(withContext: ctx, framePtr: subFramePtr)

                    // Propagate any results from the block's sub frame into the parent frame
                    for result in resultSet {
                        framePtr.v.results.insert(result)
                    }
                }

            case let stmt as IR.SetAddStatement:
                let value = try framePtr.v.resolveOperand(ctx: ctx, stmt.value)
                let target = framePtr.v.resolveLocal(idx: stmt.set)
                guard value != .undefined && target != .undefined else {
                    currentScopePtr.v.nextBlock()
                    break blockLoop
                }
                guard case .set(var targetSetValue) = target else {
                    throw EvaluationError.invalidDataType(
                        reason:
                            "unable to perform SetAddStatement on target value of type \(type(of: target))"
                    )
                }
                targetSetValue.insert(value)
                try framePtr.v.assignLocal(idx: stmt.set, value: .set(targetSetValue))

            case let stmt as IR.WithStatement:
                // First we need to resolve the value that will be upserted
                let overlayValue = try framePtr.v.resolveOperand(ctx: ctx, stmt.value)

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

private func evalCall(
    ctx: IREvaluationContext,
    frame: Ptr<Frame>,
    funcName: String,
    args: [IR.Operand],
    resultIdx: IR.Local
) async throws {
    // TODO: We should check the args "input" for undefined

    // Handle plan-defined functions first
    if ctx.policy.funcs[funcName] != nil {
        try await callPlanFunc(
            ctx: ctx, frame: frame, funcName: funcName, args: args, resultIdx: resultIdx)
        return
    }

    // Handle built-in functions second
    let args = try args.map {
        try frame.v.resolveOperand(ctx: ctx, $0)
    }
    let result = try await ctx.ctx.builtins.invoke(name: funcName, args: args)

    try frame.v.assignLocal(idx: resultIdx, value: result)

}

// callPlanFunc will evaluate calling a function defined on the plan
private func callPlanFunc(
    ctx: IREvaluationContext,
    frame: Ptr<Frame>,
    funcName: String,
    args: [IR.Operand],
    resultIdx: IR.Local
) async throws {
    guard let fn = ctx.policy.funcs[funcName] else {
        throw EvaluationError.internalError(
            reason: "function definition not found: \(funcName)")
    }
    guard fn.params.count == args.count else {
        throw EvaluationError.internalError(
            reason: "mismatched argument count for function \(funcName)")
    }

    let args = try args.map {
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
    try frame.v.assignLocal(idx: resultIdx, value: result)
}
