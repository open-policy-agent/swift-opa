import AST
import Foundation
import IR

let localIdxInput = Local(0)
let localIdxData = Local(1)

// Singleton NumberFormatter for parsing number literals - avoids expensive per-call initialization
private let numberFormatter: NumberFormatter = {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    return formatter
}()

internal struct IREvaluator {
    let policies: [IndexedIRPolicy]

    init(bundles: [String: OPA.Bundle]) throws {
        var policies: [IndexedIRPolicy] = []
        for (bundleName, bundle) in bundles {
            for planFile in bundle.planFiles {
                do {
                    let parsed = try IR.Policy(jsonData: planFile.data)
                    policies.append(IndexedIRPolicy(policy: parsed))
                } catch {
                    throw RegoError(
                        code: .bundleInitializationError,
                        message: """
                            initialization failed for bundle \(bundleName), \
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
        self.policies = policies
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
                try await evalPlan(withContext: ctx, plan: plan)
                return ctx.results
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
        var preparedPolicy = policy
        preparedPolicy.prepareForExecution()

        self.ir = preparedPolicy
        for plan in preparedPolicy.plans?.plans ?? [] {
            // TODO: is plan.name actually the right string format to
            // match a query string? If no, convert it here.
            // TODO: validator should ensure these names were unique
            self.plans[plan.name] = plan
        }
        for funcDecl in preparedPolicy.funcs?.funcs ?? [] {
            // TODO: validator should ensure these names were unique
            self.funcs[funcDecl.name] = funcDecl
            if !funcDecl.path.isEmpty {
                self.funcsPathToName[funcDecl.path.joined(separator: ".")] = funcDecl.name
            }
        }
        for string in preparedPolicy.staticData?.strings ?? [] {
            // Normalize to contiguous UTF-8 for faster string comparisons
            self.staticStrings.append(String(decoding: string.value.utf8, as: UTF8.self))
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

internal final class IREvaluationContext {
    var ctx: EvaluationContext
    var policy: IndexedIRPolicy
    var maxCallDepth: Int = 16_384
    var callDepth: Int = 0
    var memoStack = MemoStack()
    var results: ResultSet
    var locals: Locals = Locals(repeating: nil, count: 2)

    init(ctx: EvaluationContext, policy: IndexedIRPolicy) {
        self.ctx = ctx
        self.policy = policy
        self.results = ResultSet.empty
    }

    func currentLocation(stmt: IR.Statement) throws -> OPA.Trace.Location {
        return OPA.Trace.Location(
            row: stmt.location.row,
            col: stmt.location.col,
            file: policy.ir.staticData?.files?[stmt.location.file].value ?? "<unknown>"
        )
    }

    func resolveLocal(idx: IR.Local) -> AST.RegoValue {
        return self.locals[idx] ?? .undefined
    }

    func assignLocal(idx: IR.Local, value: AST.RegoValue) {
        self.locals[idx] = value
    }

    // TODO, should we throw or return optional on lookup failures?
    func resolveOperand(_ op: IR.Operand) throws -> AST.RegoValue {
        switch op.value {
        case .localIndex(let idx):
            return resolveLocal(idx: Local(idx))
        case .bool(let boolValue):
            return .boolean(boolValue)
        case .stringIndex(let idx):
            return try .string(resolveStaticString(Int(idx)))
        }
    }

    func resolveStaticString(_ idx: Int) throws -> String {
        guard let v = policy.resolveStaticString(idx) else {
            throw RegoError(
                code: .invalidOperand,
                message: "unable to resolve static string: \(idx)"
            )
        }
        return v
    }

    func traceEvent(
        op: OPA.Trace.Operation,
        anyStmt: IR.Statement,
        _ message: String = ""
    ) {
        guard let tracer = ctx.tracer else {
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

                msg = "block (stmt_count=\(count)): \(anyStmt.debugString)"
            case .callStmt(let stmt):
                msg = "function \(stmt.callFunc)"
            case .callDynamicStmt(let stmt):
                // Resolve dynamic call path
                let pathStr = resolveDynamicFunctionCallPath(path: stmt.path)
                msg = "dynamic function \(pathStr)"
            default:
                msg = "\(anyStmt) - \(anyStmt.debugString)"
            }
        case .exit:
            switch anyStmt {
            case .blockStmt:
                msg = "block \(anyStmt.debugString)"
            case .callStmt(let stmt):
                msg = "function call \(stmt.callFunc)"
            case .callDynamicStmt(let stmt):
                // Resolve dynamic call path
                let pathStr = resolveDynamicFunctionCallPath(path: stmt.path)
                msg = "dynamic function \(pathStr)"
            default:
                msg = "\(anyStmt) - \(anyStmt.debugString)"
            }
        default:
            msg = "\(anyStmt) \(formattedMessage) -> \(anyStmt.debugString)"
        }
        let traceLocation = anyStmt.location
        tracer.traceEvent(
            IRTraceEvent(
                operation: op,
                message: msg,
                location: OPA.Trace.Location(
                    row: traceLocation.row,
                    col: traceLocation.col,
                    file: policy.ir.staticData?.files?[traceLocation.file].value ?? "<unknown>"
                )
            )
        )
    }

    // Helper for rendering a dynamic call path into a string
    private func resolveDynamicFunctionCallPath(path: [IR.Operand]) -> String {
        let path = path.map {
            let v = (try? self.resolveOperand($0)) ?? "<unknown>"
            if case .string(let s) = v {
                return s
            }
            return "<\(v.typeName)>"
        }
        return path.joined(separator: ".")
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
) async throws {
    // Initialize the starting scope from the top level Plan blocks and kick off evaluation.
    // Create initial locals with input at index 0 and data at index 1

    // Pre-allocate locals to exact size needed for this plan (computed via static analysis)
    ctx.locals = Locals(repeating: nil, count: max(plan.maxLocal + 1, 2))

    // TODO: ?? are we going to hide stuff under special roots like OPA does?
    // TODO: We don't resolve refs with more complex paths very much... maybe we should
    // instead special case the DotStmt for local 0 and do a smaller read on the store?
    // ¯\_(ツ)_/¯ for now we'll just drop the whole thang in here as it simplifies the
    // other statements. We can refactor that part later to optimize.
    ctx.locals[localIdxInput] = ctx.ctx.input  // localIdxInput = 0
    ctx.locals[localIdxData] = try await ctx.ctx.store.read(from: StoreKeyPath(["data"]))  // localIdxData = 1

    let caller = IR.Statement.blockStmt(BlockStatement(blocks: plan.blocks))

    // To evaluate a plan we iterate through each block of the current scope, evaluating
    // statements in the block one at a time. We will jump between blocks being executed but
    // never go backwards, only early exit maneuvers jumping "forward" in the plan.
    // ref: https://www.openpolicyagent.org/docs/latest/ir/#execution

    blockLoop: for block in plan.blocks {
        let blockResult = try await evalBlock(withContext: ctx, caller: caller, block: block)
        guard !blockResult.shouldBreak else {
            throw RegoError(code: .internalError, message: "break statement jumped out of frame")
        }
        if blockResult.isUndefined {
            continue
        }
    }
}

internal func evalBlocks(
    withContext ctx: IREvaluationContext,
    blocks: [IR.Block],
    caller: IR.Statement
) async throws -> CallResult {
    var result = CallResult.empty
    for block in blocks {
        let blockResult = try await evalBlock(withContext: ctx, caller: caller, block: block)
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

struct CallResult {
    var functionReturnValue: AST.RegoValue?

    var undefined: Bool {
        return functionReturnValue == nil
    }

    static var empty: CallResult {
        return .init(functionReturnValue: nil)
    }
}

// BlockResult is the result of evaluating a block.
// It contains control flow information (break counter and function return value).
struct BlockResult {
    var breakCounter: UInt32?
    var functionReturnValue: AST.RegoValue?

    init(breakCounter: UInt32? = nil, functionReturnValue: AST.RegoValue? = nil) {
        self.breakCounter = breakCounter
        self.functionReturnValue = functionReturnValue
    }

    // undefined initializes an undefined BlockResult
    static var undefined: BlockResult {
        return .init(breakCounter: 0)
    }

    // empty initializes an empty BlockResult
    static var empty: BlockResult {
        return .init()
    }

    static var success: BlockResult {
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
            return BlockResult(breakCounter: 0)
        }
        return BlockResult(breakCounter: breakCounter - 1)
    }
}

func failWithUndefined(
    withContext ctx: IREvaluationContext,
    stmt: IR.Statement
) -> BlockResult {
    ctx.traceEvent(op: .fail, anyStmt: stmt, "undefined")
    return .undefined
}

func evalBlock(
    withContext ctx: IREvaluationContext,
    caller: IR.Statement,
    block: Block
) async throws -> BlockResult {

    ctx.traceEvent(op: .enter, anyStmt: caller)
    defer { ctx.traceEvent(op: .exit, anyStmt: caller) }

    stmtLoop: for i in block.statements.indices {
        let statement = block.statements[i]

        if Task.isCancelled {
            throw RegoError(code: .evaluationCancelled, message: "parent task cancelled")
        }

        ctx.traceEvent(op: .eval, anyStmt: statement)

        switch statement {
        case .arrayAppendStmt(let stmt):
            let array = ctx.resolveLocal(idx: stmt.array)
            let value = try ctx.resolveOperand(stmt.value)
            guard case .array(var arrayValue) = array, value != .undefined else {
                return failWithUndefined(withContext: ctx, stmt: statement)
            }
            arrayValue.append(value)
            ctx.assignLocal(idx: stmt.array, value: .array(arrayValue))

        case .assignIntStmt(let stmt):
            ctx.assignLocal(
                idx: stmt.target, value: .number(NSNumber(value: stmt.value)))

        case .assignVarOnceStmt(let stmt):
            // 'undefined' source value doesn't propagate aka don't break out of the block
            let sourceValue = try ctx.resolveOperand(stmt.source)
            let targetValue = ctx.resolveLocal(idx: stmt.target)

            // If it's the first time setting target, assign unconditionally
            if targetValue == .undefined {
                ctx.assignLocal(idx: stmt.target, value: sourceValue)
                break
            }

            // Repeated assignments can only be of the same value, otherwise throw an exception
            if targetValue != sourceValue {
                throw RegoError(code: .assignOnceError, message: "local already assigned with different value")
            }

        case .assignVarStmt(let stmt):
            // 'undefined' source value doesn't propagate: allow
            // assiging undefined to target, and don't affect control flow.
            let sourceValue = try ctx.resolveOperand(stmt.source)
            ctx.assignLocal(idx: stmt.target, value: sourceValue)

        case .blockStmt(let stmt):
            guard let blocks = stmt.blocks else {
                // Some plans emit null blocks for some reason
                // Just skip this statement
                break
            }

            for block in blocks {
                let rs = try await evalBlock(withContext: ctx, caller: statement, block: block)
                if rs.shouldBreak {
                    return rs.breakByOne()
                }

                // Individual undefined blocks within the BlockStmt do not
                // make the whole BlockStmt undefined - we simply continue
                // to the next internal block.
                if rs.isUndefined {
                    continue
                }
            }

        case .breakStmt(let stmt):
            // Index is the index of the block to jump out of starting with zero representing
            // the current block and incrementing by one for each outer block.
            // (https://www.openpolicyagent.org/docs/latest/ir/#breakstmt)
            //
            // Callers of evalBlock should check BlockResult.shouldBreak and if true,
            // return after calling BlockResult.breakByOne() to decrement the counter.
            return BlockResult(breakCounter: stmt.index)

        case .callDynamicStmt(let stmt):
            var funcName = ""
            for i in stmt.path.indices {
                let p = stmt.path[i]
                let segment = try ctx.resolveOperand(p)
                guard case .string(let stringValue) = segment else {
                    return failWithUndefined(withContext: ctx, stmt: statement)
                }
                if i > 0 {
                    funcName += "."
                }
                funcName += stringValue
            }

            let result = try await evalCall(
                ctx: ctx,
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
                return failWithUndefined(withContext: ctx, stmt: statement)
            }

            ctx.assignLocal(idx: stmt.result, value: result)

        case .callStmt(let stmt):
            let result = try await evalCall(
                ctx: ctx,
                caller: statement,
                funcName: stmt.callFunc,
                args: stmt.args ?? []
            )

            guard result != .undefined else {
                return failWithUndefined(withContext: ctx, stmt: statement)
            }

            ctx.assignLocal(idx: stmt.result, value: result)

        case .dotStmt(let stmt):
            let sourceValue = try ctx.resolveOperand(stmt.source)
            let keyValue = try ctx.resolveOperand(stmt.key)

            // If any input parameter is undefined then the statement is undefined
            guard sourceValue != .undefined, keyValue != .undefined else {
                return failWithUndefined(withContext: ctx, stmt: statement)
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
                return failWithUndefined(withContext: ctx, stmt: statement)
            }
            ctx.assignLocal(idx: stmt.target, value: targetValue)

        case .equalStmt(let stmt):
            // This statement is undefined if a is not equal to b.
            let a = try ctx.resolveOperand(stmt.a)
            let b = try ctx.resolveOperand(stmt.b)
            if a == .undefined || b == .undefined || a != b {
                return failWithUndefined(withContext: ctx, stmt: statement)
            }

        case .isArrayStmt(let stmt):
            guard case .array = try ctx.resolveOperand(stmt.source) else {
                return failWithUndefined(withContext: ctx, stmt: statement)
            }

        case .isDefinedStmt(let stmt):
            // This statement is undefined if source is undefined.
            if case .undefined = ctx.resolveLocal(idx: stmt.source) {
                return failWithUndefined(withContext: ctx, stmt: statement)
            }

        case .isObjectStmt(let stmt):
            guard case .object = try ctx.resolveOperand(stmt.source) else {
                return failWithUndefined(withContext: ctx, stmt: statement)
            }

        case .isSetStmt(let stmt):
            guard case .set = try ctx.resolveOperand(stmt.source) else {
                return failWithUndefined(withContext: ctx, stmt: statement)
            }

        case .isUndefinedStmt(let stmt):
            // This statement is undefined if source is not undefined.
            guard case .undefined = ctx.resolveLocal(idx: stmt.source) else {
                return failWithUndefined(withContext: ctx, stmt: statement)
            }

        case .lenStmt(let stmt):
            let sourceValue = try ctx.resolveOperand(stmt.source)
            guard sourceValue != .undefined else {
                return failWithUndefined(withContext: ctx, stmt: statement)
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

            ctx.assignLocal(idx: stmt.target, value: .number(NSNumber(value: len)))

        case .makeArrayStmt(let stmt):
            var arr: [AST.RegoValue] = []
            arr.reserveCapacity(Int(stmt.capacity))
            ctx.assignLocal(idx: stmt.target, value: .array(arr))

        case .makeNullStmt(let stmt):
            ctx.assignLocal(idx: stmt.target, value: .null)

        case .makeNumberIntStmt(let stmt):
            ctx.assignLocal(
                idx: stmt.target, value: .number(NSNumber(value: stmt.value)))

        case .makeNumberRefStmt(let stmt):
            let sourceStringValue = try ctx.resolveStaticString(
                Int(stmt.index))
            guard let n = numberFormatter.number(from: sourceStringValue) else {
                throw RegoError(code: .invalidDataType, message: "invalid number literal with MakeNumberRefStatement")
            }
            ctx.assignLocal(idx: stmt.target, value: .number(n))

        case .makeObjectStmt(let stmt):
            ctx.assignLocal(idx: stmt.target, value: .object([:]))

        case .makeSetStmt(let stmt):
            ctx.assignLocal(idx: stmt.target, value: .set([]))

        case .nopStmt:
            break

        case .notEqualStmt(let stmt):
            // This statement is undefined if a is equal to b.
            let a = try ctx.resolveOperand(stmt.a)
            let b = try ctx.resolveOperand(stmt.b)
            if a == .undefined || b == .undefined || a == b {
                return failWithUndefined(withContext: ctx, stmt: statement)
            }

        case .notStmt(let stmt):
            // We're going to evalaute the block in an isolated frame, propagating
            // local state, so that we can more easily see whether it succeeded.
            let rs = try await evalBlock(withContext: ctx, caller: statement, block: stmt.block)

            if rs.shouldBreak {
                return rs.breakByOne()
            }

            // This statement is undefined if the contained block is defined.
            guard rs.isUndefined else {
                return failWithUndefined(withContext: ctx, stmt: statement)
            }

        case .objectInsertOnceStmt(let stmt):
            let targetValue = try ctx.resolveOperand(stmt.value)
            let key = try ctx.resolveOperand(stmt.key)
            let target = ctx.resolveLocal(idx: stmt.object)
            guard targetValue != .undefined && key != .undefined && target != .undefined else {
                return failWithUndefined(withContext: ctx, stmt: statement)
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
            ctx.assignLocal(idx: stmt.object, value: .object(targetObjectValue))

        case .objectInsertStmt(let stmt):
            let value = try ctx.resolveOperand(stmt.value)
            let key = try ctx.resolveOperand(stmt.key)
            let target = ctx.resolveLocal(idx: stmt.object)
            guard value != .undefined && key != .undefined && target != .undefined else {
                return failWithUndefined(withContext: ctx, stmt: statement)
            }
            guard case .object(var targetObjectValue) = target else {
                throw RegoError(
                    code: .invalidDataType,
                    message: "unable to perform ObjectInsertStatement on target value of type \(target.typeName))"
                )
            }
            targetObjectValue[key] = value
            ctx.assignLocal(idx: stmt.object, value: .object(targetObjectValue))

        case .objectMergeStmt(let stmt):
            let a = ctx.resolveLocal(idx: stmt.a)
            let b = ctx.resolveLocal(idx: stmt.b)
            if a == .undefined || b == .undefined {
                return failWithUndefined(withContext: ctx, stmt: statement)
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
            ctx.assignLocal(idx: stmt.target, value: .object(merged))

        case .resetLocalStmt(let stmt):
            ctx.assignLocal(idx: stmt.target, value: .undefined)

        case .resultSetAddStmt(let stmt):
            guard i == block.statements.count - 1 else {
                // TODO can this be a warning?
                throw RegoError(
                    code: .internalError,
                    message: "ResultSetAddStatement can only be used in the last statement of a block"
                )
            }
            let value = ctx.resolveLocal(idx: stmt.value)
            guard value != .undefined else {
                return failWithUndefined(withContext: ctx, stmt: statement)
            }
            ctx.results.insert(value)
            return BlockResult.success

        case .returnLocalStmt(let stmt):
            return BlockResult(functionReturnValue: ctx.resolveLocal(idx: stmt.source))

        case .scanStmt(let stmt):
            // From the spec: "This statement is undefined if source is a scalar value or empty collection."
            // ...but from jarl (https://github.com/borgeby/jarl/blob/02262bde6553c6b3cd9325e6c1593dded13fa753/core/src/main/cljc/jarl/eval.cljc#L322C61-L323C10)
            //   "OPA IR docs states 'source' may not be an empty collection;
            //   but if we 'break' for such, statements like 'every x in [] { x != x }' will be 'undefined'."
            // Also - "If the domain is empty, the overall statement is true."
            //  ref: https://www.openpolicyagent.org/docs/latest/policy-language/#every-keyword
            // After clarification, the correct behavior should be: "This statement is undefined if the source is a scalar or undefined.",
            // i.e. we need to ensure it is a collection type, but empty is allowed.
            let source = ctx.resolveLocal(idx: stmt.source)

            // Ensure the source is defined and not a scalar type
            guard source != .undefined, source.isCollection else {
                return failWithUndefined(withContext: ctx, stmt: statement)
            }

            try await evalScan(
                ctx: ctx,
                stmt: stmt,
                source: source
            )

        case .setAddStmt(let stmt):
            let value = try ctx.resolveOperand(stmt.value)
            let target = ctx.resolveLocal(idx: stmt.set)
            guard value != .undefined && target != .undefined else {
                return failWithUndefined(withContext: ctx, stmt: statement)
            }
            guard case .set(var targetSetValue) = target else {
                throw RegoError(
                    code: .invalidDataType,
                    message: "unable to perform SetAddStatement on target value of type \(target.typeName)"
                )
            }
            targetSetValue.insert(value)
            ctx.assignLocal(idx: stmt.set, value: .set(targetSetValue))

        case .withStmt(let stmt):
            // First we need to resolve the value that will be upserted
            let overlayValue = try ctx.resolveOperand(stmt.value)

            // Next look up the object we'll be upserting into
            let toPatch = ctx.resolveLocal(idx: stmt.local)

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

            // Set patched value and ensure restoration on exit
            ctx.assignLocal(idx: stmt.local, value: patched)
            defer {
                ctx.assignLocal(idx: stmt.local, value: toPatch)
            }

            let blockResult = try await ctx.memoStack.withPush {
                // Execute the block with the patched value
                return try await evalBlock(
                    withContext: ctx,
                    caller: statement,
                    block: stmt.block
                )
            }

            // Respect the break index from a sub block
            if blockResult.shouldBreak {
                return blockResult.breakByOne()
            }

            // Propagate undefined
            if blockResult.isUndefined {
                return failWithUndefined(withContext: ctx, stmt: statement)
            }

        case .unknown(let location):
            // Included for completeness, but this won't happen in practice as IR.Block's
            // decoder will have already failed to parse any unknown statements.
            throw RegoError(code: .internalError, message: "unexpected statement at location: \(location)")
        }

        // Next statement of current block
    }

    return BlockResult.success
}

private func evalCall(
    ctx: IREvaluationContext,
    caller: IR.Statement,
    funcName: String,
    args: [IR.Operand],
    isDynamic: Bool = false
) async throws -> AST.RegoValue {
    // Check memo cache if applicable to save repeated evaluation time for rules
    let shouldMemoize = args.count == 2  // Currently support _rules_, not _functions_
    let sig = InvocationKey(funcName: funcName, args: args)
    if shouldMemoize, let cachedResult = ctx.memoStack[sig] {
        return cachedResult
    }

    var argValues: [AST.RegoValue] = []
    argValues.reserveCapacity(args.count)
    for arg in args {
        // Note: we do not enforce that args are defined here, it appears
        // that the expectation is that statements within the function blocks
        // (for non-builtins) handle it.
        argValues.append(try ctx.resolveOperand(arg))
    }

    if isDynamic {
        // CallDynamicStmt doesn't reference functions by name (as labeled in the IR), it will be by path,
        // eg, ["g0", "a", "b"] versus the "name" like "g0.data.a.b"
        // We strigify the path first so they come in here looking like "g0.a.b".
        // If the function is not found in the policy, it is valid but undefined.
        guard let funcName = ctx.policy.funcsPathToName[funcName] else {
            return .undefined
        }

        // funcsPathToName and funcs are built together, so this must succeed
        let fn = ctx.policy.funcs[funcName]!

        let result = try await callPlanFunc(
            ctx: ctx,
            caller: caller,
            fn: fn,
            args: argValues
        )

        if shouldMemoize {
            ctx.memoStack[sig] = result
        }
        return result
    }

    // Handle plan-defined functions first
    if let fn = ctx.policy.funcs[funcName] {
        let result = try await callPlanFunc(
            ctx: ctx,
            caller: caller,
            fn: fn,
            args: argValues
        )

        if shouldMemoize {
            ctx.memoStack[sig] = result
        }

        return result
    }

    // Handle built-in functions last

    // We won't bother invoking the builtin function if one of the arguments is undefined
    for argValue in argValues {
        guard argValue != .undefined else {
            return .undefined
        }
    }

    let bctx = BuiltinContext(
        location: try ctx.currentLocation(stmt: caller),
        tracer: ctx.ctx.tracer,
        cache: ctx.ctx.builtinsCache,
        timestamp: ctx.ctx.timestamp
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
    caller: IR.Statement,
    fn: borrowing IR.Func,
    args: [AST.RegoValue]
) async throws -> AST.RegoValue {
    guard fn.params.count == args.count else {
        throw RegoError(code: .internalError, message: "mismatched argument count for function \(fn.name)")
    }
    guard ctx.callDepth < ctx.maxCallDepth else {
        throw RegoError(code: .maxCallDepthExceeded, message: "maximum call depth exceeded: \(ctx.callDepth)")
    }

    // Match source arguments to target params
    // to construct the locals map for the callee.
    // args are the resolved values to pass.
    // fn.params are the Local indices to pass them in to
    // in the new frame.

    // Build locals array pre-sized to exact maximum needed for this function (computed via static analysis)
    var callLocals = Locals(repeating: nil, count: max(fn.maxLocal + 1, 2))

    // Assign parameters
    for (argValue, paramIdx) in zip(args, fn.params) {
        callLocals[paramIdx] = argValue
    }

    // Add in implicit input + data locals
    callLocals[localIdxInput] = ctx.resolveLocal(idx: localIdxInput)
    callLocals[localIdxData] = ctx.resolveLocal(idx: localIdxData)

    // Save current locals and install call locals
    let savedLocals = ctx.locals
    ctx.locals = callLocals

    // Increment call depth and ensure it's decremented on exit
    ctx.callDepth += 1
    defer {
        ctx.callDepth -= 1
        ctx.locals = savedLocals
    }

    // Execute the function blocks with fresh locals
    let result = try await evalBlocks(
        withContext: ctx,
        blocks: fn.blocks,
        caller: caller
    )

    return result.functionReturnValue ?? .undefined
}

private func evalScan(
    ctx: IREvaluationContext,
    stmt: ScanStatement,
    source: AST.RegoValue
) async throws {
    switch source {
    case .array(let arr):
        for i in 0..<arr.count {
            let k: AST.RegoValue = .number(NSNumber(value: i))
            let v = arr[i] as AST.RegoValue
            try await evalScanBlock(ctx: ctx, stmt: stmt, key: k, value: v)
        }
    case .object(let o):
        for (k, v) in o {
            try await evalScanBlock(ctx: ctx, stmt: stmt, key: k, value: v)
        }
    case .set(let set):
        for v in set {
            try await evalScanBlock(ctx: ctx, stmt: stmt, key: v, value: v)
        }
    default:
        break
    }
}

private func evalScanBlock(
    ctx: IREvaluationContext,
    stmt: ScanStatement,
    key: AST.RegoValue,
    value: AST.RegoValue
) async throws {
    // Set scan variables directly in ctx locals
    ctx.assignLocal(idx: stmt.key, value: key)
    ctx.assignLocal(idx: stmt.value, value: value)

    // Execute the block
    let _ = try await evalBlock(
        withContext: ctx,
        caller: IR.Statement.scanStmt(stmt),
        block: stmt.block
    )
}
