import AST
import Bytecode
import Foundation

// Bytecode instruction handlers
// Each function decodes the payload for a specific opcode and executes the instruction

extension VM {

    // MARK: - Assignment Operations

    /// ArrayAppend: [array: Local][value: Operand]
    func execArrayAppend(context: VMContext, payload: ContiguousArray<UInt8>, start: Int, length: Int) throws
        -> BlockResult
    {
        let arrayIdx = context.decodeLocal(from: payload, at: start)
        let (valueOp, _) = context.decodeOperand(from: payload, at: start + 4)
        let value = context.resolveUnchecked(valueOp)

        guard value != .undefined else {
            return failWithUndefinedBytecode(context: context)
        }

        let array = context.resolveLocal(idx: arrayIdx)
        context.locals[arrayIdx] = nil  // drop reference before var binding to avoid CoW copy
        guard case .array(var arrayValue) = array else {
            return failWithUndefinedBytecode(context: context)
        }
        arrayValue.append(value)
        context.assignLocal(idx: arrayIdx, value: .array(arrayValue))
        return .success
    }

    /// AssignInt: [value: Int64][target: Local]
    func execAssignInt(context: VMContext, payload: ContiguousArray<UInt8>, start: Int, length: Int) throws
        -> BlockResult
    {
        let signedValue = context.decodeInt64(from: payload, at: start)
        let target = context.decodeLocal(from: payload, at: start + 8)
        context.assignLocal(idx: target, value: .number(RegoNumber(int: signedValue)))
        return .success
    }

    /// AssignVarOnce: [target: Local][source: Operand]
    func execAssignVarOnce(context: VMContext, payload: ContiguousArray<UInt8>, start: Int, length: Int) throws
        -> BlockResult
    {
        let target = context.decodeLocal(from: payload, at: start)
        let (sourceOp, _) = context.decodeOperand(from: payload, at: start + 4)
        let source = context.resolveUnchecked(sourceOp)

        let currentValue = context.resolveLocal(idx: target)
        guard currentValue == .undefined else {
            // Repeated assignments can only be of the same value, otherwise error
            if currentValue != source {
                throw RegoError(code: .assignOnceError, message: "local already assigned with different value")
            }
            return .success
        }

        context.assignLocal(idx: target, value: source)
        return .success
    }

    /// AssignVar: [target: Local][source: Operand]
    func execAssignVar(context: VMContext, payload: ContiguousArray<UInt8>, start: Int, length: Int) throws
        -> BlockResult
    {
        let target = context.decodeLocal(from: payload, at: start)
        let (sourceOp, _) = context.decodeOperand(from: payload, at: start + 4)
        let source = context.resolveUnchecked(sourceOp)

        context.assignLocal(idx: target, value: source)
        return .success
    }

    // MARK: - Control Flow

    /// Block: [numBlocks: UInt32][offset1: UInt32][size1: UInt32]...
    /// Implements blockStmt semantics for 0 or 2+ sub-blocks
    func execBlockStmt(context: VMContext, payload: ContiguousArray<UInt8>, start: Int, length: Int) async throws
        -> BlockResult
    {
        let numBlocks = context.decodeUInt32(from: payload, at: start)
        guard numBlocks > 0 else { return .success }
        var offset = start + 4

        for _ in 0..<numBlocks {
            let blockOffset = context.decodeUInt32(from: payload, at: offset)
            let blockSize = context.decodeUInt32(from: payload, at: offset + 4)
            offset += 8

            let result = try await self.executeBlock(
                context: context,
                offset: Int(blockOffset),
                size: Int(blockSize)
            )

            if result.shouldBreak {
                // Propagate break after decrementing
                return result.breakByOne()
            }
            if result.isUndefined {
                // Undefined block: skip to next alternative
                continue
            }
            // Success (or functionReturnValue): continue to next sub-block.
            // functionReturnValue is intentionally not propagated here — it is
            // collected by executeBlocks at the function boundary, matching IR semantics.
        }

        return .success
    }

