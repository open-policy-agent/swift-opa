import AST
import Foundation
import IR

let localIdxInput = Local(0)
let localIdxData = Local(1)

internal struct IREvaluator {
    private var policies: [IndexedIRPolicy] = []

    init(bundles: [String: OPA.Bundle]) throws {
        for (bundleName, bundle) in bundles {
            for planFile in bundle.planFiles {
                do {
                    let parsed = try IR.Policy(jsonData: planFile.data)
                    self.policies.append(IndexedIRPolicy(policy: parsed))
                } catch {
                    throw RegoError(
                        code: .bundleInitializationError,
                        message: """
                            intialization failed for bundle \(bundleName), \
                            parsing failed in file: \(planFile.url)
                            """,
                        cause: error
                    )
                }
            }
        }
        guard !policies.isEmpty else {
            throw RegoError(code: .noPlansFoundError, message: "no IR plans were found in any of the provided bundles")
        }
    }

    // Initialize directly with parsed policies - useful for testing
    init(policies: [IR.Policy]) {
        self.policies = policies.map { IndexedIRPolicy(policy: $0) }
    }
}

extension IREvaluator: Evaluator {
    func evaluate(withContext ctx: EvaluationContext) async throws -> ResultSet {
        // TODO: We're assuming that queries are only ever defined in a single policy... that _should_ hold true.. but who's checkin?

        let entrypoint = try queryToEntryPoint(ctx.query)

        for policy in policies {
            if let plan = policy.plans[entrypoint] {
                let ctx = IREvaluationContext(ctx: ctx, policy: policy)
                return try await evalPlan(
                    withContext: ctx,
                    plan: plan
                )
            }
        }
        throw RegoError(code: .unknownQuery, message: "query not found in plan: \(ctx.query)")
    }
}

func queryToEntryPoint(_ query: String) throws -> String {
    let prefix = "data"
    guard query.hasPrefix(prefix) else {
        throw RegoError(code: .unsupportedQuery, message: "unsupported query: \(query), must start with 'data'")
    }
    if query == prefix {
        // done!
        return query
    }
    return query.dropFirst(prefix.count + 1).replacingOccurrences(of: ".", with: "/")
}

// Policy wraps an IR.Policy with some more optimized accessors for use in evaluations.
internal struct IndexedIRPolicy {
    // Original policy  TODO: we may not need this?
    var ir: IR.Policy

    // Policy plans indexed by plan name (aka query name)
    var plans: [String: IR.Plan] = [:]

    // Policy functions indexed by function name
    var funcs: [String: IR.Func] = [:]

    // Policy functions indexed by path name
    var funcsPathToName: [String: String] = [:]

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
            if !funcDecl.path.isEmpty {
                self.funcsPathToName[funcDecl.path.joined(separator: ".")] = funcDecl.name
            }
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

internal struct IREvaluationContext {
    var ctx: EvaluationContext
    var policy: IndexedIRPolicy
    var maxCallDepth: Int = 16_384
    var callDepth: Int = 0

    func withIncrementedCallDepth() -> IREvaluationContext {
        var ctx = self
        ctx.callDepth += 1
        return ctx
    }
}

internal typealias Locals = [IR.Local: AST.RegoValue]

// Frame represents a stack frame used during Rego IR evaluation. Each function call
// will prompt creation of a new stack frame.
internal struct Frame {
    var scopeStack: [Ptr<Scope>] = []
    var results: ResultSet = ResultSet()

    init(locals: Locals = [:]) {
        _ = self.pushScope(locals: locals)
    }

    // Create a new Scope, seed with some locals, push it to the stack, and return it.
    mutating func pushScope(
        locals: Locals = [:]
    ) -> Ptr<Scope> {
        let scopePtr = Ptr(toCopyOf: Scope(locals: locals))
        self.scopeStack.append(scopePtr)
        return scopePtr
    }

    // popScope discards the current scope, and returns its parent scope if there is one.
    mutating func popScope() -> Ptr<Scope>? {
        guard self.scopeStack.last != nil else {
            return nil
        }
        self.scopeStack.removeLast()
        return self.scopeStack.last
    }

    func currentScope() throws -> Ptr<Scope> {
        guard !self.scopeStack.isEmpty else {
            throw RegoError(code: .internalError, message: "no scopes remain on the frame")
        }
        return self.scopeStack.last!
    }

    func currentLocation(withContext ctx: IREvaluationContext, stmt: IR.AnyStatement) throws -> OPA.Trace.Location {
        return OPA.Trace.Location(
            row: stmt.location.row,
            col: stmt.location.col,
            file: ctx.policy.ir.staticData?.files?[stmt.location.file].value ?? "<unknown>"
        )
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
            throw RegoError(
                code: .internalError,
                message: "attempted to assign local with no scope on the frame"
            )
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
            throw RegoError(
                code: .invalidOperand,
                message: "unable to resolve static string: \(idx)"
            )
        }
        return v
    }

