import AST
import Foundation

/// Utilities for encoding bytecode primitives
public struct Encoder {
    private var buffer: ContiguousArray<UInt8> = []

    public init() {}

    /// Get the current bytecode buffer as contiguous bytes (zero-copy)
    public var bytes: ContiguousArray<UInt8> {
        return buffer
    }

    /// Get the current bytecode buffer as Data (allocates a copy; use for serialisation only)
    public var data: Data {
        return Data(buffer)
    }

    /// Get current offset in buffer
    public var offset: Int {
        return buffer.count
    }

    // MARK: - Header Encoding

    /// Append instruction header
    public mutating func appendHeader(_ opcode: Opcode, payloadLength: UInt32) {
        let header = InstructionHeader(opcode: opcode, length: payloadLength)
        let encoded = header.encode()
        appendUInt32(encoded)
    }

    /// Reserve space for instruction header (returns position to fill later)
    public mutating func reserveHeader() -> Int {
        let position = buffer.count
        appendUInt32(0)  // Placeholder
        return position
    }

    /// Fill in instruction header at reserved position
    public mutating func fillHeader(at position: Int, opcode: Opcode, payloadLength: UInt32) {
        let header = InstructionHeader(opcode: opcode, length: payloadLength)
        let encoded = header.encode()
        buffer[position] = UInt8(encoded & 0xFF)
        buffer[position + 1] = UInt8((encoded >> 8) & 0xFF)
        buffer[position + 2] = UInt8((encoded >> 16) & 0xFF)
        buffer[position + 3] = UInt8((encoded >> 24) & 0xFF)
    }

    // MARK: - Primitive Encoding

    /// Append UInt8
    public mutating func appendUInt8(_ value: UInt8) {
        buffer.append(value)
    }

    /// Append UInt32 in little-endian format
    public mutating func appendUInt32(_ value: UInt32) {
        buffer.append(UInt8(value & 0xFF))
        buffer.append(UInt8((value >> 8) & 0xFF))
        buffer.append(UInt8((value >> 16) & 0xFF))
        buffer.append(UInt8((value >> 24) & 0xFF))
    }

    /// Append Int64 in little-endian format
    public mutating func appendInt64(_ value: Int64) {
        let unsigned = UInt64(bitPattern: value)
        buffer.append(UInt8(unsigned & 0xFF))
        buffer.append(UInt8((unsigned >> 8) & 0xFF))
        buffer.append(UInt8((unsigned >> 16) & 0xFF))
        buffer.append(UInt8((unsigned >> 24) & 0xFF))
        buffer.append(UInt8((unsigned >> 32) & 0xFF))
        buffer.append(UInt8((unsigned >> 40) & 0xFF))
        buffer.append(UInt8((unsigned >> 48) & 0xFF))
        buffer.append(UInt8((unsigned >> 56) & 0xFF))
    }

    // MARK: - Operand Encoding

    /// Append local variable operand (4 bytes)
    public mutating func appendLocal(_ local: Local) {
        let operand = EncodedOperand.local(UInt32(local))
        buffer.append(contentsOf: operand.encode())
    }

    /// Append operand
    public mutating func appendOperand(_ operand: EncodedOperand) {
        buffer.append(contentsOf: operand.encode())
    }

    /// Append array of locals
    public mutating func appendLocalArray(_ locals: [Local]) {
        appendUInt32(UInt32(locals.count))
        for local in locals {
            appendLocal(local)
        }
    }

    /// Append array of operands
    public mutating func appendOperandArray(_ operands: [EncodedOperand]) {
        appendUInt32(UInt32(operands.count))
        for operand in operands {
            appendOperand(operand)
        }
    }

    // MARK: - Block Encoding

    /// Reserve space for a UInt32 (returns position to fill later)
    public mutating func reserveUInt32() -> Int {
        let position = buffer.count
        appendUInt32(0)  // Placeholder
        return position
    }

    /// Fill in UInt32 at reserved position
    public mutating func fillUInt32(at position: Int, value: UInt32) {
        buffer[position] = UInt8(value & 0xFF)
        buffer[position + 1] = UInt8((value >> 8) & 0xFF)
        buffer[position + 2] = UInt8((value >> 16) & 0xFF)
        buffer[position + 3] = UInt8((value >> 24) & 0xFF)
    }

}