    /// Break: [index: UInt32]
    func execBreak(context: VMContext, payload: ContiguousArray<UInt8>, start: Int, length: Int) throws -> BlockResult {
        let index = context.decodeUInt32(from: payload, at: start)
        return BlockResult(breakCounter: index)
    }

    /// Call: [result: Local][funcIndex: UInt32][argCount: UInt32][args: Operand...]
    /// funcIndex high bit: 0 = user function, 1 = builtin (lower bits = string table index)
    func execCall(context: VMContext, payload: ContiguousArray<UInt8>, start: Int, length: Int) async throws
        -> BlockResult
    {
        let result = context.decodeLocal(from: payload, at: start)
        let encodedFuncIndex = context.decodeUInt32(from: payload, at: start + 4)
        let argCount = context.decodeUInt32(from: payload, at: start + 8)

        // Fast path: user function call with exactly 2 args (OPA rules: input + data).
        // Check the memo cache using the raw encoded operands as the key (no value hashing).
        if encodedFuncIndex & 0x8000_0000 == 0 && argCount == 2 {
            let (op0, op0Size) = EncodedOperand.decodeUnchecked(from: payload, at: start + 12)
            let (op1, _) = EncodedOperand.decodeUnchecked(from: payload, at: start + 12 + op0Size)
            let memoKey = CallKey(
                funcIndex: Int32(encodedFuncIndex),
                op0: (UInt32(op0.type.rawValue) << 30) | op0.value,
                op1: (UInt32(op1.type.rawValue) << 30) | op1.value
            )
            if let cached = context[memoKey] {
                guard cached != .undefined else {
                    return failWithUndefinedBytecode(context: context)
                }
                context.assignLocal(idx: result, value: cached)
                return .success
            }

            let funcIndex = Int(encodedFuncIndex)
            let function = policy.functions[funcIndex]
            let arg0 = context.resolveUnchecked(op0)
            let arg1 = context.resolveUnchecked(op1)
            var memoArgs = context.allocateArgs(count: 2)
            defer { context.releaseArgs(memoArgs) }
            memoArgs.append(arg0)
            memoArgs.append(arg1)

            let returnValue = try await executeFunction(context: context, function: function, args: memoArgs)
            context[memoKey] = returnValue
            guard returnValue != .undefined else {
                return failWithUndefinedBytecode(context: context)
            }
            context.assignLocal(idx: result, value: returnValue)
            return .success
        }

        // General path: builtins and user functions with != 2 args
        var args = context.allocateArgs(count: Int(argCount))
        defer {
            context.releaseArgs(args)
        }

        // Decode arguments into pooled array.
        // Note: we do not reject undefined args here for user functions - the function body
        // handles undefined arguments internally. For builtins we check below.
        var currentOffset = start + 12
        for _ in 0..<Int(argCount) {
            let (op, size) = context.decodeOperand(from: payload, at: currentOffset)
            let value = context.resolveUnchecked(op)
            args.append(value)
            currentOffset += size
        }

        // Check if this is a builtin call (high bit set)
        if encodedFuncIndex & 0x8000_0000 != 0 {
            // Builtin call: fail immediately if any argument is undefined
            for argValue in args {
                guard argValue != .undefined else {
                    return failWithUndefinedBytecode(context: context)
                }
            }

            let stringIndex = Int(encodedFuncIndex & 0x7FFF_FFFF)
            let builtinName = policy.strings[stringIndex]

            // Look up builtin in registry using subscript
            guard let builtin = context.evaluationContext.builtins[builtinName] else {
                // Builtin not found - fail with undefined
                return failWithUndefinedBytecode(context: context)
            }

            // Create builtin context
            let builtinContext = BuiltinContext(
                tracer: context.evaluationContext.tracer,
                cache: context.evaluationContext.builtinsCache,
                timestamp: context.evaluationContext.timestamp
            )

            // Invoke builtin
            let returnValue: AST.RegoValue
            do {
                returnValue = try await builtin(builtinContext, args)
            } catch {
                // Builtin error - fail with undefined unless strict mode
                if context.evaluationContext.strictBuiltins {
                    throw error
                }
                return failWithUndefinedBytecode(context: context)
            }

            // Store result
            context.assignLocal(idx: result, value: returnValue)
            return .success
        }

        // User-defined function call with != 2 args (no memoization)
        let funcIndex = Int(encodedFuncIndex)
        let function = policy.functions[funcIndex]

        let returnValue = try await executeFunction(context: context, function: function, args: args)

        guard returnValue != .undefined else {
            return failWithUndefinedBytecode(context: context)
        }

        context.assignLocal(idx: result, value: returnValue)
        return .success
    }

