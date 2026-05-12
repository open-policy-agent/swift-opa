import AST
import Testing

@testable import Bytecode

// Tests for Policy.validate() — exercises all error paths that the VM hot loop
// skips because validation has already run at load time.
@Suite struct BytecodeValidationTests {

    // Build a Policy whose single plan block points at the given bytecode.
    private func policy(
        bytes: ContiguousArray<UInt8>,
        blockOffset: Int = 0,
        blockSize: Int? = nil,
        strings: [String] = [],
        numbers: [RegoNumber?] = [],
        functions: [Bytecode.Function] = [],
        maxLocal: Int = -1
    ) -> Bytecode.Policy {
        let sz = blockSize ?? bytes.count
        return Bytecode.Policy(
            strings: strings,
            numbers: numbers,
            functions: functions,
            plans: [
                Plan(
                    name: "test",
                    maxLocal: maxLocal,
                    bytecodeOffset: blockOffset,
                    bytecodeSize: sz,
                    blocks: [(offset: blockOffset, size: sz, syncSafe: false)]
                )
            ],
            bytecode: bytes
        )
    }

    // MARK: - unexpectedEndOfBytecode

    @Test func testBlockSizeExceedsBytecode() {
        // Block claims 100 bytes but bytecode only has a single nop (4 bytes)
        var enc = Encoder()
        enc.appendHeader(.nop, payloadLength: 0)
        let p = policy(bytes: enc.bytes, blockSize: 100)
        #expect(throws: Bytecode.Error.self) { try p.validate() }
    }

    @Test func testTruncatedHeader() {
        // Block is 2 bytes — not enough to read a 4-byte header
        let p = policy(bytes: [0x22, 0x11])
        #expect(throws: Bytecode.Error.self) { try p.validate() }
    }

    @Test func testTruncatedPayload() {
        // Header claims a 4-byte payload but only 2 payload bytes are present.
        // Block size = 6 (fits within bytecode), but payloadEnd = 8 > 6.
        var enc = Encoder()
        enc.appendHeader(.makeNull, payloadLength: 4)
        enc.appendUInt8(0x00)
        enc.appendUInt8(0x00)  // only 2 of the 4 claimed payload bytes
        let p = policy(bytes: enc.bytes)
        #expect(throws: Bytecode.Error.self) { try p.validate() }
    }

    // MARK: - invalidOpcode

    @Test func testInvalidOpcode() {
        // Raw opcode 63 (0x3F) is beyond the highest valid value (41 = assignVar1).
        // Header format: opcode in bits 29-24, so 0x3F << 24 = 0x3F000000 (little-endian).
        var enc = Encoder()
        enc.appendUInt32(0x3F00_0000)
        let p = policy(bytes: enc.bytes)
        #expect(throws: Bytecode.Error.self) { try p.validate() }
    }

    @Test func testInvalidOpcodeFirstInvalid() {
        // Raw opcode 42 is the first value beyond assignVar1 (41).
        var enc = Encoder()
        enc.appendUInt32(UInt32(42) << 24)
        let p = policy(bytes: enc.bytes)
        #expect(throws: Bytecode.Error.self) { try p.validate() }
    }

    // MARK: - invalidPayloadLength: out-of-bounds operand indices

    @Test func testStringIndexOutOfBounds() {
        // isArray with a stringIndex operand pointing beyond the (empty) string table
        var enc = Encoder()
        enc.appendHeader(.isArray, payloadLength: 4)
        enc.appendOperand(EncodedOperand.stringIndex(0))
        let p = policy(bytes: enc.bytes, strings: [])  // index 0 OOB
        #expect(throws: Bytecode.Error.self) { try p.validate() }
    }

    @Test func testNumberIndexOutOfBounds() {
        // isArray with a numberIndex operand pointing beyond the (empty) number table
        var enc = Encoder()
        enc.appendHeader(.isArray, payloadLength: 4)
        enc.appendOperand(EncodedOperand.numberIndex(0))
        let p = policy(bytes: enc.bytes, numbers: [])  // index 0 OOB
        #expect(throws: Bytecode.Error.self) { try p.validate() }
    }

    // MARK: - invalidPayloadLength: makeNumberRef

    @Test func testMakeNumberRefIndexOutOfBounds() {
        var enc = Encoder()
        enc.appendHeader(.makeNumberRef, payloadLength: 8)
        enc.appendUInt32(5)  // index 5
        enc.appendLocal(0)  // target
        let p = policy(bytes: enc.bytes, numbers: [])  // index 5 OOB
        #expect(throws: Bytecode.Error.self) { try p.validate() }
    }

