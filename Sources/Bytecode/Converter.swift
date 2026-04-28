import AST
import Foundation
import IR

/// Converts IR.Policy to Policy
public struct Converter {

    /// Convert an IR.Policy to Policy
    public static func convert(_ policy: IR.Policy) throws -> Policy {
        var functionIndices: [String: Int] = [:]
        for (index, function) in (policy.funcs?.funcs ?? []).enumerated() {
            functionIndices[function.name] = index
        }

        let numbers = buildNumberTable(from: policy)

        var context = ConversionContext(functionIndices: functionIndices, numbers: numbers)

        let staticStrings = policy.staticData?.strings ?? []
        for constString in staticStrings {
            _ = context.stringTable.intern(constString.value)
        }

        // Convert plans
        var plans: [Plan] = []
        for plan in policy.plans?.plans ?? [] {
            let planBytecode = try convertPlan(plan, context: &context)
            plans.append(planBytecode)
        }

        // Convert functions
        var functions: [Function] = []
        for function in policy.funcs?.funcs ?? [] {
            let funcBytecode = try convertFunction(function, context: &context)
            functions.append(funcBytecode)
        }

        let bytecode = context.encoder.bytes

        let policy = Policy(
            strings: context.stringTable.table,
            numbers: numbers,
            functions: functions,
            plans: plans,
            bytecode: bytecode,
            builtinFuncs: policy.staticData?.builtinFuncs ?? []
        )
        try policy.validate()
        return policy
    }

    // MARK: - Plan Conversion

    private static func convertPlan(_ plan: IR.Plan, context: inout ConversionContext) throws -> Plan {
        var plan = plan
        plan.computeMaxLocal()
        let startOffset = context.currentOffset
        var blocks: [(offset: Int, size: Int, syncSafe: Bool)] = []

        for block in plan.blocks {
            let blockStart = context.currentOffset
            try convertBlock(block, context: &context)
            blocks.append((offset: blockStart, size: context.currentOffset - blockStart, syncSafe: false))
        }

        return Plan(
            name: plan.name,
            maxLocal: plan.maxLocal,
            bytecodeOffset: startOffset,
            bytecodeSize: context.currentOffset - startOffset,
            blocks: blocks
        )
    }

    // MARK: - Function Conversion

    private static func convertFunction(_ function: IR.Func, context: inout ConversionContext) throws -> Function {
        var function = function
        function.computeMaxLocal()
        let startOffset = context.currentOffset
        var blocks: [(offset: Int, size: Int)] = []

        // Encode each block sequentially and record individual block boundaries.
        // The VM uses executeBlocks() to iterate them with the correct OR semantics,
        // so no block-wrapper instruction is needed here.
        for block in function.blocks {
            let blockStart = context.currentOffset
            try convertBlock(block, context: &context)
            blocks.append((offset: blockStart, size: context.currentOffset - blockStart))
        }

        return Function(
            name: function.name,
            path: function.path,
            params: function.params,
            returnVar: function.returnVar,
            maxLocal: function.maxLocal,
            bytecodeOffset: startOffset,
            bytecodeSize: context.currentOffset - startOffset,
            blocks: blocks
        )
    }

    // MARK: - Block Conversion

    private static func convertBlock(_ block: IR.Block, context: inout ConversionContext) throws {
        for statement in block.statements {
            try convertStatement(statement, context: &context)
        }
    }

    // MARK: - Statement Conversion

