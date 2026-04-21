import AST
import Bytecode
import Foundation

let localIdxInput = Local(0)
let localIdxData = Local(1)

/// Bytecode Virtual Machine for executing compiled IR policies
internal struct VM {
    let policy: Policy
}

extension VM {
    /// Execute a bytecode plan
    func executePlan(
        withContext ctx: EvaluationContext,
        planIndex: Int
    ) async throws -> ResultSet {
        guard planIndex < policy.plans.count else {
            throw Error.invalidPayloadLength
        }

        let plan = policy.plans[planIndex]
        let data = try await ctx.store.read(from: StoreKeyPath(["data"]))
        let vmContext = VMContext(
            evaluationContext: ctx,
            policy: policy,
            planMaxLocal: plan.maxLocal,
            data: data
        )

        for block in plan.blocks {
            let blockResult = try await executeBlock(
                context: vmContext,
                offset: block.offset,
                size: block.size
            )
            guard !blockResult.shouldBreak else {
                throw RegoError(code: .internalError, message: "break statement jumped out of frame")
            }
            if blockResult.isUndefined {
                continue
            }
        }

        return vmContext.results
    }

    /// Execute multiple blocks, collecting function return values
    internal func executeBlocks(
        context: VMContext,
        blocks: [(offset: Int, size: Int)]
    ) async throws -> BlockResult {
        var functionReturnValue: AST.RegoValue?

        for block in blocks {
            let blockResult = try await executeBlock(
                context: context,
                offset: block.offset,
                size: block.size
            )
            guard !blockResult.shouldBreak else {
                throw RegoError(code: .internalError, message: "break statement jumped out of frame")
            }
            if blockResult.isUndefined {
                continue
            }
            if let retVal = blockResult.functionReturnValue {
                guard functionReturnValue == nil else {
                    throw RegoError(code: .internalError, message: "multiple return values from a function")
                }
                functionReturnValue = retVal
            }
        }

        return BlockResult(functionReturnValue: functionReturnValue)
    }

    /// Execute a user-defined function
    internal func executeFunction(
        context: VMContext,
        function: Function,
        args: [AST.RegoValue]
    ) async throws -> AST.RegoValue {
        context.callDepth += 1
        guard context.callDepth <= context.maxCallDepth else {
            context.callDepth -= 1
            throw RegoError(code: .internalError, message: "max call depth exceeded")
        }

        // Save current locals and install new frame
        let savedLocals = context.locals
        let localsCount = max(function.maxLocal + 1, 2)
        context.locals = context.allocateLocals(count: localsCount)

        // Assign parameters
        for (i, paramIdx) in function.params.enumerated() where i < args.count {
            context.locals[paramIdx] = args[i]
        }

        // Propagate input and data from the caller's frame so that with-patched values are visible
        // to called functions.
        context.locals[localIdxInput] = savedLocals[localIdxInput] ?? .undefined
        context.locals[localIdxData] = savedLocals[localIdxData] ?? .undefined

        defer {
            context.callDepth -= 1
            let callLocals = context.locals
            context.locals = savedLocals
            context.releaseLocals(callLocals, usedCount: localsCount)
        }

        // Execute function blocks
        let result = try await executeBlocks(context: context, blocks: function.blocks)

        // Return explicit ReturnLocal value; undefined if none
        let returnValue = result.functionReturnValue ?? .undefined

        return returnValue
    }

