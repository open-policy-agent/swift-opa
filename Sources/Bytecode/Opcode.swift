import AST
import Foundation

/// Bytecode opcode representing an IR statement type
public enum Opcode: UInt8, Sendable {
    // Assignment operations
    case arrayAppend = 0
    case assignInt = 1
    case assignVarOnce = 2
    case assignVar = 3

    // Control flow
    case block = 4
    case `break` = 5
    case call = 6
    case callDynamic = 7

    // Operations
    case dot = 8
    case equal = 9

    // Type checks
    case isArray = 10
    case isDefined = 11
    case isObject = 12
    case isSet = 13
    case isUndefined = 14

    // Built-in operations
    case len = 15

    // Value construction
    case makeArray = 16
    case makeNull = 17
    case makeNumberInt = 18
    case makeNumberRef = 19
    case makeObject = 20
    case makeSet = 21

    // Control and comparison
    case nop = 22
    case notEqual = 23
    case not = 24

    // Object operations
    case objectInsertOnce = 25
    case objectInsert = 26
    case objectMerge = 27

    // Variable management
    case resetLocal = 28
    case resultSetAdd = 29
    case returnLocal = 30

    // Collection operations
    case scan = 31
    case setAdd = 32
    case with = 33

    // Optimized single-sub-block variant of block
    case block1 = 34

    // Compact single-operand variants: operand is stored in the header length field (24 bits),
    // so the entire instruction fits in one 4-byte word with no separate payload.
    case isDefined1 = 35
    case isUndefined1 = 36
    case resetLocal1 = 37
    case resultSetAdd1 = 38
    case returnLocal1 = 39
    case break1 = 40

    // Compact 2-operand variant: [target:12 | source:12] packed in the header length field.
    case assignVar1 = 41

    /// True for compact opcodes whose operand is stored in the header length field (zero payload bytes).
    var isCompact: Bool {
        switch self {
        case .isDefined1, .isUndefined1, .resetLocal1, .resultSetAdd1, .returnLocal1, .break1,
             .assignVar1:
            return true
        default:
            return false
        }
    }
}

/// Instruction header encoding/decoding
public struct InstructionHeader: Sendable {
    public let opcode: Opcode
    public let length: UInt32  // Payload length in bytes (24-bit)

    public init(opcode: Opcode, length: UInt32) {
        assert(length <= 0xFFFFFF, "Payload length must fit in 24 bits")
        self.opcode = opcode
        self.length = length
    }

    /// Encode header as 4-byte value: [Reserved: 2 bits | Opcode: 6 bits | Length: 24 bits]
    public func encode() -> UInt32 {
        let opcodeValue = UInt32(opcode.rawValue)
        assert(opcodeValue <= 0x3F, "Opcode must fit in 6 bits")
        return (opcodeValue << 24) | (length & 0xFFFFFF)
    }

    /// Decode header from 4-byte value.
    /// Throws `Error.invalidOpcode` if the opcode field is not a valid `Opcode` raw value.
    public static func decode(_ value: UInt32) throws -> InstructionHeader {
        let opcodeValue = UInt8((value >> 24) & 0x3F)
        guard let opcode = Opcode(rawValue: opcodeValue) else {
            throw Error.invalidOpcode(opcodeValue)
        }
        let length = value & 0xFFFFFF
        return InstructionHeader(opcode: opcode, length: length)
    }

    // MARK: - Payload validation

