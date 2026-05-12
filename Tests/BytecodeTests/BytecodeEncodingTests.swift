import AST
import Foundation
import Testing

@testable import Bytecode

@Suite struct BytecodeEncodingTests {

    // MARK: - Header Encoding Tests

    @Test func testHeaderEncoding() throws {
        let header = InstructionHeader(opcode: .assignInt, length: 12)
        let encoded = header.encode()

        // Opcode 1 (assignInt) in top 6 bits, length 12 in bottom 24 bits
        // 0x01000000 | 0x0000000C = 0x0100000C
        #expect(encoded == 0x0100_000C)
    }

    @Test func testHeaderDecoding() throws {
        let encoded: UInt32 = 0x0100_000C  // Opcode 1, length 12
        let header = try InstructionHeader.decode(encoded)

        #expect(header.opcode == .assignInt)
        #expect(header.length == 12)
    }

    @Test func testHeaderRoundTrip() throws {
        let original = InstructionHeader(opcode: .scan, length: 16)
        let encoded = original.encode()
        let decoded = try InstructionHeader.decode(encoded)

        #expect(decoded.opcode == original.opcode)
        #expect(decoded.length == original.length)
    }

    @Test func testAllOpcodes() throws {
        let opcodes: [Opcode] = [
            .arrayAppend, .assignInt, .assignVarOnce, .assignVar,
            .block, .break, .call, .callDynamic,
            .dot, .equal,
            .isArray, .isDefined, .isObject, .isSet, .isUndefined,
            .len,
            .makeArray, .makeNull, .makeNumberInt, .makeNumberRef, .makeObject, .makeSet,
            .nop, .notEqual, .not,
            .objectInsertOnce, .objectInsert, .objectMerge,
            .resetLocal, .resultSetAdd, .returnLocal,
            .scan, .setAdd, .with,
        ]

        for opcode in opcodes {
            let header = InstructionHeader(opcode: opcode, length: 0)
            let encoded = header.encode()
            let decoded = try InstructionHeader.decode(encoded)
            #expect(decoded.opcode == opcode, "Opcode \(opcode) failed round-trip")
        }
    }

    // MARK: - Operand Encoding Tests

    @Test func testLocalOperandEncoding() throws {
        let operand = EncodedOperand.local(42)
        let encoded = operand.encode()

        #expect(encoded.count == 4)
        #expect(operand.encodedSize == 4)

        // Verify decoding
        let (decoded, size) = EncodedOperand.decode(from: Data(encoded), at: 0)
        #expect(decoded.type == .local)
        #expect(decoded.value == 42)
        #expect(size == 4)
    }

    @Test func testBoolOperandEncoding() throws {
        let operandTrue = EncodedOperand.bool(true)
        let encodedTrue = operandTrue.encode()

        #expect(encodedTrue.count == 4)
        #expect(operandTrue.encodedSize == 4)

        let operandFalse = EncodedOperand.bool(false)
        let encodedFalse = operandFalse.encode()

        #expect(encodedFalse.count == 4)

        // Verify decoding
        let (decodedTrue, sizeTrue) = EncodedOperand.decode(from: Data(encodedTrue), at: 0)
        #expect(decodedTrue.type == .bool)
        #expect(decodedTrue.value == 1)
        #expect(sizeTrue == 4)

        let (decodedFalse, sizeFalse) = EncodedOperand.decode(from: Data(encodedFalse), at: 0)
        #expect(decodedFalse.type == .bool)
        #expect(decodedFalse.value == 0)
        #expect(sizeFalse == 4)
    }

    @Test func testStringIndexOperandEncoding() throws {
        let operand = EncodedOperand.stringIndex(100)
        let encoded = operand.encode()

        #expect(encoded.count == 4)
        #expect(operand.encodedSize == 4)

        // Verify decoding
        let (decoded, size) = EncodedOperand.decode(from: Data(encoded), at: 0)
        #expect(decoded.type == .stringIndex)
        #expect(decoded.value == 100)
        #expect(size == 4)
    }

    @Test func testNumberIndexOperandEncoding() throws {
        let operand = EncodedOperand.numberIndex(100)
        let encoded = operand.encode()

        #expect(encoded.count == 4)
        #expect(operand.encodedSize == 4)

        // Verify decoding
        let (decoded, size) = EncodedOperand.decode(from: Data(encoded), at: 0)
        #expect(decoded.type == .numberIndex)
        #expect(decoded.value == 100)
        #expect(size == 4)
    }