    /// Execute a single block (PC loop over instructions)
    internal func executeBlock(
        context: VMContext,
        offset: Int,
        size: Int
    ) async throws -> BlockResult {
        let bytecode = policy.bytecode
        var pc = offset
        let endOffset = offset + size

        while pc < endOffset {
            if pc % 256 == 0 && Task.isCancelled {
                throw RegoError(code: .evaluationCancelled, message: "parent task cancelled")
            }

            // Decode header word: [reserved:2 | opcode:6 | length:24] little-endian.
            let word = bytecode.withUnsafeBytes {
                $0.load(fromByteOffset: pc, as: UInt32.self)
            }
            let opcodeRaw = Int((word >> 24) & 0x3F)
            let length = Int(word & 0xFFFFFF)
            pc += 4
            let payloadStart = pc

            // Unified switch over all opcodes: compact ops use `continue` (zero payload — `pc`
            // already advanced past the 4-byte header).  Non-compact ops assign `result` and
            // fall through to advance `pc` by the payload length.
            var result: BlockResult = .success
            switch opcodeRaw {
            // ── Compact opcodes (rawValues 35–41): operand encoded in `length` field ─────────
            case Int(Opcode.isDefined1.rawValue):
                if context.resolveLocal(idx: Local(UInt32(length))) == .undefined { return .undefined }
                continue
            case Int(Opcode.isUndefined1.rawValue):
                if context.resolveLocal(idx: Local(UInt32(length))) != .undefined { return .undefined }
                continue
            case Int(Opcode.resetLocal1.rawValue):
                context.locals[Local(UInt32(length))] = nil
                continue
            case Int(Opcode.resultSetAdd1.rawValue):
                let val = context.resolveLocal(idx: Local(UInt32(length)))
                if val == .undefined { return .undefined }
                context.results.insert(val)
                continue
            case Int(Opcode.returnLocal1.rawValue):
                return BlockResult(functionReturnValue: context.resolveLocal(idx: Local(UInt32(length))))
            case Int(Opcode.break1.rawValue):
                return BlockResult(breakCounter: UInt32(length))
            case Int(Opcode.assignVar1.rawValue):
                // Payload is [target:12 | source:12] packed in the header length field.
                context.locals[Local(UInt32(length) >> 12)] = context.locals[Local(UInt32(length) & 0xFFF)]
                continue
            // ── Non-compact opcodes (rawValues 0–34): `length` is payload byte count ─────────
            // Assignments
            case Int(Opcode.arrayAppend.rawValue):
                result = try execArrayAppend(context: context, payload: bytecode, start: payloadStart, length: length)
            case Int(Opcode.assignInt.rawValue):
                result = try execAssignInt(context: context, payload: bytecode, start: payloadStart, length: length)
            case Int(Opcode.assignVarOnce.rawValue):
                result = try execAssignVarOnce(context: context, payload: bytecode, start: payloadStart, length: length)
            case Int(Opcode.assignVar.rawValue):
                result = try execAssignVar(context: context, payload: bytecode, start: payloadStart, length: length)
            // Control flow
            case Int(Opcode.block.rawValue):
                result = try await execBlockStmt(
                    context: context, payload: bytecode, start: payloadStart, length: length)
            case Int(Opcode.break.rawValue):
                result = try execBreak(context: context, payload: bytecode, start: payloadStart, length: length)
            case Int(Opcode.call.rawValue):
                result = try await execCall(context: context, payload: bytecode, start: payloadStart, length: length)
            case Int(Opcode.callDynamic.rawValue):
                result = try await execCallDynamic(
                    context: context, payload: bytecode, start: payloadStart, length: length)
            // Operations
            case Int(Opcode.dot.rawValue):
                result = try execDot(context: context, payload: bytecode, start: payloadStart, length: length)
            case Int(Opcode.equal.rawValue):
                result = try execEqual(context: context, payload: bytecode, start: payloadStart, length: length)
            // Type checks
            case Int(Opcode.isArray.rawValue):
                result = try execIsArray(context: context, payload: bytecode, start: payloadStart, length: length)
            case Int(Opcode.isDefined.rawValue):
                result = try execIsDefined(context: context, payload: bytecode, start: payloadStart, length: length)
            case Int(Opcode.isObject.rawValue):
                result = try execIsObject(context: context, payload: bytecode, start: payloadStart, length: length)
            case Int(Opcode.isSet.rawValue):
                result = try execIsSet(context: context, payload: bytecode, start: payloadStart, length: length)
            case Int(Opcode.isUndefined.rawValue):
                result = try execIsUndefined(context: context, payload: bytecode, start: payloadStart, length: length)
            // Built-in operations
            case Int(Opcode.len.rawValue):
                result = try execLen(context: context, payload: bytecode, start: payloadStart, length: length)
            // Value construction
            case Int(Opcode.makeArray.rawValue):
                result = try execMakeArray(context: context, payload: bytecode, start: payloadStart, length: length)
            case Int(Opcode.makeNull.rawValue):
                result = try execMakeNull(context: context, payload: bytecode, start: payloadStart, length: length)
            case Int(Opcode.makeNumberInt.rawValue):
                result = try execMakeNumberInt(context: context, payload: bytecode, start: payloadStart, length: length)
            case Int(Opcode.makeNumberRef.rawValue):
                result = try execMakeNumberRef(context: context, payload: bytecode, start: payloadStart, length: length)
            case Int(Opcode.makeObject.rawValue):
                result = try execMakeObject(context: context, payload: bytecode, start: payloadStart, length: length)
            case Int(Opcode.makeSet.rawValue):
                result = try execMakeSet(context: context, payload: bytecode, start: payloadStart, length: length)
            // Control and comparison
            case Int(Opcode.nop.rawValue):
                break  // result stays .success
            case Int(Opcode.notEqual.rawValue):
                result = try execNotEqual(context: context, payload: bytecode, start: payloadStart, length: length)
            case Int(Opcode.not.rawValue):
                result = try await execNot(context: context, payload: bytecode, start: payloadStart, length: length)
            // Object operations
            case Int(Opcode.objectInsertOnce.rawValue):
                result = try execObjectInsertOnce(
                    context: context, payload: bytecode, start: payloadStart, length: length)
            case Int(Opcode.objectInsert.rawValue):
                result = try execObjectInsert(context: context, payload: bytecode, start: payloadStart, length: length)
            case Int(Opcode.objectMerge.rawValue):
                result = try execObjectMerge(context: context, payload: bytecode, start: payloadStart, length: length)
            // Variable management
            case Int(Opcode.resetLocal.rawValue):
                result = try execResetLocal(context: context, payload: bytecode, start: payloadStart, length: length)
            case Int(Opcode.resultSetAdd.rawValue):
                result = try execResultSetAdd(context: context, payload: bytecode, start: payloadStart, length: length)
            case Int(Opcode.returnLocal.rawValue):
                result = try execReturnLocal(context: context, payload: bytecode, start: payloadStart, length: length)
            // Collection operations
            case Int(Opcode.scan.rawValue):
                result = try await execScan(context: context, payload: bytecode, start: payloadStart, length: length)
            case Int(Opcode.setAdd.rawValue):
                result = try execSetAdd(context: context, payload: bytecode, start: payloadStart, length: length)
            case Int(Opcode.with.rawValue):
                result = try await execWith(context: context, payload: bytecode, start: payloadStart, length: length)
            case Int(Opcode.block1.rawValue):
                // Inline block1 to avoid an extra async activation record for the single sub-block call.
                let innerResult = try await executeBlock(context: context, offset: payloadStart, size: length)
                if innerResult.shouldBreak {
                    result = innerResult.breakByOne()
                }
            // Inner undefined is intentionally ignored: block1 compiles from a single-sub-block
            // IR form where an undefined body means "this alternative didn't match" and execution
            // falls through to the next instruction, not propagated as undefined to the caller.
            default:
                preconditionFailure("unhandled opcode \(opcodeRaw)")
            }

            // .undefined is encoded as BlockResult(breakCounter: 0), so the breakCounter check
            // below already covers it.  Propagate any non-continuing result immediately.
            if result.breakCounter != nil || result.functionReturnValue != nil { return result }

            pc = payloadStart + length
        }

        return .success
    }
}

