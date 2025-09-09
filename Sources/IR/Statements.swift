public struct ArrayAppendStatement: Statement, Codable, Hashable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case array
        case value
    }

    public var array: Local
    public var value: Operand
}

public struct AssignIntStatement: Statement, Codable, Hashable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case value
        case target
    }

    public var value: Int64
    public var target: Local
}

public struct AssignVarOnceStatement: Statement, Codable, Hashable {
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
}

public struct AssignVarStatement: Statement, Codable, Hashable {
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
}

public struct BlockStatement: Statement, Codable, Hashable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case blocks
    }

    public var blocks: [Block]?

    public init(blocks: [Block]) {
        self.blocks = blocks
    }
}

public struct BreakStatement: Statement, Codable, Hashable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case index
    }

    public var index: UInt32

    public init(index: UInt32) {
        self.index = index
    }
}

public struct CallDynamicStatement: Statement, Codable, Hashable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case path
        case args
        case result
    }

    public var path: [Operand]
    public var args: [Local]
    public var result: Local
}

public struct CallStatement: Statement, Codable, Hashable {
    public var location: Location = Location()

    public var callFunc: String = ""
    public var args: [Operand]? = []
    public var result: Local = 0

    enum CodingKeys: String, CodingKey {
        case callFunc = "func"
        case args
        case result
    }

    public init(location: Location = Location(), callFunc: String, args: [Operand] = [], result: Local) {
        self.location = location
        self.callFunc = callFunc
        self.args = args
        self.result = result
    }
}

public struct DotStatement: Statement, Codable, Hashable {
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
}

public struct EqualStatement: Statement, Codable, Hashable {
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
}

public struct IsArrayStatement: Statement, Codable, Hashable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case source
    }

    public var source: Operand
}

public struct IsDefinedStatement: Statement, Codable, Hashable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case source
    }

    // NOTE: There is a mistake upstream in the spec, which specifies this as an operand (https://www.openpolicyagent.org/docs/latest/ir/#isdefinedstmt)
    public var source: Local
}

public struct IsObjectStatement: Statement, Codable, Hashable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case source
    }

    public var source: Operand
}

public struct IsSetStatement: Statement, Codable, Hashable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case source
    }

    public var source: Operand
}

public struct IsUndefinedStatement: Statement, Codable, Hashable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case source
    }

    // NOTE: There is a mistake upstream in the spec, which specifies this as an operand (https://www.openpolicyagent.org/docs/latest/ir/#isundefinedstmt)
    public var source: Local

    public init(source: Local) {
        self.source = source
    }
}

public struct LenStatement: Statement, Codable, Hashable {
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
}

public struct MakeArrayStatement: Statement, Codable, Hashable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case capacity
        case target
    }

    public var capacity: Int32
    public var target: Local
}

public struct MakeNullStatement: Statement, Codable, Hashable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case target
    }

    public var target: Local
}

public struct MakeNumberIntStatement: Statement, Codable, Hashable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case value
        case target
    }

    public var value: Int64
    public var target: Local
}

public struct MakeNumberRefStatement: Statement, Codable, Hashable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        // According to the Java SDK - "yup, it's capitalized"
        case index = "Index"
        case target
    }

    public var index: Int32
    public var target: Local
}

public struct MakeObjectStatement: Statement, Codable, Hashable {
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
}

public struct MakeSetStatement: Statement, Codable, Hashable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case target
    }

    public var target: Local
}

public struct NopStatement: Statement, Codable, Hashable {
    public var location: Location = Location()

    // Workaround - NopStatement has no fields aside from the Location fields, which
    // are decoded generically in Block's decode initializer.
    // Since we can' provide an empty CodingKeys, and we don't want the default magic
    // behavior of looking for a "location" key, we override the decoding initializer
    // and do nothing.
    public init(from decoder: Decoder) throws {
    }
}

public struct NotStatement: Statement, Codable, Hashable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case block
    }

    public var block: Block
}

public struct NotEqualStatement: Statement, Codable, Hashable {
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
}

public struct ObjectInsertOnceStatement: Statement, Codable, Hashable {
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
}

public struct ObjectInsertStatement: Statement, Codable, Hashable {
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
}

public struct ObjectMergeStatement: Statement, Codable, Hashable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case a
        case b
        case target
    }

    public var a: Local
    public var b: Local
    public var target: Local
}

public struct ResetLocalStatement: Statement, Codable, Hashable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case target
    }

    public var target: Local
}

public struct ResultSetAddStatement: Statement, Codable, Hashable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case value
    }

    public var value: Local

    public init(value: Local) {
        self.value = value
    }
}

public struct ReturnLocalStatement: Statement, Codable, Hashable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case source
    }

    public var source: Local
}

public struct ScanStatement: Statement, Codable, Hashable {
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
}

public struct SetAddStatement: Statement, Codable, Hashable {
    public var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case value
        case set
    }

    public var value: Operand
    public var set: Local
}

public struct WithStatement: Statement, Codable, Hashable {
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
}