    private static func convertStatement(_ statement: IR.Statement, context: inout ConversionContext) throws {
        switch statement {
        case .arrayAppendStmt(let stmt):
            try convertArrayAppend(stmt, context: &context)
        case .assignIntStmt(let stmt):
            try convertAssignInt(stmt, context: &context)
        case .assignVarOnceStmt(let stmt):
            try convertAssignVarOnce(stmt, context: &context)
        case .assignVarStmt(let stmt):
            try convertAssignVar(stmt, context: &context)
        case .blockStmt(let stmt):
            try convertBlockStmt(stmt, context: &context)
        case .breakStmt(let stmt):
            try convertBreak(stmt, context: &context)
        case .callStmt(let stmt):
            try convertCall(stmt, context: &context)
        case .callDynamicStmt(let stmt):
            try convertCallDynamic(stmt, context: &context)
        case .dotStmt(let stmt):
            try convertDot(stmt, context: &context)
        case .equalStmt(let stmt):
            try convertEqual(stmt, context: &context)
        case .isArrayStmt(let stmt):
            try convertIsArray(stmt, context: &context)
        case .isDefinedStmt(let stmt):
            try convertIsDefined(stmt, context: &context)
        case .isObjectStmt(let stmt):
            try convertIsObject(stmt, context: &context)
        case .isSetStmt(let stmt):
            try convertIsSet(stmt, context: &context)
        case .isUndefinedStmt(let stmt):
            try convertIsUndefined(stmt, context: &context)
        case .lenStmt(let stmt):
            try convertLen(stmt, context: &context)
        case .makeArrayStmt(let stmt):
            try convertMakeArray(stmt, context: &context)
        case .makeNullStmt(let stmt):
            try convertMakeNull(stmt, context: &context)
        case .makeNumberIntStmt(let stmt):
            try convertMakeNumberInt(stmt, context: &context)
        case .makeNumberRefStmt(let stmt):
            try convertMakeNumberRef(stmt, context: &context)
        case .makeObjectStmt(let stmt):
            try convertMakeObject(stmt, context: &context)
        case .makeSetStmt(let stmt):
            try convertMakeSet(stmt, context: &context)
        case .nopStmt(let stmt):
            try convertNop(stmt, context: &context)
        case .notEqualStmt(let stmt):
            try convertNotEqual(stmt, context: &context)
        case .notStmt(let stmt):
            try convertNot(stmt, context: &context)
        case .objectInsertOnceStmt(let stmt):
            try convertObjectInsertOnce(stmt, context: &context)
        case .objectInsertStmt(let stmt):
            try convertObjectInsert(stmt, context: &context)
        case .objectMergeStmt(let stmt):
            try convertObjectMerge(stmt, context: &context)
        case .resetLocalStmt(let stmt):
            try convertResetLocal(stmt, context: &context)
        case .resultSetAddStmt(let stmt):
            try convertResultSetAdd(stmt, context: &context)
        case .returnLocalStmt(let stmt):
            try convertReturnLocal(stmt, context: &context)
        case .scanStmt(let stmt):
            try convertScan(stmt, context: &context)
        case .setAddStmt(let stmt):
            try convertSetAdd(stmt, context: &context)
        case .withStmt(let stmt):
            try convertWith(stmt, context: &context)
        case .unknown:
            throw Error.invalidOpcode(0xFF)
        }
    }

    // MARK: - Individual Statement Converters

    private static func convertArrayAppend(_ stmt: IR.ArrayAppendStatement, context: inout ConversionContext) throws {
        let operand = try context.convertOperand(stmt.value)
        let payloadSize = 4 + operand.encodedSize  // local (4) + operand

        context.encoder.appendHeader(.arrayAppend, payloadLength: UInt32(payloadSize))
        context.encoder.appendLocal(stmt.array)
        context.encoder.appendOperand(operand)
    }

    private static func convertAssignInt(_ stmt: IR.AssignIntStatement, context: inout ConversionContext) throws {
        let payloadSize = 8 + 4  // int64 (8) + local (4)

        context.encoder.appendHeader(.assignInt, payloadLength: UInt32(payloadSize))
        context.encoder.appendInt64(stmt.value)
        context.encoder.appendLocal(stmt.target)
    }

    private static func convertAssignVarOnce(_ stmt: IR.AssignVarOnceStatement, context: inout ConversionContext) throws
    {
        let operand = try context.convertOperand(stmt.source)
        let payloadSize = 4 + operand.encodedSize  // target (4) + operand

        context.encoder.appendHeader(.assignVarOnce, payloadLength: UInt32(payloadSize))
        context.encoder.appendLocal(stmt.target)
        context.encoder.appendOperand(operand)
    }

    private static func convertAssignVar(_ stmt: IR.AssignVarStatement, context: inout ConversionContext) throws {
        let operand = try context.convertOperand(stmt.source)
        // Compact form: when source is a local and both indices fit in 12 bits,
        // pack [target:12 | source:12] into the header length field — zero payload.
        if operand.type == .local,
            stmt.target <= 0xFFF,
            operand.value <= 0xFFF
        {
            let packed = (UInt32(stmt.target) << 12) | operand.value
            context.encoder.appendHeader(.assignVar1, payloadLength: packed)
            return
        }
        let payloadSize = 4 + operand.encodedSize  // target (4) + operand
        context.encoder.appendHeader(.assignVar, payloadLength: UInt32(payloadSize))
        context.encoder.appendLocal(stmt.target)
        context.encoder.appendOperand(operand)
    }