    /// CallDynamic: [result: Local][pathCount: UInt32][path: Operand...][argCount: UInt32][args: Local...]
    func execCallDynamic(context: VMContext, payload: ContiguousArray<UInt8>, start: Int, length: Int) async throws
        -> BlockResult
    {
        let result = context.decodeLocal(from: payload, at: start)
        let pathCount = context.decodeUInt32(from: payload, at: start + 4)

        var offset = start + 8

        // Decode path operands
        var funcName = ""
        for i in 0..<Int(pathCount) {
            let (segmentOp, size) = context.decodeOperand(from: payload, at: offset)
            let segment = context.resolveUnchecked(segmentOp)
            offset += size

            guard case .string(let stringValue) = segment else {
                return failWithUndefinedBytecode(context: context)
            }

            if i > 0 {
                funcName += "."
            }
            funcName += stringValue
        }

        // Decode argument count
        let argCount = context.decodeUInt32(from: payload, at: offset)
        offset += 4

        // Allocate args array from pool
        var args = context.allocateArgs(count: Int(argCount))
        defer {
            context.releaseArgs(args)
        }

        // Decode arguments (these are Locals, not Operands)
        // Note: do not reject undefined args — the called function handles them internally,
        // mirroring execCall's behavior for user functions.
        for _ in 0..<Int(argCount) {
            let argLocal = context.decodeLocal(from: payload, at: offset)
            offset += 4
            let argValue = context.resolveLocal(idx: argLocal)
            args.append(argValue)
        }

        // Find function by path (joined with ".").
        // Both the callDynamic path segments and the Function.path array use the same naming
        // convention (no "data" prefix), so joining with "." gives a directly comparable key.
        guard let function = policy.functions.first(where: { $0.path.joined(separator: ".") == funcName }) else {
            return failWithUndefinedBytecode(context: context)
        }

        let returnValue = try await executeFunction(context: context, function: function, args: args)

        guard returnValue != .undefined else {
            return failWithUndefinedBytecode(context: context)
        }
        context.assignLocal(idx: result, value: returnValue)

        return .success
    }

    // MARK: - Operations

    /// Dot: [source: Operand][key: Operand][target: Local]
    func execDot(context: VMContext, payload: ContiguousArray<UInt8>, start: Int, length: Int) throws -> BlockResult {
        let (sourceOp, sourceSize) = context.decodeOperand(from: payload, at: start)
        let source = context.resolveUnchecked(sourceOp)
        let (keyOp, keySize) = context.decodeOperand(from: payload, at: start + sourceSize)
        let key = context.resolveUnchecked(keyOp)
        let target = context.decodeLocal(from: payload, at: start + sourceSize + keySize)

        let result: AST.RegoValue
        switch source {
        case .object(let obj):
            result = obj[key] ?? .undefined
        case .array(let arr):
            guard case .number(let num) = key else {
                result = .undefined
                break
            }
            let index = num.intValue
            guard index >= 0 && index < arr.count else {
                result = .undefined
                break
            }
            result = arr[index]
        case .set(let set):
            result = set.contains(key) ? key : .undefined
        default:
            result = .undefined
        }

        guard result != .undefined else {
            return failWithUndefinedBytecode(context: context)
        }

        context.assignLocal(idx: target, value: result)
        return .success
    }

    /// Equal: [a: Operand][b: Operand]
    func execEqual(context: VMContext, payload: ContiguousArray<UInt8>, start: Int, length: Int) throws -> BlockResult {
        let (aOp, aSize) = context.decodeOperand(from: payload, at: start)
        let a = context.resolveUnchecked(aOp)
        let (bOp, _) = context.decodeOperand(from: payload, at: start + aSize)
        let b = context.resolveUnchecked(bOp)

        guard a == b else {
            return failWithUndefinedBytecode(context: context)
        }
        return .success
    }

