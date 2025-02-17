public struct ArrayAppendStatement: Statement, Codable, Equatable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case array
        case value
    }

    public var array: Local
    public var value: Operand

    public func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

public struct AssignIntStatement: Statement, Codable, Equatable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case value
        case target
    }

    public var value: Int64
    public var target: Local

    public func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

public struct AssignVarOnceStatement: Statement, Codable, Equatable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case source
        case target
    }

    public var source: Operand
    public var target: Local

    public func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

public struct AssignVarStatement: Statement, Codable, Equatable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case source
        case target
    }

    public var source: Operand
    public var target: Local

    public init(location: Location? = nil, source: Operand, target: Local) {
        self.source = source
        self.target = target

        guard let location else {
            return
        }
        self.location = location
    }

    public func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

public struct BlockStatement: Statement, Codable, Equatable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case blocks
    }

    public var blocks: [Block]?

    public init(blocks: [Block]) {
        self.blocks = blocks
    }

    public func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

public struct BreakStatement: Statement, Codable, Equatable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case index
    }

    public var index: UInt32

    public func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

public struct CallDynamicStatement: Statement, Codable, Equatable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case path
        case args
        case result
    }

    public var path: [Operand]
    public var args: [Local]
    public var result: Local

    public func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

public struct CallStatement: Statement, Codable, Equatable {
    public var location: Location = Location()

    public var callFunc: String = ""
    public var args: [Operand]? = []
    public var result: Local = 0

    enum CodingKeys: String, CodingKey {
        case callFunc = "func"
        case args
        case result
    }

    public func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

public struct DotStatement: Statement, Codable, Equatable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case source
        case key
        case target
    }

    public var source: Operand
    public var key: Operand
    public var target: Local

    public init(source: Operand, key: Operand, target: Local) {
        self.source = source
        self.key = key
        self.target = target
    }

    public func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

public struct EqualStatement: Statement, Codable, Equatable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case a
        case b
    }

    public var a: Operand
    public var b: Operand

    public init(a: Operand, b: Operand) {
        self.a = a
        self.b = b
    }

    public func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

public struct IsArrayStatement: Statement, Codable, Equatable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case source
    }

    public var source: Operand

    public func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

public struct IsDefinedStatement: Statement, Codable, Equatable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case source
    }

    // NOTE: There is a mistake upstream in the spec, which specifies this as an operand (https://www.openpolicyagent.org/docs/latest/ir/#isdefinedstmt)
    public var source: Local

    public func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

public struct IsObjectStatement: Statement, Codable, Equatable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case source
    }

    public var source: Operand

    public func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

public struct IsSetStatement: Statement, Codable, Equatable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case source
    }

    public var source: Operand

    public func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

public struct IsUndefinedStatement: Statement, Codable, Equatable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case source
    }

    // NOTE: There is a mistake upstream in the spec, which specifies this as an operand (https://www.openpolicyagent.org/docs/latest/ir/#isundefinedstmt)
    public var source: Local

    public init(source: Local) {
        self.source = source
    }

    public func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

public struct LenStatement: Statement, Codable, Equatable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case source
        case target
    }

    public var source: Operand
    public var target: Local

    public init(source: Operand, target: Local) {
        self.source = source
        self.target = target
    }

    public func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

public struct MakeArrayStatement: Statement, Codable, Equatable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case capacity
        case target
    }

    public var capacity: Int32
    public var target: Local

    public func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

public struct MakeNullStatement: Statement, Codable, Equatable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case target
    }

    public var target: Local

    public func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

public struct MakeNumberIntStatement: Statement, Codable, Equatable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case value
        case target
    }

    public var value: Int64
    public var target: Local

    public func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

public struct MakeNumberRefStatement: Statement, Codable, Equatable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        // According to the Java SDK - "yup, it's capitalized"
        case index = "Index"
        case target
    }

    public var index: Int32
    public var target: Local

    public func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

public struct MakeObjectStatement: Statement, Codable, Equatable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case target
    }

    public var target: Local

    public init(location: Location? = nil, target: Local) {
        if let location {
            self.location = location
        }
        self.target = target
    }

    public func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

public struct MakeSetStatement: Statement, Codable, Equatable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case target
    }

    public var target: Local

    public func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

public struct NopStatement: Statement, Codable, Equatable {
    public var location: Location = Location()

    // Workaround - NopStatement has no fields aside from the Location fields, which
    // are decoded generically in Block's decode initializer.
    // Since we can' provide an empty CodingKeys, and we don't want the default magic
    // behavior of looking for a "location" key, we override the decoding initializer
    // and do nothing.
    public init(from decoder: Decoder) throws {
    }

    public func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

public struct NotStatement: Statement, Codable, Equatable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case block
    }

    public var block: Block

    public func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

public struct NotEqualStatement: Statement, Codable, Equatable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case a
        case b
    }

    public var a: Operand
    public var b: Operand

    public init(a: Operand, b: Operand) {
        self.a = a
        self.b = b
    }

    public func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

public struct ObjectInsertOnceStatement: Statement, Codable, Equatable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case key
        case value
        case object
    }

    public var key: Operand
    public var value: Operand
    public var object: Local

    public init(key: Operand, value: Operand, object: Local) {
        self.key = key
        self.value = value
        self.object = object
    }

    public func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

public struct ObjectInsertStatement: Statement, Codable, Equatable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case key
        case value
        case object
    }

    public var key: Operand
    public var value: Operand
    public var object: Local

    public init(location: Location? = nil, key: Operand, value: Operand, object: Local) {
        if let location {
            self.location = location
        }
        self.key = key
        self.value = value
        self.object = object
    }

    public func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

public struct ObjectMergeStatement: Statement, Codable, Equatable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case a
        case b
        case target
    }

    public var a: Local
    public var b: Local
    public var target: Local

    public func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

public struct ResetLocalStatement: Statement, Codable, Equatable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case target
    }

    public var target: Local

    public func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

public struct ResultSetAddStatement: Statement, Codable, Equatable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case value
    }

    public var value: Local

    public init(value: Local) {
        self.value = value
    }

    public func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

public struct ReturnLocalStatement: Statement, Codable, Equatable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case source
    }

    public var source: Local

    public func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

public struct ScanStatement: Statement, Codable, Equatable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case source
        case key
        case value
        case block
    }

    public var source: Local
    public var key: Local
    public var value: Local
    public var block: Block

    public init(source: Local, key: Local, value: Local, block: Block) {
        self.source = source
        self.key = key
        self.value = value
        self.block = block
    }

    public func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

public struct SetAddStatement: Statement, Codable, Equatable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case value
        case set
    }

    public var value: Operand
    public var set: Local

    public func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

public struct WithStatement: Statement, Codable, Equatable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case local
        case path
        case value
        case block
    }

    public var local: Local
    public var path: [Int32]?  // TODO when is this ever allowed to be null/missing?
    public var value: Operand
    public var block: Block

    public func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}