/// CallKey is a key for memoizing a bytecode user-function (rule) call.
/// Arguments are captured as raw-encoded operand values rather than resolved RegoValues,
/// as hashing resolved values is expensive. This relies on the invariant that the plan
/// will not modify a local after it has been initially set.
/// Only 2-arg calls (OPA rules: input + data) are memoized.
struct CallKey: Hashable {
    let funcIndex: Int32
    let op0: UInt32  // (type:2 | value:30) encoded from EncodedOperand
    let op1: UInt32
}

typealias MemoCache = [CallKey: AST.RegoValue]

/// VM execution context - holds state during bytecode execution
internal final class VMContext {
    let evaluationContext: EvaluationContext
    let policy: Policy
    let tracingEnabled: Bool

    var maxCallDepth: Int = 16_384
    var callDepth: Int = 0
    var memoStack: [MemoCache] = []
    var results: ResultSet
    var locals: Locals

    // Pool for reusing storage arrays across function calls
    private var localsPool: [[AST.RegoValue?]] = []

    // Pool for reusing args arrays
    private var argsPool: [[AST.RegoValue]] = []

    init(evaluationContext: EvaluationContext, policy: Policy, planMaxLocal: Int, data: AST.RegoValue) {
        self.evaluationContext = evaluationContext
        self.policy = policy
        self.tracingEnabled = evaluationContext.tracer != nil
        self.results = ResultSet.empty

        // Pre-allocate locals based on static analysis
        self.locals = Locals(repeating: nil, count: max(planMaxLocal + 1, 2))

        // Initialize input and data locals
        self.locals[localIdxInput] = evaluationContext.input
        self.locals[localIdxData] = data
    }