    // MARK: - Type Checks

    /// IsArray: [source: Operand]
    func execIsArray(context: VMContext, payload: ContiguousArray<UInt8>, start: Int, length: Int) throws -> BlockResult
    {
        let (sourceOp, _) = context.decodeOperand(from: payload, at: start)
        let source = context.resolveUnchecked(sourceOp)

        switch source {
        case .array:
            return .success
        default:
            return failWithUndefinedBytecode(context: context)
        }
    }

    /// IsDefined: [source: Local]
    func execIsDefined(context: VMContext, payload: ContiguousArray<UInt8>, start: Int, length: Int) throws
        -> BlockResult
    {
        let source = context.decodeLocal(from: payload, at: start)
        let value = context.resolveLocal(idx: source)

        guard value != .undefined else {
            return failWithUndefinedBytecode(context: context)
        }
        return .success
    }

    /// IsObject: [source: Operand]
    func execIsObject(context: VMContext, payload: ContiguousArray<UInt8>, start: Int, length: Int) throws
        -> BlockResult
    {
        let (sourceOp, _) = context.decodeOperand(from: payload, at: start)
        let source = context.resolveUnchecked(sourceOp)

        guard case .object = source else {
            return failWithUndefinedBytecode(context: context)
        }
        return .success
    }

    /// IsSet: [source: Operand]
    func execIsSet(context: VMContext, payload: ContiguousArray<UInt8>, start: Int, length: Int) throws -> BlockResult {
        let (sourceOp, _) = context.decodeOperand(from: payload, at: start)
        let source = context.resolveUnchecked(sourceOp)

        guard case .set = source else {
            return failWithUndefinedBytecode(context: context)
        }
        return .success
    }

    /// IsUndefined: [source: Local]
    func execIsUndefined(context: VMContext, payload: ContiguousArray<UInt8>, start: Int, length: Int) throws
        -> BlockResult
    {
        let source = context.decodeLocal(from: payload, at: start)
        let value = context.resolveLocal(idx: source)

        guard value == .undefined else {
            return failWithUndefinedBytecode(context: context)
        }
        return .success
    }

    // MARK: - Built-in Operations

    /// Len: [source: Operand][target: Local]
    func execLen(context: VMContext, payload: ContiguousArray<UInt8>, start: Int, length: Int) throws -> BlockResult {
        let (sourceOp, sourceSize) = context.decodeOperand(from: payload, at: start)
        let source = context.resolveUnchecked(sourceOp)
        let target = context.decodeLocal(from: payload, at: start + sourceSize)

        let sourceValue = source

        let length: Int
        switch sourceValue {
        case .array(let arr):
            length = arr.count
        case .set(let set):
            length = set.count
        case .object(let obj):
            length = obj.count
        case .string(let str):
            length = str.count
        default:
            return failWithUndefinedBytecode(context: context)
        }

        context.assignLocal(idx: target, value: .number(RegoNumber(int: Int64(length))))
        return .success
    }

    // MARK: - Value Construction

    /// MakeArray: [capacity: UInt32][target: Local]
    func execMakeArray(context: VMContext, payload: ContiguousArray<UInt8>, start: Int, length: Int) throws
        -> BlockResult
    {
        let capacity = context.decodeUInt32(from: payload, at: start)
        let target = context.decodeLocal(from: payload, at: start + 4)

        var array: [AST.RegoValue] = []
        array.reserveCapacity(Int(capacity))

        context.assignLocal(idx: target, value: .array(array))
        return .success
    }

    /// MakeNull: [target: Local]
    func execMakeNull(context: VMContext, payload: ContiguousArray<UInt8>, start: Int, length: Int) throws
        -> BlockResult
    {
        let target = context.decodeLocal(from: payload, at: start)
        context.assignLocal(idx: target, value: .null)
        return .success
    }