    @Test func testMakeNumberRefNilEntry() {
        // Index is in bounds but numbers[0] == nil (string wasn't parseable as a number)
        var enc = Encoder()
        enc.appendHeader(.makeNumberRef, payloadLength: 8)
        enc.appendUInt32(0)  // index 0
        enc.appendLocal(0)  // target
        let p = policy(bytes: enc.bytes, numbers: [nil])
        #expect(throws: Bytecode.Error.self) { try p.validate() }
    }

    // MARK: - invalidPayloadLength: call

    @Test func testCallUserFuncIndexOutOfBounds() {
        // User function index 5 with empty function table
        var enc = Encoder()
        enc.appendHeader(.call, payloadLength: 12)  // result(4)+funcIdx(4)+argCount(4)
        enc.appendLocal(0)  // result
        enc.appendUInt32(5)  // user func index 5 (high bit clear)
        enc.appendUInt32(0)  // 0 args
        let p = policy(bytes: enc.bytes, functions: [])
        #expect(throws: Bytecode.Error.self) { try p.validate() }
    }

    @Test func testCallBuiltinStringIndexOutOfBounds() {
        // Builtin with string index 5 but empty string table
        var enc = Encoder()
        enc.appendHeader(.call, payloadLength: 12)
        enc.appendLocal(0)  // result
        enc.appendUInt32(0x8000_0000 | 5)  // builtin flag set, string index 5
        enc.appendUInt32(0)  // 0 args
        let p = policy(bytes: enc.bytes, strings: [])
        #expect(throws: Bytecode.Error.self) { try p.validate() }
    }

    // MARK: - invalidPayloadLength: with path

    @Test func testScanPayloadTooShort() {
        // scan requires 12 bytes for source/key/value locals before the inline block.
        var enc = Encoder()
        enc.appendHeader(.scan, payloadLength: 8)  // 8 < 12 minimum
        enc.appendLocal(0)
        enc.appendLocal(1)
        let p = policy(bytes: enc.bytes)
        #expect(throws: Bytecode.Error.self) { try p.validate() }
    }

    // MARK: - invalidPayloadLength: with path

    @Test func testWithPathIndexOutOfBounds() {
        // with: local(4)+value_op(4)+pathCount(4)+pathIdx(4) = 16 bytes payload, empty block
        var enc = Encoder()
        enc.appendHeader(.with, payloadLength: 16)
        enc.appendLocal(0)  // local
        enc.appendOperand(.local(0))  // value
        enc.appendUInt32(1)  // pathCount = 1
        enc.appendUInt32(0)  // path[0] = string index 0
        // Block content: empty (16 - 16 = 0 bytes)
        let p = policy(bytes: enc.bytes, strings: [])  // index 0 OOB
        #expect(throws: Bytecode.Error.self) { try p.validate() }
    }

    // MARK: - invalidLocalIndex

    @Test func testLocalIndexOutOfBounds() {
        // resetLocal with local index 5, but maxLocal = 2 — index 5 is beyond the frame
        var enc = Encoder()
        enc.appendHeader(.resetLocal, payloadLength: 4)
        enc.appendLocal(5)
        let p = policy(bytes: enc.bytes, maxLocal: 2)
        #expect(throws: Bytecode.Error.self) { try p.validate() }
    }

    @Test func testLocalIndexInBounds() throws {
        // resetLocal with local index 2, maxLocal = 2 — valid
        var enc = Encoder()
        enc.appendHeader(.resetLocal, payloadLength: 4)
        enc.appendLocal(2)
        try policy(bytes: enc.bytes, maxLocal: 2).validate()
    }

    @Test func testCompactLocalIndexOutOfBounds() {
        // isDefined1 with local index 10, but maxLocal = 3 — index 10 is beyond the frame
        var enc = Encoder()
        enc.appendHeader(.isDefined1, payloadLength: 10)  // operand = 10 in length field
        let p = policy(bytes: enc.bytes, maxLocal: 3)
        #expect(throws: Bytecode.Error.self) { try p.validate() }
    }

    @Test func testOperandLocalIndexOutOfBounds() {
        // isArray with a local operand pointing beyond the frame
        var enc = Encoder()
        enc.appendHeader(.isArray, payloadLength: 4)
        enc.appendOperand(.local(99))
        let p = policy(bytes: enc.bytes, maxLocal: 5)
        #expect(throws: Bytecode.Error.self) { try p.validate() }
    }