    /// Validate an instruction's payload, returning any nested (offset, size) block pairs found.
    ///
    /// Called once per instruction during the load-time validation pass. The caller has already
    /// verified that `payload[start ..< start+length]` lies within the bytecode buffer.
    ///
    /// - Parameters:
    ///   - payload: the full bytecode `Data` buffer
    ///   - start: absolute start offset of this instruction's payload within `payload`
    ///   - length: payload length as recorded in the instruction header
    ///   - strings: string table from the policy
    ///   - numbers: number table from the policy
    ///   - functions: function table from the policy
    ///   - maxLocal: highest valid local index for the enclosing frame
    /// - Returns: nested `(offset, size)` block pairs embedded in this instruction (e.g. for
    ///   `block`, `not`, `scan`, `with` opcodes) that the caller must also validate.
    public static func validatePayload(
        opcode: Opcode,
        payload: ContiguousArray<UInt8>,
        start: Int,
        length: Int,
        strings: [String],
        numbers: [RegoNumber?],
        functions: [Function],
        maxLocal: Int
    ) throws -> [(offset: Int, size: Int)] {
        switch opcode {

        // ── No locals or table indices ────────────────────────────────────────────
        case .nop, .break:
            return []

        // ── Compact single-operand variants (operand in header.length, zero payload) ─
        case .break1:
            return []

        case .isDefined1, .isUndefined1, .resetLocal1, .resultSetAdd1, .returnLocal1:
            try validateLocal(UInt32(length), maxLocal: maxLocal)
            return []

        case .assignVar1:
            // [target:12 | source:12] packed in the header length field.
            try validateLocal(UInt32(length) >> 12, maxLocal: maxLocal)
            try validateLocal(UInt32(length) & 0xFFF, maxLocal: maxLocal)
            return []

        // ── Single-local target ───────────────────────────────────────────────────
        case .makeNull, .makeObject, .makeSet:
            // [target: Local (4)]
            try validateLocal(readUInt32(payload, at: start), maxLocal: maxLocal)
            return []

        case .isDefined, .isUndefined, .resetLocal, .resultSetAdd, .returnLocal:
            // [source/local/value: Local (4)]
            try validateLocal(readUInt32(payload, at: start), maxLocal: maxLocal)
            return []

        case .makeArray:
            // [capacity: UInt32 (4)][target: Local (4)]
            try validateLocal(readUInt32(payload, at: start + 4), maxLocal: maxLocal)
            return []

        case .assignInt, .makeNumberInt:
            // [value: Int64 (8)][target: Local (4)]
            try validateLocal(readUInt32(payload, at: start + 8), maxLocal: maxLocal)
            return []

        case .objectMerge:
            // [target: Local (4)][a: Local (4)][b: Local (4)]
            try validateLocal(readUInt32(payload, at: start),     maxLocal: maxLocal)
            try validateLocal(readUInt32(payload, at: start + 4), maxLocal: maxLocal)
            try validateLocal(readUInt32(payload, at: start + 8), maxLocal: maxLocal)
            return []

        // ── Single operand ───────────────────────────────────────────────────────
        case .arrayAppend:
            // [array: Local (4)][value: Operand]
            try validateLocal(readUInt32(payload, at: start), maxLocal: maxLocal)
            var off = start + 4
            try validateOperand(payload: payload, at: &off, strings: strings, numbers: numbers, maxLocal: maxLocal)
            return []

        case .assignVarOnce, .assignVar:
            // [target: Local (4)][source: Operand]
            try validateLocal(readUInt32(payload, at: start), maxLocal: maxLocal)
            var off = start + 4
            try validateOperand(payload: payload, at: &off, strings: strings, numbers: numbers, maxLocal: maxLocal)
            return []

        case .isArray, .isObject, .isSet:
            // [source: Operand]
            var off = start
            try validateOperand(payload: payload, at: &off, strings: strings, numbers: numbers, maxLocal: maxLocal)
            return []

        case .len:
            // [source: Operand][target: Local (4)]
            var off = start
            try validateOperand(payload: payload, at: &off, strings: strings, numbers: numbers, maxLocal: maxLocal)
            guard off + 4 <= start + length else { throw Error.invalidPayloadLength }
            try validateLocal(readUInt32(payload, at: off), maxLocal: maxLocal)
            return []

        case .setAdd:
            // [set: Local (4)][value: Operand]
            try validateLocal(readUInt32(payload, at: start), maxLocal: maxLocal)
            var off = start + 4
            try validateOperand(payload: payload, at: &off, strings: strings, numbers: numbers, maxLocal: maxLocal)
            return []

        // ── Two operands ─────────────────────────────────────────────────────────
        case .dot:
            // [source: Operand][key: Operand][target: Local (4)]
            var off = start
            try validateOperand(payload: payload, at: &off, strings: strings, numbers: numbers, maxLocal: maxLocal)
            try validateOperand(payload: payload, at: &off, strings: strings, numbers: numbers, maxLocal: maxLocal)
            guard off + 4 <= start + length else { throw Error.invalidPayloadLength }
            try validateLocal(readUInt32(payload, at: off), maxLocal: maxLocal)
            return []

        case .equal, .notEqual:
            // [a: Operand][b: Operand]
            var off = start
            try validateOperand(payload: payload, at: &off, strings: strings, numbers: numbers, maxLocal: maxLocal)
            try validateOperand(payload: payload, at: &off, strings: strings, numbers: numbers, maxLocal: maxLocal)
            return []

        case .objectInsertOnce, .objectInsert:
            // [object: Local (4)][key: Operand][value: Operand]
            try validateLocal(readUInt32(payload, at: start), maxLocal: maxLocal)
            var off = start + 4
            try validateOperand(payload: payload, at: &off, strings: strings, numbers: numbers, maxLocal: maxLocal)
            try validateOperand(payload: payload, at: &off, strings: strings, numbers: numbers, maxLocal: maxLocal)
            return []

        // ── Number table reference ───────────────────────────────────────────────
        case .makeNumberRef:
            // [index: UInt32 (4)][target: Local (4)]
            let index = Int(readUInt32(payload, at: start))
            guard index < numbers.count else { throw Error.invalidPayloadLength }
            guard numbers[index] != nil else { throw Error.invalidPayloadLength }
            try validateLocal(readUInt32(payload, at: start + 4), maxLocal: maxLocal)
            return []

        // ── Nested single block ──────────────────────────────────────────────────
        case .not:
            // [block content inline] — block starts at payload start, fills full payload
            return [(start, length)]

        // ── Nested multiple blocks ───────────────────────────────────────────────
        case .block:
            // [numBlocks: UInt32 (4)][{offset: UInt32, size: UInt32}...] — 0 or 2+ sub-blocks
            guard length >= 4 else { throw Error.invalidPayloadLength }
            let numBlocks = Int(readUInt32(payload, at: start))
            var nested: [(offset: Int, size: Int)] = []
            var off = start + 4
            for _ in 0..<numBlocks {
                guard off + 8 <= start + length else { throw Error.invalidPayloadLength }
                let blockOffset = Int(readUInt32(payload, at: off))
                let blockSize   = Int(readUInt32(payload, at: off + 4))
                off += 8
                nested.append((blockOffset, blockSize))
            }
            return nested

        case .block1:
            // [block content inline] — single sub-block, payload IS the block content
            return [(start, length)]

        // ── Call ─────────────────────────────────────────────────────────────────
        case .call:
            // [result: Local (4)][encodedFuncIndex: UInt32 (4)][argCount: UInt32 (4)][args: Operand...]
            guard length >= 12 else { throw Error.invalidPayloadLength }
            try validateLocal(readUInt32(payload, at: start), maxLocal: maxLocal)
            let encodedFuncIndex = readUInt32(payload, at: start + 4)
            let argCount = Int(readUInt32(payload, at: start + 8))
            if encodedFuncIndex & 0x8000_0000 != 0 {
                // Builtin: lower 31 bits = string-table index of the builtin name
                let stringIdx = Int(encodedFuncIndex & 0x7FFF_FFFF)
                guard stringIdx < strings.count else { throw Error.invalidPayloadLength }
            } else {
                let funcIdx = Int(encodedFuncIndex)
                guard funcIdx < functions.count else { throw Error.invalidPayloadLength }
            }
            var off = start + 12
            for _ in 0..<argCount {
                guard off + 4 <= start + length else { throw Error.invalidPayloadLength }
                try validateOperand(payload: payload, at: &off, strings: strings, numbers: numbers, maxLocal: maxLocal)
            }
            return []

        // ── CallDynamic ──────────────────────────────────────────────────────────
        case .callDynamic:
            // [result: Local (4)][pathCount: UInt32 (4)][path: Operand...][argCount: UInt32 (4)][args: Local (4)...]
            guard length >= 8 else { throw Error.invalidPayloadLength }
            try validateLocal(readUInt32(payload, at: start), maxLocal: maxLocal)
            let pathCount = Int(readUInt32(payload, at: start + 4))
            var off = start + 8
            for _ in 0..<pathCount {
                guard off + 4 <= start + length else { throw Error.invalidPayloadLength }
                try validateOperand(payload: payload, at: &off, strings: strings, numbers: numbers, maxLocal: maxLocal)
            }
            guard off + 4 <= start + length else { throw Error.invalidPayloadLength }
            let argCount = Int(readUInt32(payload, at: off))
            off += 4
            for _ in 0..<argCount {
                guard off + 4 <= start + length else { throw Error.invalidPayloadLength }
                try validateLocal(readUInt32(payload, at: off), maxLocal: maxLocal)
                off += 4
            }
            return []

        // ── Scan ─────────────────────────────────────────────────────────────────
        case .scan:
            // [source: Local (4)][key: Local (4)][value: Local (4)][block content inline]
            guard length >= 12 else { throw Error.invalidPayloadLength }
            try validateLocal(readUInt32(payload, at: start),     maxLocal: maxLocal)
            try validateLocal(readUInt32(payload, at: start + 4), maxLocal: maxLocal)
            try validateLocal(readUInt32(payload, at: start + 8), maxLocal: maxLocal)
            return [(start + 12, length - 12)]

        // ── With ─────────────────────────────────────────────────────────────────
        case .with:
            // [local: Local (4)][value: Operand][pathCount: UInt32 (4)][pathIndices: UInt32...][block content inline]
            guard length >= 4 else { throw Error.invalidPayloadLength }
            try validateLocal(readUInt32(payload, at: start), maxLocal: maxLocal)
            var off = start + 4
            try validateOperand(payload: payload, at: &off, strings: strings, numbers: numbers, maxLocal: maxLocal)
            guard off + 4 <= start + length else { throw Error.invalidPayloadLength }
            let pathCount = Int(readUInt32(payload, at: off))
            off += 4
            for _ in 0..<pathCount {
                guard off + 4 <= start + length else { throw Error.invalidPayloadLength }
                let stringIdx = Int(readUInt32(payload, at: off))
                off += 4
                guard stringIdx < strings.count else { throw Error.invalidPayloadLength }
            }
            // Block starts at `off` — fills remainder of payload
            let blockSize = length - (off - start)
            guard blockSize >= 0 else { throw Error.invalidPayloadLength }
            return [(off, blockSize)]
        }
    }