    /// MakeNumberInt: [value: Int64][target: Local]
    func execMakeNumberInt(context: VMContext, payload: ContiguousArray<UInt8>, start: Int, length: Int) throws
        -> BlockResult
    {
        let value = context.decodeInt64(from: payload, at: start)
        let target = context.decodeLocal(from: payload, at: start + 8)
        context.assignLocal(idx: target, value: .number(RegoNumber(int: value)))
        return .success
    }

    /// MakeNumberRef: [index: UInt32][target: Local]
    func execMakeNumberRef(context: VMContext, payload: ContiguousArray<UInt8>, start: Int, length: Int) throws
        -> BlockResult
    {
        let index = context.decodeUInt32(from: payload, at: start)
        let target = context.decodeLocal(from: payload, at: start + 4)
        let number = policy.numbers[Int(index)]!
        context.assignLocal(idx: target, value: .number(number))
        return .success
    }

    /// MakeObject: [target: Local]
    func execMakeObject(context: VMContext, payload: ContiguousArray<UInt8>, start: Int, length: Int) throws
        -> BlockResult
    {
        let target = context.decodeLocal(from: payload, at: start)
        context.assignLocal(idx: target, value: .object([:]))
        return .success
    }

    /// MakeSet: [target: Local]
    func execMakeSet(context: VMContext, payload: ContiguousArray<UInt8>, start: Int, length: Int) throws -> BlockResult
    {
        let target = context.decodeLocal(from: payload, at: start)
        context.assignLocal(idx: target, value: .set([]))
        return .success
    }

    // MARK: - Comparison

    /// NotEqual: [a: Operand][b: Operand]
    func execNotEqual(context: VMContext, payload: ContiguousArray<UInt8>, start: Int, length: Int) throws
        -> BlockResult
    {
        let (aOp, aSize) = context.decodeOperand(from: payload, at: start)
        let a = context.resolveUnchecked(aOp)
        let (bOp, _) = context.decodeOperand(from: payload, at: start + aSize)
        let b = context.resolveUnchecked(bOp)

        // This statement is undefined if either operand is undefined or if a equals b
        if a == .undefined || b == .undefined || a == b {
            return failWithUndefinedBytecode(context: context)
        }

        return .success
    }

    /// Not: [block content inline]
    func execNot(context: VMContext, payload: ContiguousArray<UInt8>, start: Int, length: Int) async throws
        -> BlockResult
    {
        // Execute the nested block — block starts at payload start and fills the entire payload
        let result = try await self.executeBlock(
            context: context,
            offset: start,
            size: length
        )

        // Handle break statements
        if let breakCounter = result.breakCounter {
            if breakCounter > 0 {
                // Propagate break after decrementing
                return result.breakByOne()
            }
            // breakCounter == 0 means undefined, so Not succeeds
            return .success
        }

        // If block succeeded (not undefined), Not fails
        return failWithUndefinedBytecode(context: context)
    }

    // MARK: - Object Operations

    /// ObjectInsertOnce: [object: Local][key: Operand][value: Operand]
    func execObjectInsertOnce(context: VMContext, payload: ContiguousArray<UInt8>, start: Int, length: Int) throws
        -> BlockResult
    {
        let object = context.decodeLocal(from: payload, at: start)
        let (keyOp, keySize) = context.decodeOperand(from: payload, at: start + 4)
        let key = context.resolveUnchecked(keyOp)
        let (valueOp, _) = context.decodeOperand(from: payload, at: start + 4 + keySize)
        let value = context.resolveUnchecked(valueOp)

        guard key != .undefined, value != .undefined else {
            return failWithUndefinedBytecode(context: context)
        }

        let objectValue = context.resolveLocal(idx: object)
        context.locals[object] = nil  // drop reference before var binding to avoid CoW copy
        guard case .object(var obj) = objectValue else {
            return failWithUndefinedBytecode(context: context)
        }

        // Check if key already exists with different value
        if let existing = obj[key], existing != value {
            throw RegoError(
                code: .objectInsertOnceError,
                message: "key '\(key)' already exists in object with different value"
            )
        }

        obj[key] = value
        context.assignLocal(idx: object, value: .object(obj))
        return .success
    }