    private static func convertBlockStmt(_ stmt: IR.BlockStatement, context: inout ConversionContext) throws {
        let blocks = stmt.blocks ?? []

        // Single sub-block — emit block1.
        // Payload IS the block content; offset/size are derived at decode time from payloadStart/length.
        if blocks.count == 1 {
            let headerPosition = context.encoder.reserveHeader()
            let blockStart = context.currentOffset
            try convertBlock(blocks[0], context: &context)
            let blockSize = context.currentOffset - blockStart
            context.encoder.fillHeader(at: headerPosition, opcode: .block1, payloadLength: UInt32(blockSize))
            return
        }

        // General case (0 or 2+ sub-blocks): use the block encoding with explicit references.
        let headerPos = context.encoder.reserveHeader()
        let payloadStartOffset = context.currentOffset

        // Encode number of blocks
        context.encoder.appendUInt32(UInt32(blocks.count))

        // Reserve space for block offsets and sizes
        var offsetPositions: [(offsetPos: Int, sizePos: Int)] = []
        for _ in blocks {
            let offsetPos = context.encoder.reserveUInt32()  // Reserve offset
            let sizePos = context.encoder.reserveUInt32()  // Reserve size
            offsetPositions.append((offsetPos, sizePos))
        }

        // Convert each nested block and record its offset/size
        for (index, nestedBlock) in blocks.enumerated() {
            let blockStartOffset = context.currentOffset
            try convertBlock(nestedBlock, context: &context)
            let blockSize = context.currentOffset - blockStartOffset

            // Fill in the block offset and size
            context.encoder.fillUInt32(at: offsetPositions[index].offsetPos, value: UInt32(blockStartOffset))
            context.encoder.fillUInt32(at: offsetPositions[index].sizePos, value: UInt32(blockSize))
        }

        // Now that we've converted all nested blocks, we know the total payload size
        // Payload includes: numBlocks + offsets/sizes + all nested blocks' bytecode
        let totalPayloadSize = context.currentOffset - payloadStartOffset
        context.encoder.fillHeader(at: headerPos, opcode: .block, payloadLength: UInt32(totalPayloadSize))
    }

    private static func convertBreak(_ stmt: IR.BreakStatement, context: inout ConversionContext) throws {
        // Compact form: break index fits in 24 bits (it's a small nesting depth counter)
        context.encoder.appendHeader(.break1, payloadLength: UInt32(stmt.index))
    }

    private static func convertCall(_ stmt: IR.CallStatement, context: inout ConversionContext) throws {
        let operands = try context.convertOperands(stmt.args ?? [])
        let operandsSize = operands.reduce(0) { $0 + $1.encodedSize }

        // Determine if this is a user function or builtin
        let encodedFuncIndex: UInt32
        if let funcIndex = context.functionIndices[stmt.callFunc] {
            // User-defined function: use function index directly (high bit clear)
            encodedFuncIndex = UInt32(funcIndex)
        } else {
            // Builtin function: intern name in string table and set high bit
            let builtinNameIndex = context.stringTable.intern(stmt.callFunc)
            encodedFuncIndex = 0x8000_0000 | UInt32(builtinNameIndex)
        }

        let payloadSize = 4 + 4 + 4 + operandsSize  // result (4) + func index (4) + count (4) + operands

        context.encoder.appendHeader(.call, payloadLength: UInt32(payloadSize))
        context.encoder.appendLocal(stmt.result)
        context.encoder.appendUInt32(encodedFuncIndex)
        context.encoder.appendOperandArray(operands)
    }