    // MARK: - Private helpers

    private static func validateOperand(
        payload: ContiguousArray<UInt8>,
        at offset: inout Int,
        strings: [String],
        numbers: [RegoNumber?],
        maxLocal: Int
    ) throws {
        let (operand, size) = EncodedOperand.decodeUnchecked(from: payload, at: offset)
        switch operand.type {
        case .stringIndex:
            guard Int(operand.value) < strings.count else { throw Error.invalidPayloadLength }
        case .numberIndex:
            guard Int(operand.value) < numbers.count else { throw Error.invalidPayloadLength }
        case .local:
            try validateLocal(operand.value, maxLocal: maxLocal)
        case .bool:
            break
        }
        offset += size
    }

    private static func validateLocal(_ index: UInt32, maxLocal: Int) throws {
        // VM always allocates at least 2 locals (input=0, data=1); valid range is [0, max(maxLocal, 1)].
        guard Int(index) <= max(maxLocal, 1) else { throw Error.invalidLocalIndex }
    }

    @inline(__always)
    private static func readUInt32(_ data: ContiguousArray<UInt8>, at offset: Int) -> UInt32 {
        data.withUnsafeBytes { $0.load(fromByteOffset: offset, as: UInt32.self) }
    }
}

/// Operand type for bytecode instructions
public enum OperandType: UInt8, Sendable {
    case local = 0      // Local variable reference (00)
    case bool = 1       // Boolean constant (01)
    case stringIndex = 2  // String table index (10)
    case numberIndex = 3  // Number table index (11)
}