    func traceEvent(
        withContext ctx: IREvaluationContext,
        op: OPA.Trace.Operation,
        anyStmt: IR.AnyStatement,
        _ message: String = ""
    ) {
        guard let tracer = ctx.ctx.tracer else {
            // tracing disabled
            return
        }
        let formattedMessage = message.isEmpty ? "" : "message='\(message)'"

        let msg: String
        switch op {
        case .enter:
            switch anyStmt {
            case .blockStmt(let stmt):
                let count = stmt.blocks?.count ?? 0

                msg = "block (stmt_count=\(count)): \(stmt.debugString)"
            case .callStmt(let stmt):
                msg = "function \(stmt.callFunc)"
            case .callDynamicStmt(let stmt):
                // Resolve dynamic call path
                let pathStr = resolveDynamicFunctionCallPath(withContext: ctx, path: stmt.path)
                msg = "dynamic function \(pathStr)"
            default:
                if let stmt = anyStmt.statement {
                    msg = "\(type(of: stmt)) - \(stmt.debugString)"
                } else {
                    msg = "<unknown>"
                }
            }
        case .exit:
            switch anyStmt {
            case .blockStmt(let stmt):
                msg = "block \(stmt.debugString)"
            case .callStmt(let stmt):
                msg = "function call \(stmt.callFunc)"
            case .callDynamicStmt(let stmt):
                let pathStr = resolveDynamicFunctionCallPath(withContext: ctx, path: stmt.path)
                msg = "dynamic function \(pathStr)"
            default:
                if let stmt = anyStmt.statement {
                    msg = "\(type(of: stmt)) - \(stmt.debugString)"
                } else {
                    msg = "<unknown>"
                }
            }
        default:
            if let stmt = anyStmt.statement {
                msg = "\(type(of: stmt)) \(formattedMessage) -> \(stmt.debugString)"
            } else {
                msg = "<unknown>"
            }
        }
        let traceLocation = anyStmt.location
        tracer.traceEvent(
            IRTraceEvent(
                operation: op,
                message: msg,
                location: OPA.Trace.Location(
                    row: traceLocation.row,
                    col: traceLocation.col,
                    file: ctx.policy.ir.staticData?.files?[traceLocation.file].value ?? "<unknown>"
                )
            )
        )
    }

    // helper for rendering a dynamic call path into a string
    private func resolveDynamicFunctionCallPath(withContext ctx: IREvaluationContext, path: [IR.Operand]) -> String {
        let path = path.map {
            let v = (try? self.resolveOperand(ctx: ctx, $0)) ?? "<unknown>"
            if case .string(let s) = v {
                return s
            }
            return "<\(v.typeName)>"
        }
        return path.joined(separator: ".")
    }
}

// Scopes are children of a Frame, representing a logical Rego scope. Each time
// a statement has nested blocks a new Scope is pushed. These are primarily used
// for further protecting locals and tracking "with" value overrides.
internal struct Scope: Encodable {
    var locals: Locals

    // Initialize a fresh scope with its own copy of locals
    init(locals: Locals = [:]) {
        self.locals = locals
    }
}

private struct IRTraceEvent: OPA.Trace.TraceableEvent {
    var operation: OPA.Trace.Operation
    var message: String
    var location: OPA.Trace.Location

    // IR Specific stuff
    // Note: this won't be seen in pretty prints but should be dumped in super verbose JSON output
    // TODO: Ideally we can just dump a copy of the scope in here, but it isn't Codable, so for now
    // leave some choice bread crumbs
}

// Evaluate an IR Plan from start to finish for the given IREvaluationContext
private func evalPlan(
    withContext ctx: IREvaluationContext,
    plan: IR.Plan
) async throws -> ResultSet {
    // Initialize the starting Frame+Scope from the top level Plan blocks and kick off evaluation.
    let frame = Frame(
        locals: [
            // TODO: ?? are we going to hide stuff under special roots like OPA does?
            // TODO: We don't resolve refs with more complex paths very much... maybe we should
            // instead special case the DotStmt for local 0 and do a smaller read on the store?
            // ¯\_(ツ)_/¯ for now we'll just drop the whole thang in here as it simplifies the
            // other statments. We can refactor that part later to optimize.
            localIdxInput: ctx.ctx.input,
            localIdxData: try await ctx.ctx.store.read(from: StoreKeyPath(["data"])),
        ]
    )

    let caller = IR.AnyStatement(BlockStatement(blocks: plan.blocks))

    let pFrame = Ptr(toCopyOf: frame)
    return try await evalPlanFrame(withContext: ctx, framePtr: pFrame, blocks: plan.blocks, caller: caller)
}