    private static func convertCallDynamic(_ stmt: IR.CallDynamicStatement, context: inout ConversionContext) throws {
        let path = try context.convertOperands(stmt.path)
        let args = stmt.args.map { EncodedOperand.local(UInt32($0)) }
        let pathSize = path.reduce(0) { $0 + $1.encodedSize }
        let argsSize = args.reduce(0) { $0 + $1.encodedSize }
        // result (4) + path count (4) + path + args count (4) + args
        let payloadSize = 4 + 4 + pathSize + 4 + argsSize

        context.encoder.appendHeader(.callDynamic, payloadLength: UInt32(payloadSize))
        context.encoder.appendLocal(stmt.result)
        context.encoder.appendOperandArray(path)
        context.encoder.appendOperandArray(args)
    }

    private static func convertDot(_ stmt: IR.DotStatement, context: inout ConversionContext) throws {
        let source = try context.convertOperand(stmt.source)
        let key = try context.convertOperand(stmt.key)
        let payloadSize = source.encodedSize + key.encodedSize + 4  // source + key + target (4)

        context.encoder.appendHeader(.dot, payloadLength: UInt32(payloadSize))
        context.encoder.appendOperand(source)
        context.encoder.appendOperand(key)
        context.encoder.appendLocal(stmt.target)
    }

    private static func convertEqual(_ stmt: IR.EqualStatement, context: inout ConversionContext) throws {
        let a = try context.convertOperand(stmt.a)
        let b = try context.convertOperand(stmt.b)
        let payloadSize = a.encodedSize + b.encodedSize  // a + b

        context.encoder.appendHeader(.equal, payloadLength: UInt32(payloadSize))
        context.encoder.appendOperand(a)
        context.encoder.appendOperand(b)
    }

    private static func convertIsArray(_ stmt: IR.IsArrayStatement, context: inout ConversionContext) throws {
        let operand = try context.convertOperand(stmt.source)
        let payloadSize = operand.encodedSize

        context.encoder.appendHeader(.isArray, payloadLength: UInt32(payloadSize))
        context.encoder.appendOperand(operand)
    }

    private static func convertIsDefined(_ stmt: IR.IsDefinedStatement, context: inout ConversionContext) throws {
        // Compact form: local index fits in 24 bits
        context.encoder.appendHeader(.isDefined1, payloadLength: UInt32(stmt.source))
    }

    private static func convertIsObject(_ stmt: IR.IsObjectStatement, context: inout ConversionContext) throws {
        let operand = try context.convertOperand(stmt.source)
        let payloadSize = operand.encodedSize

        context.encoder.appendHeader(.isObject, payloadLength: UInt32(payloadSize))
        context.encoder.appendOperand(operand)
    }

    private static func convertIsSet(_ stmt: IR.IsSetStatement, context: inout ConversionContext) throws {
        let operand = try context.convertOperand(stmt.source)
        let payloadSize = operand.encodedSize

        context.encoder.appendHeader(.isSet, payloadLength: UInt32(payloadSize))
        context.encoder.appendOperand(operand)
    }

    private static func convertIsUndefined(_ stmt: IR.IsUndefinedStatement, context: inout ConversionContext) throws {
        // Compact form: local index fits in 24 bits
        context.encoder.appendHeader(.isUndefined1, payloadLength: UInt32(stmt.source))
    }

    private static func convertLen(_ stmt: IR.LenStatement, context: inout ConversionContext) throws {
        let source = try context.convertOperand(stmt.source)
        let payloadSize = source.encodedSize + 4  // source + target (4)

        context.encoder.appendHeader(.len, payloadLength: UInt32(payloadSize))
        context.encoder.appendOperand(source)
        context.encoder.appendLocal(stmt.target)
    }

    private static func convertMakeArray(_ stmt: IR.MakeArrayStatement, context: inout ConversionContext) throws {
        let payloadSize = 4 + 4  // capacity (4) + target (4)

        context.encoder.appendHeader(.makeArray, payloadLength: UInt32(payloadSize))
        context.encoder.appendUInt32(UInt32(stmt.capacity))
        context.encoder.appendLocal(stmt.target)
    }

    private static func convertMakeNull(_ stmt: IR.MakeNullStatement, context: inout ConversionContext) throws {
        let payloadSize = 4  // target (4)

        context.encoder.appendHeader(.makeNull, payloadLength: UInt32(payloadSize))
        context.encoder.appendLocal(stmt.target)
    }