/// Encoded operand value
public struct EncodedOperand: Sendable {
    public let type: OperandType
    public let value: UInt32

    public init(type: OperandType, value: UInt32) {
        self.type = type
        self.value = value
    }

    /// Local variable operand
    public static func local(_ index: UInt32) -> EncodedOperand {
        assert(index <= 0x3FFFFFFF, "Local index must fit in 30 bits")
        return EncodedOperand(type: .local, value: index)
    }

    /// Boolean constant operand
    public static func bool(_ value: Bool) -> EncodedOperand {
        return EncodedOperand(type: .bool, value: value ? 1 : 0)
    }

    /// String table index operand
    public static func stringIndex(_ index: UInt32) -> EncodedOperand {
        assert(index <= 0x3FFFFFFF, "String index must fit in 30 bits")
        return EncodedOperand(type: .stringIndex, value: index)
    }

    /// Number table index operand
    public static func numberIndex(_ index: UInt32) -> EncodedOperand {
        assert(index <= 0x3FFFFFFF, "Number index must fit in 30 bits")
        return EncodedOperand(type: .numberIndex, value: index)
    }

    /// Encode operand
    /// All operand types encode to 4 bytes, little-endian: [Type:2 | Value:30]
    public func encode() -> [UInt8] {
        let encoded = (UInt32(type.rawValue) << 30) | (value & 0x3FFFFFFF)
        return [
            UInt8(encoded & 0xFF),
            UInt8((encoded >> 8) & 0xFF),
            UInt8((encoded >> 16) & 0xFF),
            UInt8((encoded >> 24) & 0xFF)
        ]
    }