// Evaluate a plan entrypoint in a Frame from start to finish (respecting Task.isCancelled)
internal func evalPlanFrame(
    withContext ctx: IREvaluationContext,
    framePtr: Ptr<Frame>,
    blocks: [IR.Block],
    caller: IR.AnyStatement
) async throws -> ResultSet {
    var results = ResultSet()

    // To evaluate a Frame we iterate through each block of the current scope, evaluating
    // statements in the block one at a time. We will jump between blocks being executed but
    // never go backwards, only early exit maneuvers jumping "forward" in the plan.
    // ref: https://www.openpolicyagent.org/docs/latest/ir/#execution

    blockLoop: for block in blocks {
        // Evaluate the statements in the block
        let blockResult = try await evalBlock(withContext: ctx, framePtr: framePtr, caller: caller, block: block)
        guard !blockResult.shouldBreak else {
            throw RegoError(code: .internalError, message: "break statement jumped out of frame")
        }
        if blockResult.isUndefined {
            continue
        }
        results.formUnion(blockResult.results)
    }

    return results
}

internal func evalCallFrame(
    withContext ctx: IREvaluationContext,
    framePtr: Ptr<Frame>,
    blocks: [IR.Block],
    caller: IR.AnyStatement
) async throws -> CallFrameResult {
    var result = CallFrameResult.empty
    for block in blocks {
        let blockResult = try await evalBlock(withContext: ctx, framePtr: framePtr, caller: caller, block: block)
        guard !blockResult.shouldBreak else {
            throw RegoError(code: .internalError, message: "break statement jumped out of frame")
        }
        if blockResult.isUndefined {
            continue
        }
        if blockResult.functionReturnValue != nil {
            guard result.functionReturnValue == nil else {
                throw RegoError(code: .internalError, message: "multiple return values from a function")
            }
            result.functionReturnValue = blockResult.functionReturnValue
        }
    }
    return result
}

struct CallFrameResult {
    var results: ResultSet
    var functionReturnValue: AST.RegoValue?

    var undefined: Bool {
        return functionReturnValue == nil
    }

    static var empty: CallFrameResult {
        return .init(results: .empty, functionReturnValue: nil)
    }
}

// BlockResult is the result of evaluating a block.
// In includes any results accumulated in descendent statements of the block,
// as well as an indicator of whether the calling block evaluation should break.
struct BlockResult {
    var results: ResultSet
    var breakCounter: UInt32?
    var functionReturnValue: AST.RegoValue?

    init(results: ResultSet = .empty, breakCounter: UInt32? = nil, functionReturnValue: AST.RegoValue? = nil) {
        self.results = results
        self.breakCounter = breakCounter
        self.functionReturnValue = functionReturnValue
    }

    // Constructs a BlockResult with a single RegoValue in its ResultSet
    init(withResultValue value: AST.RegoValue) {
        self.results = ResultSet(value: value)
    }

    // undefined initializes an undefined BlockResult
    static var undefined: BlockResult {
        return .init(breakCounter: 0)
    }

    // empty initializes an empty BlockResult
    static var empty: BlockResult {
        return .init()
    }

    // isUndefined indicates whether the block evaluated to undefined.
    var isUndefined: Bool {
        return self.breakCounter != nil
    }

    // If shouldBreak is true, evaluation of the calling block should
    // break (by calling breakByOne()).
    var shouldBreak: Bool {
        guard let breakCounter = self.breakCounter else {
            return false
        }
        return breakCounter > 0
    }

    // breakByOne returns a new BlockResult whose breakCounter has been
    // decremented by 1 - this simulates "breaking" one level.
    func breakByOne() -> BlockResult {
        guard let breakCounter = self.breakCounter else {
            return BlockResult(results: self.results, breakCounter: 0)
        }
        return BlockResult(results: self.results, breakCounter: breakCounter - 1)
    }
}

func failWithUndefined(
    withContext ctx: IREvaluationContext,
    framePtr: Ptr<Frame>,
    stmt: IR.AnyStatement
) -> BlockResult {
    framePtr.v.traceEvent(withContext: ctx, op: .fail, anyStmt: stmt, "undefined")
    return .undefined
}