    /// Resolve a local variable.
    /// `nil` and `.undefined` in the locals array are equivalent — both represent an unbound
    /// variable.  All reads must go through this function; direct `locals[idx]` access is only
    /// permitted for writes (assignment, CoW nil-before-rebind, resetLocal).
    func resolveLocal(idx: Local) -> AST.RegoValue {
        return locals[idx] ?? .undefined
    }

    /// Assign a value to a local variable
    func assignLocal(idx: Local, value: AST.RegoValue) {
        locals[idx] = value
    }

    /// Decode and resolve an operand from bytecode
    func decodeOperand(from bytes: ContiguousArray<UInt8>, at offset: Int) -> (operand: EncodedOperand, size: Int) {
        return EncodedOperand.decodeUnchecked(from: bytes, at: offset)
    }

    /// Resolve an encoded operand to a RegoValue without bounds checking (for validated bytecode)
    /// SAFETY: Caller must ensure operand indices are valid
    @inline(__always)
    func resolveUnchecked(_ operand: EncodedOperand) -> AST.RegoValue {
        switch operand.type {
        case .local:
            return resolveLocal(idx: Local(operand.value))
        case .bool:
            return .boolean(operand.value != 0)
        case .stringIndex:
            return .string(policy.strings[Int(operand.value)])
        case .numberIndex:
            return .number(policy.numbers[Int(operand.value)]!)
        }
    }

    /// Decode a Local index from 4 bytes
    @inline(__always)
    func decodeLocal(from bytes: ContiguousArray<UInt8>, at offset: Int) -> Local {
        Local(bytes.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self) })
    }

    /// Decode a UInt32 from 4 bytes
    @inline(__always)
    func decodeUInt32(from bytes: ContiguousArray<UInt8>, at offset: Int) -> UInt32 {
        bytes.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self) }
    }

    /// Decode an Int64 from 8 bytes (little-endian)
    @inline(__always)
    func decodeInt64(from bytes: ContiguousArray<UInt8>, at offset: Int) -> Int64 {
        bytes.withUnsafeBytes { Int64(bitPattern: $0.loadUnaligned(fromByteOffset: offset, as: UInt64.self)) }
    }

    // Memoization support
    subscript(key: CallKey) -> AST.RegoValue? {
        get {
            guard !memoStack.isEmpty else {
                return nil
            }
            return memoStack[memoStack.count - 1][key]
        }
        set {
            if memoStack.isEmpty {
                memoStack.append(MemoCache())
            }
            memoStack[memoStack.count - 1][key] = newValue
        }
    }

    func pushMemoCache() {
        memoStack.append(MemoCache())
    }

    func popMemoCache() {
        guard !memoStack.isEmpty else {
            return
        }
        memoStack.removeLast()
    }

    // Locals pool management
    func allocateLocals(count: Int) -> Locals {
        if var storage = localsPool.popLast() {
            if count > storage.count {
                storage.append(contentsOf: repeatElement(nil, count: count - storage.count))
            }
            return Locals(storage)
        }
        return Locals(repeating: nil, count: count)
    }

    func releaseLocals(_ locals: Locals, usedCount: Int? = nil) {
        var locals = locals
        let cleared = locals.releaseStorage(usedCount: usedCount)
        localsPool.append(cleared)
    }

    // Args pool management
    func allocateArgs(count: Int) -> [AST.RegoValue] {
        if var args = argsPool.popLast() {
            // Clear old contents but keep capacity
            args.removeAll(keepingCapacity: true)
            args.reserveCapacity(count)
            return args
        }
        // Pool exhausted - allocate new
        var args: [AST.RegoValue] = []
        args.reserveCapacity(count)
        return args
    }

    func releaseArgs(_ args: [AST.RegoValue]) {
        // Return to pool without clearing - will be cleared on next allocate
        argsPool.append(args)
    }
}

/// Helper to return undefined block result
func failWithUndefinedBytecode(context: VMContext) -> BlockResult {
    return .undefined
}