    /// Get encoded size in bytes (all operand types are 4 bytes)
    public var encodedSize: Int { 4 }

    /// Decode operand from Data (little-endian; all types are 4 bytes)
    public static func decode(from bytes: Data, at offset: Int) -> (operand: EncodedOperand, size: Int) {
        let encoded = bytes.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self) }
        let type = OperandType(rawValue: UInt8(encoded >> 30))!
        return (EncodedOperand(type: type, value: encoded & 0x3FFFFFFF), 4)
    }

    /// Decode operand without bounds checking (for validated bytecode, little-endian)
    /// SAFETY: Caller must ensure offset is valid and bytes contain enough data
    @inline(__always)
    public static func decodeUnchecked(from bytes: ContiguousArray<UInt8>, at offset: Int) -> (operand: EncodedOperand, size: Int) {
        let encoded = bytes.withUnsafeBytes {
            $0.load(fromByteOffset: offset, as: UInt32.self)
        }
        return (EncodedOperand(type: OperandType(rawValue: UInt8(encoded >> 30))!, value: encoded & 0x3FFFFFFF), 4)
    }
}

/// Bytecode errors
public enum Error: Swift.Error, Sendable {
    case invalidOpcode(UInt8)
    case invalidOperandType(UInt8)
    case unexpectedEndOfBytecode
    case invalidHeader
    case invalidPayloadLength
    case invalidLocalIndex
}