func evalBlock(
    withContext ctx: IREvaluationContext,
    framePtr: Ptr<Frame>,
    caller: IR.AnyStatement,
    block: Block
) async throws -> BlockResult {
    var currentScopePtr = try framePtr.v.currentScope()
    var results = ResultSet.empty

    framePtr.v.traceEvent(withContext: ctx, op: .enter, anyStmt: caller)
    defer { framePtr.v.traceEvent(withContext: ctx, op: .exit, anyStmt: caller) }

    stmtLoop: for (i, statement) in block.statements.enumerated() {

        if Task.isCancelled {
            throw RegoError(code: .evaluationCancelled, message: "parent task cancelled")
        }

        framePtr.v.traceEvent(withContext: ctx, op: .eval, anyStmt: statement)

        switch statement {
        case .arrayAppendStmt(let stmt):
            let array = framePtr.v.resolveLocal(idx: stmt.array)
            let value = try framePtr.v.resolveOperand(ctx: ctx, stmt.value)
            guard case .array(var arrayValue) = array, value != .undefined else {
                return failWithUndefined(withContext: ctx, framePtr: framePtr, stmt: statement)
            }
            arrayValue.append(value)
            try framePtr.v.assignLocal(idx: stmt.array, value: .array(arrayValue))

        case .assignIntStmt(let stmt):
            try framePtr.v.assignLocal(
                idx: stmt.target, value: .number(NSNumber(value: stmt.value)))

        case .assignVarOnceStmt(let stmt):
            // 'undefined' source value doesn't propagate aka don't break out of the block
            let sourceValue = try framePtr.v.resolveOperand(ctx: ctx, stmt.source)
            let targetValue = framePtr.v.resolveLocal(idx: stmt.target)

            // If it's the first time setting target, assign unconditionally
            if targetValue == .undefined {
                try framePtr.v.assignLocal(idx: stmt.target, value: sourceValue)
                break
            }

            // Repeated assignments can only be of the same value, otherwise throw an exception
            if targetValue != sourceValue {
                throw RegoError(code: .assignOnceError, message: "local already assigned with different value")
            }

        case .assignVarStmt(let stmt):
            // 'undefined' source value doesn't propagate: allow
            // assiging undefined to target, and don't affect control flow.
            let sourceValue = try framePtr.v.resolveOperand(ctx: ctx, stmt.source)
            try framePtr.v.assignLocal(idx: stmt.target, value: sourceValue)

        case .blockStmt(let stmt):
            guard let blocks = stmt.blocks else {
                // Some plans emit null blocks for some reason
                // Just skip this statement
                break
            }

            for block in blocks {
                let rs = try await evalBlock(withContext: ctx, framePtr: framePtr, caller: statement, block: block)
                if rs.shouldBreak {
                    return rs.breakByOne()
                }

                // Individual undefined blocks within the BlockStmt do not
                // make the whole BlockStmt undefined - we simply continue
                // to the next internal block.
                if rs.isUndefined {
                    continue
                }
                results.formUnion(rs.results)
            }

        case .breakStmt(let stmt):
            // Index is the index of the block to jump out of starting with zero representing
            // the current block and incrementing by one for each outer block.
            // (https://www.openpolicyagent.org/docs/latest/ir/#breakstmt)
            //
            // Callers of evalBlock should check BlockResult.shouldBreak and if true,
            // return after calling BlockResult.breakByOne() to decrement the counter.
            return BlockResult(results: results, breakCounter: stmt.index)

        case .callDynamicStmt(let stmt):
            var path: [String] = []
            for p in stmt.path {
                let segment = try framePtr.v.resolveOperand(ctx: ctx, p)
                guard case .string(let stringValue) = segment else {
                    return failWithUndefined(withContext: ctx, framePtr: framePtr, stmt: statement)
                }
                path.append(stringValue)
            }

            let funcName = path.joined(separator: ".")

            let result = try await evalCall(
                ctx: ctx,
                frame: framePtr,
                caller: statement,
                funcName: funcName,
                args: stmt.args.map {  // (╯°□°)╯︵ ┻━┻
                    // TODO: make the CallDynamicStatement "args" match the CallStatement ones upstream..
                    IR.Operand(
                        type: Operand.OpType.local, value: Operand.Value.localIndex(Int($0)))
                },
                isDynamic: true
            )

            guard result != .undefined else {
                return failWithUndefined(withContext: ctx, framePtr: framePtr, stmt: statement)
            }

            try framePtr.v.assignLocal(idx: stmt.result, value: result)

        case .callStmt(let stmt):
            let result = try await evalCall(
                ctx: ctx,
                frame: framePtr,
                caller: statement,
                funcName: stmt.callFunc,
                args: stmt.args ?? []
            )

            guard result != .undefined else {
                return failWithUndefined(withContext: ctx, framePtr: framePtr, stmt: statement)
            }

            try framePtr.v.assignLocal(idx: stmt.result, value: result)

        case .dotStmt(let stmt):
            let sourceValue = try framePtr.v.resolveOperand(ctx: ctx, stmt.source)
            let keyValue = try framePtr.v.resolveOperand(ctx: ctx, stmt.key)

            // If any input parameter is undefined then the statement is undefined
            guard sourceValue != .undefined, keyValue != .undefined else {
                return failWithUndefined(withContext: ctx, framePtr: framePtr, stmt: statement)
            }

            var targetValue: AST.RegoValue?
            switch sourceValue {
            case .object(let sourceObj):
                targetValue = sourceObj[keyValue]
            case .array(let sourceArray):
                if case .number(let numberValue) = keyValue {
                    let idx = numberValue.intValue
                    if idx < 0 || idx >= sourceArray.count {
                        break
                    }
                    targetValue = sourceArray[idx]
                }
            case .set(let sourceSet):
                if sourceSet.contains(keyValue) {
                    targetValue = keyValue
                }
            default:
                // Dot on non-collections is undefined
                break
            }

            // This statement is undefined if the key does not exist in the source value.
            guard let targetValue else {
                // undefined
                return failWithUndefined(withContext: ctx, framePtr: framePtr, stmt: statement)
            }
            try framePtr.v.assignLocal(idx: stmt.target, value: targetValue)

        case .equalStmt(let stmt):
            // This statement is undefined if a is not equal to b.
            let a = try framePtr.v.resolveOperand(ctx: ctx, stmt.a)
            let b = try framePtr.v.resolveOperand(ctx: ctx, stmt.b)
            if a == .undefined || b == .undefined || a != b {
                return failWithUndefined(withContext: ctx, framePtr: framePtr, stmt: statement)
            }

        case .isArrayStmt(let stmt):
            guard case .array = try framePtr.v.resolveOperand(ctx: ctx, stmt.source) else {
                return failWithUndefined(withContext: ctx, framePtr: framePtr, stmt: statement)
            }

        case .isDefinedStmt(let stmt):
            // This statement is undefined if source is undefined.
            if case .undefined = framePtr.v.resolveLocal(idx: stmt.source) {
                return failWithUndefined(withContext: ctx, framePtr: framePtr, stmt: statement)
            }

        case .isObjectStmt(let stmt):
            guard case .object = try framePtr.v.resolveOperand(ctx: ctx, stmt.source) else {
                return failWithUndefined(withContext: ctx, framePtr: framePtr, stmt: statement)
            }

        case .isSetStmt(let stmt):
            guard case .set = try framePtr.v.resolveOperand(ctx: ctx, stmt.source) else {
                return failWithUndefined(withContext: ctx, framePtr: framePtr, stmt: statement)
            }

        case .isUndefinedStmt(let stmt):
            // This statement is undefined if source is not undefined.
            guard case .undefined = framePtr.v.resolveLocal(idx: stmt.source) else {
                return failWithUndefined(withContext: ctx, framePtr: framePtr, stmt: statement)
            }

        case .lenStmt(let stmt):
            let sourceValue = try framePtr.v.resolveOperand(ctx: ctx, stmt.source)
            guard sourceValue != .undefined else {
                return failWithUndefined(withContext: ctx, framePtr: framePtr, stmt: statement)
            }

            guard let len = sourceValue.count else {
                throw RegoError(
                    code: .invalidDataType,
                    message: """
                        LenStmt invalid on provided operand type. got: \(sourceValue.typeName), \
                        want: (array|object|string|set)
                        """
                )
            }

            try framePtr.v.assignLocal(idx: stmt.target, value: .number(NSNumber(value: len)))

        case .makeArrayStmt(let stmt):
            var arr: [AST.RegoValue] = []
            arr.reserveCapacity(Int(stmt.capacity))
            try framePtr.v.assignLocal(idx: stmt.target, value: .array(arr))

        case .makeNullStmt(let stmt):
            try framePtr.v.assignLocal(idx: stmt.target, value: .null)

        case .makeNumberIntStmt(let stmt):
            try framePtr.v.assignLocal(
                idx: stmt.target, value: .number(NSNumber(value: stmt.value)))

        case .makeNumberRefStmt(let stmt):
            let sourceStringValue = try framePtr.v.resolveStaticString(
                ctx: ctx, Int(stmt.index))
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            guard let n = formatter.number(from: sourceStringValue) else {
                throw RegoError(code: .invalidDataType, message: "invalid number literal with MakeNumberRefStatement")
            }
            try framePtr.v.assignLocal(idx: stmt.target, value: .number(n))

        case .makeObjectStmt(let stmt):
            try framePtr.v.assignLocal(idx: stmt.target, value: .object([:]))

        case .makeSetStmt(let stmt):
            try framePtr.v.assignLocal(idx: stmt.target, value: .set([]))

        case .nopStmt:
            break

        case .notEqualStmt(let stmt):
            // This statement is undefined if a is equal to b.
            let a = try framePtr.v.resolveOperand(ctx: ctx, stmt.a)
            let b = try framePtr.v.resolveOperand(ctx: ctx, stmt.b)
            if a == .undefined || b == .undefined || a == b {
                return failWithUndefined(withContext: ctx, framePtr: framePtr, stmt: statement)
            }

        case .notStmt(let stmt):
            // We're going to evalaute the block in an isolated frame, propagating
            // local state, so that we can more easily see whether it succeeded.
            let rs = try await evalBlock(withContext: ctx, framePtr: framePtr, caller: statement, block: stmt.block)

            if rs.shouldBreak {
                return rs.breakByOne()
            }

            // This statement is undefined if the contained block is defined.
            guard rs.isUndefined else {
                return failWithUndefined(withContext: ctx, framePtr: framePtr, stmt: statement)
            }

            // Propagate any results from the block's sub frame into the parent frame
            // TODO is this correct?
            results.formUnion(rs.results)

        case .objectInsertOnceStmt(let stmt):
            let targetValue = try framePtr.v.resolveOperand(ctx: ctx, stmt.value)
            let key = try framePtr.v.resolveOperand(ctx: ctx, stmt.key)
            let target = framePtr.v.resolveLocal(idx: stmt.object)
            guard targetValue != .undefined && key != .undefined && target != .undefined else {
                return failWithUndefined(withContext: ctx, framePtr: framePtr, stmt: statement)
            }
            guard case .object(var targetObjectValue) = target else {
                throw RegoError(
                    code: .invalidDataType,
                    message: "unable to perform ObjectInsertStatement on target value of type \(target.typeName))"
                )
            }

            // The rules: Either this key has not been set (currentValue==nil),
            // _or_ it has, but the old value must be equal to the new value
            let currentValue = targetObjectValue[key]
            guard currentValue == nil || currentValue! == targetValue else {
                throw RegoError(
                    code: .objectInsertOnceError,
                    message: "key '\(key)' already exists in object with different value"
                )
            }
            targetObjectValue[key] = targetValue
            try framePtr.v.assignLocal(idx: stmt.object, value: .object(targetObjectValue))

        case .objectInsertStmt(let stmt):
            let value = try framePtr.v.resolveOperand(ctx: ctx, stmt.value)
            let key = try framePtr.v.resolveOperand(ctx: ctx, stmt.key)
            let target = framePtr.v.resolveLocal(idx: stmt.object)
            guard value != .undefined && key != .undefined && target != .undefined else {
                return failWithUndefined(withContext: ctx, framePtr: framePtr, stmt: statement)
            }
            guard case .object(var targetObjectValue) = target else {
                throw RegoError(
                    code: .invalidDataType,
                    message: "unable to perform ObjectInsertStatement on target value of type \(target.typeName))"
                )
            }
            targetObjectValue[key] = value
            try framePtr.v.assignLocal(idx: stmt.object, value: .object(targetObjectValue))

        case .objectMergeStmt(let stmt):
            let a = framePtr.v.resolveLocal(idx: stmt.a)
            let b = framePtr.v.resolveLocal(idx: stmt.b)
            if a == .undefined || b == .undefined {
                return failWithUndefined(withContext: ctx, framePtr: framePtr, stmt: statement)
            }
            guard case .object(let objectValueA) = a, case .object(let objectValueB) = b else {
                throw RegoError(
                    code: .invalidDataType,
                    message: "unable to perform ObjectMergeStatement with types \(a.typeName)) and \(b.typeName))"
                )
            }

            // The IR spec says object B is merged in to object A.. however, it seems that
            // the values in A need to take precedence, so we'll merge it in to B.
            // Some context:
            // - https://github.com/open-policy-agent/opa/issues/2926
            // - https://github.com/open-policy-agent/opa/pull/3017
            let merged = objectValueB.merge(with: objectValueA)
            try framePtr.v.assignLocal(idx: stmt.target, value: .object(merged))

        case .resetLocalStmt(let stmt):
            try framePtr.v.assignLocal(idx: stmt.target, value: .undefined)

        case .resultSetAddStmt(let stmt):
            guard i == block.statements.count - 1 else {
                // TODO can this be a warning?
                throw RegoError(
                    code: .internalError,
                    message: "ResultSetAddStatement can only be used in the last statement of a block"
                )
            }
            let value = framePtr.v.resolveLocal(idx: stmt.value)
            guard value != .undefined else {
                return failWithUndefined(withContext: ctx, framePtr: framePtr, stmt: statement)
            }
            return BlockResult(withResultValue: value)

        case .returnLocalStmt(let stmt):
            return BlockResult(functionReturnValue: framePtr.v.resolveLocal(idx: stmt.source))

        case .scanStmt(let stmt):
            // From the spec: "This statement is undefined if source is a scalar value or empty collection."
            // ...but from jarl (https://github.com/borgeby/jarl/blob/02262bde6553c6b3cd9325e6c1593dded13fa753/core/src/main/cljc/jarl/eval.cljc#L322C61-L323C10)
            //   "OPA IR docs states 'source' may not be an empty collection;
            //   but if we 'break' for such, statements like 'every x in [] { x != x }' will be 'undefined'."
            // Also - "If the domain is empty, the overall statement is true."
            //  ref: https://www.openpolicyagent.org/docs/latest/policy-language/#every-keyword
            // After clarification, the correct behavior should be: "This statement is undefined if the source is a scalar or undefined.",
            // i.e. we need to ensure it is a collection type, but empty is allowed.
            let source = framePtr.v.resolveLocal(idx: stmt.source)

            // Ensure the source is defined and not a scalar type
            guard source != .undefined, source.isCollection else {
                return failWithUndefined(withContext: ctx, framePtr: framePtr, stmt: statement)
            }

            let rs = try await evalScan(
                ctx: ctx,
                frame: framePtr,
                stmt: stmt,
                source: source
            )

            // Propagate any results from the block's sub frame into the parent frame
            results.formUnion(rs)

        case .setAddStmt(let stmt):
            let value = try framePtr.v.resolveOperand(ctx: ctx, stmt.value)
            let target = framePtr.v.resolveLocal(idx: stmt.set)
            guard value != .undefined && target != .undefined else {
                return failWithUndefined(withContext: ctx, framePtr: framePtr, stmt: statement)
            }
            guard case .set(var targetSetValue) = target else {
                throw RegoError(
                    code: .invalidDataType,
                    message: "unable to perform SetAddStatement on target value of type \(target.typeName)"
                )
            }
            targetSetValue.insert(value)
            try framePtr.v.assignLocal(idx: stmt.set, value: .set(targetSetValue))

        case .withStmt(let stmt):
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
                throw RegoError(
                    code: .internalError,
                    message: "invalid path - some segments could not resolve to strings"
                )
            }

            let patched = toPatch.patch(with: overlayValue, at: path)

            // Push a new scope that includes that patched local (likely shadowing a previous
            // scopes values) and start evaluating the new block
            var newLocals = currentScopePtr.v.locals
            newLocals[stmt.local] = patched
            currentScopePtr = framePtr.v.pushScope(locals: newLocals)
            // Start executing the block on the new scope we just pushed
            let blockResult = try await evalBlock(
                withContext: ctx,
                framePtr: framePtr,
                caller: statement,
                block: stmt.block
            )

            // Squash locals from the child frame back into the current frame.
            // Overlay the original (non-patched) value, keep the other side-effects.
            let _ = try popAndSquash(frame: framePtr)
            try framePtr.v.assignLocal(idx: stmt.local, value: toPatch)

            // Respect the break index from a sub block
            if blockResult.shouldBreak {
                return blockResult.breakByOne()
            }

            // Propagate undefined
            if blockResult.isUndefined {
                return failWithUndefined(withContext: ctx, framePtr: framePtr, stmt: statement)
            }

            results.formUnion(blockResult.results)

        case .unknown(let location):
            // Included for completeness, but this won't happen in practice as IR.Block's
            // decoder will have already failed to parse any unknown statements.
            throw RegoError(code: .internalError, message: "unexpected statement at location: \(location)")
        }

        // Next statement of current block
    }

    // If no ResultSetAddStmt statements are executed, the implicit result set is empty.
    return BlockResult(results: results)
}