    private static func convertMakeNumberInt(_ stmt: IR.MakeNumberIntStatement, context: inout ConversionContext) throws
    {
        let payloadSize = 8 + 4  // value (8) + target (4)

        context.encoder.appendHeader(.makeNumberInt, payloadLength: UInt32(payloadSize))
        context.encoder.appendInt64(stmt.value)
        context.encoder.appendLocal(stmt.target)
    }

    private static func convertMakeNumberRef(_ stmt: IR.MakeNumberRefStatement, context: inout ConversionContext) throws
    {
        let payloadSize = 4 + 4  // index (4) + target (4)

        context.encoder.appendHeader(.makeNumberRef, payloadLength: UInt32(payloadSize))
        context.encoder.appendUInt32(UInt32(stmt.index))
        context.encoder.appendLocal(stmt.target)
    }

    private static func convertMakeObject(_ stmt: IR.MakeObjectStatement, context: inout ConversionContext) throws {
        let payloadSize = 4  // target (4)

        context.encoder.appendHeader(.makeObject, payloadLength: UInt32(payloadSize))
        context.encoder.appendLocal(stmt.target)
    }

    private static func convertMakeSet(_ stmt: IR.MakeSetStatement, context: inout ConversionContext) throws {
        let payloadSize = 4  // target (4)

        context.encoder.appendHeader(.makeSet, payloadLength: UInt32(payloadSize))
        context.encoder.appendLocal(stmt.target)
    }

    private static func convertNop(_ stmt: IR.NopStatement, context: inout ConversionContext) throws {
        let payloadSize = 0  // no payload

        context.encoder.appendHeader(.nop, payloadLength: UInt32(payloadSize))
    }

    private static func convertNotEqual(_ stmt: IR.NotEqualStatement, context: inout ConversionContext) throws {
        let a = try context.convertOperand(stmt.a)
        let b = try context.convertOperand(stmt.b)
        let payloadSize = a.encodedSize + b.encodedSize  // a + b

        context.encoder.appendHeader(.notEqual, payloadLength: UInt32(payloadSize))
        context.encoder.appendOperand(a)
        context.encoder.appendOperand(b)
    }

    private static func convertNot(_ stmt: IR.NotStatement, context: inout ConversionContext) throws {
        // Reserve space for header (will fill in payload size later)
        let headerPosition = context.encoder.reserveHeader()

        // Convert the block inline — payload IS the block content
        let blockStart = context.currentOffset
        try convertBlock(stmt.block, context: &context)
        let blockSize = context.currentOffset - blockStart

        context.encoder.fillHeader(at: headerPosition, opcode: .not, payloadLength: UInt32(blockSize))
    }

    private static func convertObjectInsertOnce(_ stmt: IR.ObjectInsertOnceStatement, context: inout ConversionContext)
        throws
    {
        let key = try context.convertOperand(stmt.key)
        let value = try context.convertOperand(stmt.value)
        let payloadSize = 4 + key.encodedSize + value.encodedSize  // object (4) + key + value

        context.encoder.appendHeader(.objectInsertOnce, payloadLength: UInt32(payloadSize))
        context.encoder.appendLocal(stmt.object)
        context.encoder.appendOperand(key)
        context.encoder.appendOperand(value)
    }

    private static func convertObjectInsert(_ stmt: IR.ObjectInsertStatement, context: inout ConversionContext) throws {
        let key = try context.convertOperand(stmt.key)
        let value = try context.convertOperand(stmt.value)
        let payloadSize = 4 + key.encodedSize + value.encodedSize  // object (4) + key + value

        context.encoder.appendHeader(.objectInsert, payloadLength: UInt32(payloadSize))
        context.encoder.appendLocal(stmt.object)
        context.encoder.appendOperand(key)
        context.encoder.appendOperand(value)
    }

    private static func convertObjectMerge(_ stmt: IR.ObjectMergeStatement, context: inout ConversionContext) throws {
        let a = EncodedOperand.local(UInt32(stmt.a))
        let b = EncodedOperand.local(UInt32(stmt.b))
        let payloadSize = 4 + a.encodedSize + b.encodedSize  // target (4) + a + b

        context.encoder.appendHeader(.objectMerge, payloadLength: UInt32(payloadSize))
        context.encoder.appendLocal(stmt.target)
        context.encoder.appendOperand(a)
        context.encoder.appendOperand(b)
    }