    @Test func testOperandRoundTrip() throws {
        let operands: [EncodedOperand] = [
            .local(0),
            .local(1000),
            .bool(true),
            .bool(false),
            .stringIndex(0),
            .stringIndex(999),
            .numberIndex(0),
            .numberIndex(999),
        ]

        for original in operands {
            let encoded = original.encode()
            let (decoded, _) = EncodedOperand.decode(from: Data(encoded), at: 0)

            #expect(decoded.type == original.type)
            #expect(decoded.value == original.value)
        }
    }

    // MARK: - Encoder Tests

    @Test func testEncoderHeader() throws {
        var encoder = Encoder()
        encoder.appendHeader(.assignInt, payloadLength: 12)

        let bytes = encoder.bytes
        #expect(bytes.count == 4)

        // Read as little-endian UInt32 and verify via InstructionHeader.decode
        let value = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
        let header = try InstructionHeader.decode(value)
        #expect(header.opcode == .assignInt)
        #expect(header.length == 12)
    }

    @Test func testEncoderPrimitives() throws {
        var encoder = Encoder()

        encoder.appendUInt8(0x42)
        encoder.appendUInt32(0x1234_5678)
        encoder.appendInt64(-123_456_789)

        let bytes = encoder.bytes
        #expect(bytes[0] == 0x42)

        let uint32 = UInt32(bytes[1]) | UInt32(bytes[2]) << 8 | UInt32(bytes[3]) << 16 | UInt32(bytes[4]) << 24
        #expect(uint32 == 0x1234_5678)

        let unsignedLo =
            UInt64(bytes[5]) | UInt64(bytes[6]) << 8 | UInt64(bytes[7]) << 16 | UInt64(bytes[8]) << 24
        let unsignedHi =
            UInt64(bytes[9]) << 32 | UInt64(bytes[10]) << 40 | UInt64(bytes[11]) << 48 | UInt64(bytes[12]) << 56
        let unsigned = unsignedLo | unsignedHi
        #expect(Int64(bitPattern: unsigned) == -123_456_789)
    }

    @Test func testEncoderLocal() throws {
        var encoder = Encoder()
        encoder.appendLocal(42)

        let bytes = encoder.bytes
        let (decoded, size) = EncodedOperand.decode(from: Data(bytes), at: 0)
        #expect(decoded.type == .local)
        #expect(decoded.value == 42)
        #expect(size == 4)
    }

    @Test func testEncoderLocalArray() throws {
        var encoder = Encoder()
        let locals: [Local] = [0, 1, 2, 42, 100]
        encoder.appendLocalArray(locals)

        let bytes = encoder.bytes
        let count = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
        #expect(count == UInt32(locals.count))

        for (i, expected) in locals.enumerated() {
            let offset = 4 + i * 4
            let (decoded, _) = EncodedOperand.decode(from: Data(bytes), at: offset)
            #expect(decoded.type == .local)
            #expect(decoded.value == UInt32(expected))
        }
    }

    @Test func testEncoderOperandArray() throws {
        var encoder = Encoder()
        let operands: [EncodedOperand] = [
            .local(0),
            .bool(true),
            .stringIndex(5),
            .local(10),
        ]
        encoder.appendOperandArray(operands)

        let bytes = encoder.bytes
        let count = UInt32(bytes[0]) | UInt32(bytes[1]) << 8 | UInt32(bytes[2]) << 16 | UInt32(bytes[3]) << 24
        #expect(count == UInt32(operands.count))

        for (i, original) in operands.enumerated() {
            let offset = 4 + i * 4
            let (decoded, _) = EncodedOperand.decode(from: Data(bytes), at: offset)
            #expect(decoded.type == original.type)
            #expect(decoded.value == original.value)
        }
    }

    @Test func testEncoderReserveAndFillUInt32() throws {
        var encoder = Encoder()

        encoder.appendUInt32(0x1234_5678)

        let position = encoder.reserveUInt32()
        #expect(encoder.offset == 8)  // 4 + 4

        encoder.appendUInt32(0xABCD_EF00)

        encoder.fillUInt32(at: position, value: 0x100)

        let bytes = encoder.bytes
        let filled = UInt32(bytes[4]) | UInt32(bytes[5]) << 8 | UInt32(bytes[6]) << 16 | UInt32(bytes[7]) << 24
        #expect(filled == 0x100)
    }

    // MARK: - Error Cases

    @Test func testInvalidOpcodeError() throws {
        let invalidEncoded: UInt32 = 0xFF00_0000  // Opcode 255 (invalid)
        #expect(throws: Bytecode.Error.self) {
            try InstructionHeader.decode(invalidEncoded)
        }
    }

    // Note: testInvalidOperandType() was removed because all 2-bit type values (0-3) are now valid
    // after adding numberIndex = 3. There's no way to encode an invalid 2-bit type value.
}