private func evalCall(
    ctx: IREvaluationContext,
    frame: Ptr<Frame>,
    caller: IR.AnyStatement,
    funcName: String,
    args: [IR.Operand],
    isDynamic: Bool = false
) async throws -> AST.RegoValue {
    var argValues: [AST.RegoValue] = []
    for arg in args {
        // Note: we do not enforce that args are defined here, it appears
        // that the expectation is that statements within the function blocks
        // (for non-builtins) handle it.
        argValues.append(try frame.v.resolveOperand(ctx: ctx, arg))
    }

    if isDynamic {
        // CallDynamicStmt doesn't reference functions by name (as labeled in the IR), it will be by path,
        // eg, ["g0", "a", "b"] versus the "name" like "g0.data.a.b"
        // We strigify the path first so they come in here looking like "g0.a.b".
        // If the function is not found in the policy, it is valid but undefined.
        guard let funcName = ctx.policy.funcsPathToName[funcName] else {
            return .undefined
        }

        return try await callPlanFunc(
            ctx: ctx,
            frame: frame,
            caller: caller,
            funcName: funcName,
            args: argValues
        )
    }

    // Handle plan-defined functions first
    if ctx.policy.funcs[funcName] != nil {
        return try await callPlanFunc(
            ctx: ctx,
            frame: frame,
            caller: caller,
            funcName: funcName,
            args: argValues
        )
    }

    // Handle built-in functions last

    // We won't bother invoking the builtin function if one of the arguments is undefined
    for argValue in argValues {
        guard argValue != .undefined else {
            return .undefined
        }
    }

    let bctx = BuiltinContext(
        location: try frame.v.currentLocation(withContext: ctx, stmt: caller),
        tracer: ctx.ctx.tracer
    )

    return try await ctx.ctx.builtins.invoke(
        withContext: bctx,
        name: funcName,
        args: argValues,
        strict: ctx.ctx.strictBuiltins
    )
}

