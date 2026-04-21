import AST
import IR

/// Builds deduplicated string table during bytecode conversion
public struct StringTableBuilder {
    private var strings: [String] = []
    private var indices: [String: Int] = [:]

    public init() {}

    /// Intern a string and return its index in the table
    public mutating func intern(_ string: String) -> Int {
        if let existing = indices[string] {
            return existing
        }
        let index = strings.count
        strings.append(string)
        indices[string] = index
        return index
    }

    /// Get the final string table
    public var table: [String] {
        return strings
    }

    /// Get the number of strings in the table
    public var count: Int {
        return strings.count
    }
}

/// Context for bytecode conversion, tracks state during conversion
public struct ConversionContext {
    public var stringTable: StringTableBuilder
    public var encoder: Encoder
    public var functionIndices: [String: Int]
    public var numbers: [RegoNumber?]

    public init(functionIndices: [String: Int] = [:], numbers: [RegoNumber?] = []) {
        self.stringTable = StringTableBuilder()
        self.encoder = Encoder()
        self.functionIndices = functionIndices
        self.numbers = numbers
    }

    /// Get current bytecode offset
    public var currentOffset: Int {
        return encoder.offset
    }

    /// Convert IR operand to encoded operand, interning strings as needed
    public mutating func convertOperand(_ operand: IR.Operand) throws -> EncodedOperand {
        switch operand.value {
        case .localIndex(let idx):
            return .local(UInt32(idx))
        case .bool(let value):
            return .bool(value)
        case .stringIndex(let idx):
            return .stringIndex(UInt32(idx))
        }
    }

    /// Convert array of IR operands to encoded operands
    public mutating func convertOperands(_ operands: [IR.Operand]) throws -> [EncodedOperand] {
        return try operands.map { try convertOperand($0) }
    }
}