    /// ObjectInsert: [object: Local][key: Operand][value: Operand]
    func execObjectInsert(context: VMContext, payload: ContiguousArray<UInt8>, start: Int, length: Int) throws
        -> BlockResult
    {
        let object = context.decodeLocal(from: payload, at: start)
        let (keyOp, keySize) = context.decodeOperand(from: payload, at: start + 4)
        let key = context.resolveUnchecked(keyOp)
        let (valueOp, _) = context.decodeOperand(from: payload, at: start + 4 + keySize)
        let value = context.resolveUnchecked(valueOp)

        guard value != .undefined else {
            return failWithUndefinedBytecode(context: context)
        }

        let objectValue = context.resolveLocal(idx: object)
        context.locals[object] = nil  // drop reference before var binding to avoid CoW copy
        guard case .object(var obj) = objectValue else {
            return failWithUndefinedBytecode(context: context)
        }

        obj[key] = value
        context.assignLocal(idx: object, value: .object(obj))
        return .success
    }

    /// ObjectMerge: [target: Local][a: Local][b: Local]
    func execObjectMerge(context: VMContext, payload: ContiguousArray<UInt8>, start: Int, length: Int) throws
        -> BlockResult
    {
        let target = context.decodeLocal(from: payload, at: start)
        let a = context.decodeLocal(from: payload, at: start + 4)
        let b = context.decodeLocal(from: payload, at: start + 8)

        let aValue = context.resolveLocal(idx: a)
        let bValue = context.resolveLocal(idx: b)

        guard case .object(let objA) = aValue, case .object(let objB) = bValue else {
            return failWithUndefinedBytecode(context: context)
        }

        // Deep merge
        // Values from A take precedence; if both sides have objects at the same key they are merged recursively.
        let merged = objB.merge(with: objA)

        context.assignLocal(idx: target, value: .object(merged))
        return .success
    }

    // MARK: - Variable Management

    /// ResetLocal: [local: Local]
    func execResetLocal(context: VMContext, payload: ContiguousArray<UInt8>, start: Int, length: Int) throws
        -> BlockResult
    {
        let local = context.decodeLocal(from: payload, at: start)
        context.locals[local] = nil
        return .success
    }

    /// ResultSetAdd: [value: Local]
    func execResultSetAdd(context: VMContext, payload: ContiguousArray<UInt8>, start: Int, length: Int) throws
        -> BlockResult
    {
        let value = context.decodeLocal(from: payload, at: start)
        let regoValue = context.resolveLocal(idx: value)

        guard regoValue != .undefined else {
            return failWithUndefinedBytecode(context: context)
        }

        context.results.insert(regoValue)
        return .success
    }

    /// ReturnLocal: [source: Local]
    func execReturnLocal(context: VMContext, payload: ContiguousArray<UInt8>, start: Int, length: Int) throws
        -> BlockResult
    {
        let source = context.decodeLocal(from: payload, at: start)
        let value = context.resolveLocal(idx: source)
        return BlockResult(functionReturnValue: value)
    }

    // MARK: - Collection Operations