    private static func convertResetLocal(_ stmt: IR.ResetLocalStatement, context: inout ConversionContext) throws {
        // Compact form: local index fits in 24 bits
        context.encoder.appendHeader(.resetLocal1, payloadLength: UInt32(stmt.target))
    }

    private static func convertResultSetAdd(_ stmt: IR.ResultSetAddStatement, context: inout ConversionContext) throws {
        // Compact form: local index fits in 24 bits
        context.encoder.appendHeader(.resultSetAdd1, payloadLength: UInt32(stmt.value))
    }

    private static func convertReturnLocal(_ stmt: IR.ReturnLocalStatement, context: inout ConversionContext) throws {
        // Compact form: local index fits in 24 bits
        context.encoder.appendHeader(.returnLocal1, payloadLength: UInt32(stmt.source))
    }

    private static func convertScan(_ stmt: IR.ScanStatement, context: inout ConversionContext) throws {
        // Reserve space for header (payload size is unknown until block is converted)
        let headerPosition = context.encoder.reserveHeader()
        let payloadStartOffset = context.currentOffset

        context.encoder.appendLocal(stmt.source)
        context.encoder.appendLocal(stmt.key)
        context.encoder.appendLocal(stmt.value)

        // Convert the block inline immediately after the three locals — block offset/size derived at runtime
        try convertBlock(stmt.block, context: &context)

        // Fill in the header: source(4)+key(4)+value(4)+block
        let totalPayloadSize = context.currentOffset - payloadStartOffset
        context.encoder.fillHeader(at: headerPosition, opcode: .scan, payloadLength: UInt32(totalPayloadSize))
    }

    private static func convertSetAdd(_ stmt: IR.SetAddStatement, context: inout ConversionContext) throws {
        let operand = try context.convertOperand(stmt.value)
        let payloadSize = 4 + operand.encodedSize  // set (4) + operand

        context.encoder.appendHeader(.setAdd, payloadLength: UInt32(payloadSize))
        context.encoder.appendLocal(stmt.set)
        context.encoder.appendOperand(operand)
    }

    private static func convertWith(_ stmt: IR.WithStatement, context: inout ConversionContext) throws {
        let value = try context.convertOperand(stmt.value)
        let pathIndices = stmt.path ?? []

        // Reserve space for header (payload size is unknown until block is converted)
        let headerPosition = context.encoder.reserveHeader()
        let payloadStartOffset = context.currentOffset

        context.encoder.appendLocal(stmt.local)
        context.encoder.appendOperand(value)

        // Encode path: count + string-table indices (mirrors IR.WithStatement.path)
        context.encoder.appendUInt32(UInt32(pathIndices.count))
        for idx in pathIndices {
            context.encoder.appendUInt32(UInt32(bitPattern: idx))
        }

        // Convert the block inline immediately after path — block offset/size derived at runtime
        try convertBlock(stmt.block, context: &context)

        // Fill in header: local(4)+value(variable)+pathCount(4)+pathIndices(4*n)+block
        let totalPayloadSize = context.currentOffset - payloadStartOffset
        context.encoder.fillHeader(at: headerPosition, opcode: .with, payloadLength: UInt32(totalPayloadSize))
    }

    // MARK: - Number Table Building

    private static func buildNumberTable(from policy: IR.Policy) -> [RegoNumber?] {
        let staticStrings = policy.staticData?.strings ?? []
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .decimal
        numberFormatter.locale = Locale(identifier: "en_US_POSIX")  // Use consistent locale

        var numbers: [RegoNumber?] = []
        numbers.reserveCapacity(staticStrings.count)

        let numberIndices = Set(policy.staticStringNumbers)

        // Build numbers array: parse strings that are marked as numeric literals
        for (index, constString) in staticStrings.enumerated() {
            if numberIndices.contains(index) {
                // Try Decimal(string:) first — handles large integers and arbitrary precision.
                // Fall back to NumberFormatter for edge cases it may not handle.
                if let decimal = Decimal(string: constString.value) {
                    numbers.append(RegoNumber(decimal))
                } else if let nsNum = numberFormatter.number(from: constString.value) {
                    numbers.append(RegoNumber(nsNumber: nsNum))
                } else {
                    numbers.append(nil)
                }
            } else {
                // Not a number - append nil
                numbers.append(nil)
            }
        }

        return numbers
    }
}
