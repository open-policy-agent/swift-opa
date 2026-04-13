import AST
import IR

/// Bytecode-encoded policy container
public struct Policy: Sendable {
    /// String table - interned strings referenced by index
    public let strings: [String]

    /// Number table - pre-parsed numbers referenced by index
    public let numbers: [RegoNumber?]

    /// Function metadata
    public let functions: [Function]

    /// Plan metadata
    public let plans: [Plan]

    /// Bytecode instruction stream
    public let bytecode: ContiguousArray<UInt8>

    /// Builtin functions required by this policy (from IR static data)
    public let builtinFuncs: [IR.BuiltinFunc]

    public init(
        strings: [String],
        numbers: [RegoNumber?],
        functions: [Function],
        plans: [Plan],
        bytecode: ContiguousArray<UInt8>,
        builtinFuncs: [IR.BuiltinFunc] = []
    ) {
        self.strings = strings
        self.numbers = numbers
        self.functions = functions
        self.plans = plans
        self.bytecode = bytecode
        self.builtinFuncs = builtinFuncs
    }

    // MARK: - Validation

    /// Validate the bytecode policy in a single pass before execution.
    ///
    /// Walks every reachable block (seeded from plan and function blocks, with nested blocks
    /// discovered as instructions are validated) and checks:
    /// - Block offset+size fits within the bytecode buffer
    /// - Every instruction header is readable and contains a valid opcode
    /// - Every instruction payload fits within the bytecode buffer
    /// - Per-opcode: all string/number/function index references are in bounds
    ///
    /// Call this once at load/conversion time so the VM hot loop can skip these checks.
    public func validate() throws {
        var worklist: [(offset: Int, size: Int, maxLocal: Int)] = []
        for plan in plans {
            for block in plan.blocks {
                worklist.append((block.offset, block.size, plan.maxLocal))
            }
        }
        for function in functions {
            for block in function.blocks {
                worklist.append((block.offset, block.size, function.maxLocal))
            }
        }

        var validated = Set<Int>()

        while let block = worklist.popLast() {
            guard validated.insert(block.offset).inserted else { continue }
            let nested = try validateBlock(offset: block.offset, size: block.size, maxLocal: block.maxLocal)
            worklist.append(contentsOf: nested.map { ($0.offset, $0.size, block.maxLocal) })
        }
    }

    private func validateBlock(offset: Int, size: Int, maxLocal: Int) throws -> [(offset: Int, size: Int)] {
        guard offset >= 0, offset + size <= bytecode.count else {
            throw Error.unexpectedEndOfBytecode
        }

        var pc = offset
        let endOffset = offset + size
        var nestedBlocks: [(offset: Int, size: Int)] = []

        while pc < endOffset {
            guard pc + 4 <= bytecode.count else {
                throw Error.unexpectedEndOfBytecode
            }

            let headerValue =
                UInt32(bytecode[pc]) | UInt32(bytecode[pc + 1]) << 8 | UInt32(bytecode[pc + 2]) << 16 | UInt32(
                    bytecode[pc + 3]) << 24
            let rawOpcode = UInt8((headerValue >> 24) & 0x3F)
            guard Opcode(rawValue: rawOpcode) != nil else {
                throw Error.invalidOpcode(rawOpcode)
            }
            let header = try InstructionHeader.decode(headerValue)
            pc += 4

            let payloadStart = pc
            // Compact opcodes encode their operand in header.length; their payload is 0 bytes.
            let payloadSize = header.opcode.isCompact ? 0 : Int(header.length)
            let payloadEnd = pc + payloadSize
            guard payloadEnd <= bytecode.count else {
                throw Error.unexpectedEndOfBytecode
            }

            let nested = try InstructionHeader.validatePayload(
                opcode: header.opcode,
                payload: bytecode,
                start: payloadStart,
                length: Int(header.length),
                strings: strings,
                numbers: numbers,
                functions: functions,
                maxLocal: maxLocal
            )
            nestedBlocks.append(contentsOf: nested)
            pc = payloadEnd
        }

        return nestedBlocks
    }
}

/// Bytecode function metadata
public struct Function: Sendable {
    public let name: String
    public let path: [String]
    public let params: [Local]
    public let returnVar: Local
    public let maxLocal: Int
    public let bytecodeOffset: Int
    public let bytecodeSize: Int
    /// Individual block (offset, size) pairs — mirrors IR.Func.blocks
    public let blocks: [(offset: Int, size: Int)]

    public init(
        name: String,
        path: [String],
        params: [Local],
        returnVar: Local,
        maxLocal: Int,
        bytecodeOffset: Int,
        bytecodeSize: Int,
        blocks: [(offset: Int, size: Int)]
    ) {
        self.name = name
        self.path = path
        self.params = params
        self.returnVar = returnVar
        self.maxLocal = maxLocal
        self.bytecodeOffset = bytecodeOffset
        self.bytecodeSize = bytecodeSize
        self.blocks = blocks
    }
}

/// Bytecode plan metadata
public struct Plan: Sendable {
    public let name: String
    public let maxLocal: Int
    public let bytecodeOffset: Int
    public let bytecodeSize: Int
    /// Individual block (offset, size, syncSafe) triples — mirrors IR.Plan.blocks.
    /// `syncSafe` is set by `SyncSafePatcher`; defaults to `false` until then.
    public let blocks: [(offset: Int, size: Int, syncSafe: Bool)]
    /// `true` when every block in this plan is sync-safe.
    /// Populated by `SyncSafePatcher`; `false` until then.
    public let syncSafe: Bool

    public init(
        name: String,
        maxLocal: Int,
        bytecodeOffset: Int,
        bytecodeSize: Int,
        blocks: [(offset: Int, size: Int, syncSafe: Bool)] = [],
        syncSafe: Bool = false
    ) {
        self.name = name
        self.maxLocal = maxLocal
        self.bytecodeOffset = bytecodeOffset
        self.bytecodeSize = bytecodeSize
        self.blocks = blocks
        self.syncSafe = syncSafe
    }
}