    /// Scan: [source: Local][key: Local][value: Local][block content inline]
    func execScan(context: VMContext, payload: ContiguousArray<UInt8>, start: Int, length: Int) async throws
        -> BlockResult
    {
        let source = context.decodeLocal(from: payload, at: start)
        let key = context.decodeLocal(from: payload, at: start + 4)
        let value = context.decodeLocal(from: payload, at: start + 8)
        // Block starts immediately after 3 locals (12 bytes)
        let blockOffset = start + 12
        let blockSize = length - 12

        let sourceValue = context.resolveLocal(idx: source)

        // Ensure source is defined and is a collection
        guard sourceValue != .undefined, sourceValue.isCollection else {
            return failWithUndefinedBytecode(context: context)
        }

        // Iterate over the collection, propagating break and return from the scan body.
        // OPA semantics: break exits the scan loop (consuming one nesting level),
        // return propagates immediately, undefined or success means this iteration
        // didn't match / completed — continue to the next element.
        switch sourceValue {
        case .array(let arr):
            for (i, val) in arr.enumerated() {
                context.assignLocal(idx: key, value: .number(RegoNumber(int: Int64(i))))
                context.assignLocal(idx: value, value: val)
                let blockResult = try await self.executeBlock(
                    context: context,
                    offset: blockOffset,
                    size: blockSize
                )
                if blockResult.shouldBreak { return blockResult.breakByOne() }
                if blockResult.functionReturnValue != nil { return blockResult }
            }
        case .object(let obj):
            for (k, v) in obj {
                context.assignLocal(idx: key, value: k)
                context.assignLocal(idx: value, value: v)
                let blockResult = try await self.executeBlock(
                    context: context,
                    offset: blockOffset,
                    size: blockSize
                )
                if blockResult.shouldBreak { return blockResult.breakByOne() }
                if blockResult.functionReturnValue != nil { return blockResult }
            }
        case .set(let set):
            for val in set {
                context.assignLocal(idx: key, value: val)
                context.assignLocal(idx: value, value: val)
                let blockResult = try await self.executeBlock(
                    context: context,
                    offset: blockOffset,
                    size: blockSize
                )
                if blockResult.shouldBreak { return blockResult.breakByOne() }
                if blockResult.functionReturnValue != nil { return blockResult }
            }
        default:
            return failWithUndefinedBytecode(context: context)
        }

        return .success
    }

    /// SetAdd: [set: Local][value: Operand]
    func execSetAdd(context: VMContext, payload: ContiguousArray<UInt8>, start: Int, length: Int) throws -> BlockResult
    {
        let set = context.decodeLocal(from: payload, at: start)
        let (valueOp, _) = context.decodeOperand(from: payload, at: start + 4)
        let value = context.resolveUnchecked(valueOp)

        guard value != .undefined else {
            return failWithUndefinedBytecode(context: context)
        }

        let setValue = context.resolveLocal(idx: set)
        context.locals[set] = nil  // drop reference before var binding to avoid CoW copy
        guard case .set(var setVal) = setValue else {
            return failWithUndefinedBytecode(context: context)
        }

        setVal.insert(value)
        context.assignLocal(idx: set, value: .set(setVal))
        return .success
    }

    /// With: [local: Local][value: Operand][pathCount: UInt32][pathIndices: UInt32...][block content inline]
    func execWith(context: VMContext, payload: ContiguousArray<UInt8>, start: Int, length: Int) async throws
        -> BlockResult
    {
        let local = context.decodeLocal(from: payload, at: start)
        let (valueOp, valueSize) = context.decodeOperand(from: payload, at: start + 4)
        let overlayValue = context.resolveUnchecked(valueOp)

        var offset = start + 4 + valueSize

        // Decode path (string-table indices)
        let pathCount = context.decodeUInt32(from: payload, at: offset)
        offset += 4

        var path: [String] = []
        path.reserveCapacity(Int(pathCount))
        for _ in 0..<Int(pathCount) {
            let stringIndex = Int(context.decodeUInt32(from: payload, at: offset))
            offset += 4
            path.append(policy.strings[stringIndex])
        }

        // Block starts at `offset` — fills the remainder of the payload
        let blockOffset = offset
        let blockSize = length - (offset - start)

        // Save current value, apply patch at path
        let toPatch = context.resolveLocal(idx: local)
        let patched = toPatch.patch(with: overlayValue, at: path)
        context.assignLocal(idx: local, value: patched)

        // Push a fresh memo cache for the with-block.
        // `with` patches input/data locals, so any memoized call results from the enclosing
        // scope are stale inside the block — a called rule may return a different value when
        // it sees the patched data.  The cache is popped in the defer, restoring the outer scope.
        context.pushMemoCache()
        defer {
            context.popMemoCache()
            context.assignLocal(idx: local, value: toPatch)
        }

        let result = try await self.executeBlock(
            context: context,
            offset: blockOffset,
            size: blockSize
        )

        // Respect the break index from a sub block
        if result.shouldBreak {
            return result.breakByOne()
        }

        // Propagate undefined
        if result.isUndefined {
            return failWithUndefinedBytecode(context: context)
        }

        return result
    }
}