    // MARK: - invalidPayloadLength: oversized count fields

    @Test func testBlockNumBlocksExceedsPayload() {
        // block: numBlocks claims 100 sub-blocks but payload only holds the count field (4 bytes)
        var enc = Encoder()
        enc.appendHeader(.block, payloadLength: 4)
        enc.appendUInt32(100)  // numBlocks = 100 — each needs 8 bytes, none fit
        let p = policy(bytes: enc.bytes)
        #expect(throws: Bytecode.Error.self) { try p.validate() }
    }

    @Test func testCallArgCountExceedsPayload() {
        // call: argCount claims 10 args but payload has no room for them after the 12-byte header
        var enc = Encoder()
        enc.appendHeader(.call, payloadLength: 12)  // exactly the fixed header, no arg bytes
        enc.appendLocal(0)  // result
        enc.appendUInt32(0)  // user func 0
        enc.appendUInt32(10)  // argCount = 10
        // No arg operands follow — first guard trip should throw
        let p = policy(
            bytes: enc.bytes,
            functions: [
                Function(
                    name: "f", path: [], params: [], returnVar: Local(0), maxLocal: 0, bytecodeOffset: 0,
                    bytecodeSize: 0, blocks: [])
            ])
        #expect(throws: Bytecode.Error.self) { try p.validate() }
    }

    @Test func testCallDynamicPathCountExceedsPayload() {
        // callDynamic: pathCount claims 10 path elements but payload has no room after the 8-byte header
        var enc = Encoder()
        enc.appendHeader(.callDynamic, payloadLength: 8)  // result(4)+pathCount(4), no path bytes
        enc.appendLocal(0)  // result
        enc.appendUInt32(10)  // pathCount = 10
        let p = policy(bytes: enc.bytes)
        #expect(throws: Bytecode.Error.self) { try p.validate() }
    }

    @Test func testWithPathCountExceedsPayload() {
        // with: pathCount claims 10 path indices but payload has no room after local+value+count
        var enc = Encoder()
        // local(4) + value_op(4) + pathCount(4) = 12 bytes, no indices
        enc.appendHeader(.with, payloadLength: 12)
        enc.appendLocal(0)  // local
        enc.appendOperand(.local(1))  // value
        enc.appendUInt32(10)  // pathCount = 10
        let p = policy(bytes: enc.bytes, strings: ["x"])
        #expect(throws: Bytecode.Error.self) { try p.validate() }
    }

    // MARK: - Happy path

    @Test func testValidateEmptyPolicy() throws {
        let p = Bytecode.Policy(
            strings: [], numbers: [], functions: [], plans: [], bytecode: ContiguousArray()
        )
        try p.validate()
    }

    @Test func testValidateNop() throws {
        var enc = Encoder()
        enc.appendHeader(.nop, payloadLength: 0)
        try policy(bytes: enc.bytes).validate()
    }

    @Test func testValidateCompactOpcodes() throws {
        // All compact opcodes: isDefined1, isUndefined1, resetLocal1,
        // resultSetAdd1, returnLocal1, break1, assignVar1
        var enc = Encoder()
        enc.appendHeader(.isDefined1, payloadLength: 2)
        enc.appendHeader(.isUndefined1, payloadLength: 3)
        enc.appendHeader(.resetLocal1, payloadLength: 4)
        enc.appendHeader(.resultSetAdd1, payloadLength: 5)
        enc.appendHeader(.returnLocal1, payloadLength: 6)
        enc.appendHeader(.break1, payloadLength: 1)
        enc.appendHeader(.assignVar1, payloadLength: (1 << 12) | 2)
        try policy(bytes: enc.bytes, maxLocal: 6).validate()
    }

    @Test func testValidateValidStringIndex() throws {
        var enc = Encoder()
        enc.appendHeader(.isArray, payloadLength: 4)
        enc.appendOperand(EncodedOperand.stringIndex(0))
        try policy(bytes: enc.bytes, strings: ["hello"]).validate()
    }

    @Test func testValidateValidMakeNumberRef() throws {
        var enc = Encoder()
        enc.appendHeader(.makeNumberRef, payloadLength: 8)
        enc.appendUInt32(0)  // index 0
        enc.appendLocal(2)  // target
        try policy(bytes: enc.bytes, numbers: [RegoNumber(int: 42)], maxLocal: 2).validate()
    }
}