// callPlanFunc will evaluate calling a function defined on the plan
private func callPlanFunc(
    ctx: IREvaluationContext,
    frame: Ptr<Frame>,
    caller: IR.AnyStatement,
    funcName: String,
    args: [AST.RegoValue]
) async throws -> AST.RegoValue {
    guard let fn = ctx.policy.funcs[funcName] else {
        throw RegoError(code: .internalError, message: "function definition not found: \(funcName)")
    }
    guard fn.params.count == args.count else {
        throw RegoError(code: .internalError, message: "mismatched argument count for function \(funcName)")
    }
    guard ctx.callDepth < ctx.maxCallDepth else {
        throw RegoError(code: .maxCallDepthExceeded, message: "maximum call depth exceeded: \(ctx.callDepth)")
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
    callLocals[localIdxData] = frame.v.resolveLocal(idx: localIdxData)

    // Setup a new frame for the function call
    let callFrame = Frame(
        locals: callLocals
    )
    let callFramePtr = Ptr(toCopyOf: callFrame)
    let result = try await evalCallFrame(
        withContext: ctx.withIncrementedCallDepth(),
        framePtr: callFramePtr,
        blocks: fn.blocks,
        caller: caller
    )

    return result.functionReturnValue ?? .undefined
}

private func evalScan(
    ctx: IREvaluationContext,
    frame: Ptr<Frame>,
    stmt: ScanStatement,
    source: AST.RegoValue
) async throws -> ResultSet {
    var results: ResultSet = []
    switch source {
    case .array(let arr):
        for i in 0..<arr.count {
            let k: AST.RegoValue = .number(NSNumber(value: i))
            let v = arr[i] as AST.RegoValue
            let rs = try await evalScanBlock(ctx: ctx, frame: frame, stmt: stmt, key: k, value: v)
            results.formUnion(rs)
        }
    case .object(let o):
        for (k, v) in o {
            let rs = try await evalScanBlock(ctx: ctx, frame: frame, stmt: stmt, key: k, value: v)
            results.formUnion(rs)
        }
    case .set(let set):
        for v in set {
            let rs = try await evalScanBlock(ctx: ctx, frame: frame, stmt: stmt, key: v, value: v)
            results.formUnion(rs)
        }
    default:
        return []
    }
    return results
}

private func evalScanBlock(
    ctx: IREvaluationContext,
    frame: Ptr<Frame>,
    stmt: ScanStatement,
    key: AST.RegoValue,
    value: AST.RegoValue
) async throws -> ResultSet {
    var currentScopePtr = try frame.v.currentScope()
    var newLocals = currentScopePtr.v.locals
    newLocals[stmt.key] = key
    newLocals[stmt.value] = value
    currentScopePtr = frame.v.pushScope(locals: newLocals)
    // Start executing the block on the new scope we just pushed
    let rs = try await evalBlock(
        withContext: ctx,
        framePtr: frame,
        caller: IR.AnyStatement(stmt),
        block: stmt.block
    )

    // Copy out any locals set on the nested block and put the scope back
    let updatedLocals = currentScopePtr.v.locals
    guard let parentScope = frame.v.popScope() else {
        throw RegoError(code: .internalError, message: "scope stack exhausted")
    }
    parentScope.v.locals = updatedLocals
    return rs.results
}

// popAndSquash pops the current scope off the stack, and squashes its locals into its parent
// Returns the new current scope.
private func popAndSquash(frame: Ptr<Frame>) throws -> Ptr<Scope> {
    let scope = try frame.v.currentScope()
    let currentLocals = scope.v.locals

    guard let parentScope = frame.v.popScope() else {
        throw RegoError(code: .internalError, message: "scope stack exhausted")
    }

    // Propagate any modified locals from the scope we just popped off
    parentScope.v.locals = currentLocals
    return parentScope
}
