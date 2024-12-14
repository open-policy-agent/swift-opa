struct AssignAppendStatement: Statement, Codable, Equatable {
    var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case array
        case value
    }

    var array: Local
    var value: Operand

    func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

struct AssignIntStatement: Statement, Codable, Equatable {
    var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case value
        case target
    }

    var value: Int64
    var target: Local

    func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

struct AssignVarOnceStatement: Statement, Codable, Equatable {
    var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case source
        case target
    }
    var source: Operand
    var target: Local

    func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

struct AssignVarStatement: Statement, Codable, Equatable {
    var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case source
        case target
    }

    var source: Operand
    var target: Local

    func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

struct BlockStatement: Statement, Codable, Equatable {
    var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case blocks
    }

    var blocks: [Block]

    func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

struct BreakStatement: Statement, Codable, Equatable {
    var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case index
    }

    var index: UInt32

    func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

struct CallDynamicStatement: Statement, Codable, Equatable {
    var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case path
        case args
        case result
    }

    var path: [Operand]
    var args: [Local]
    var result: Local

    func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

struct CallStatement: Statement, Codable, Equatable {
    var location: Location = Location()

    var callFunc: String = ""
    var args: [Argument] = []

    enum CodingKeys: String, CodingKey {
        case callFunc = "func"
        case args
    }

    func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

struct DotStatement: Statement, Codable, Equatable {
    var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case source
        case key
        case target
    }
    var source: Operand
    var key: Operand
    var target: Local

    func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

struct EqualStatement: Statement, Codable, Equatable {
    var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case a
        case b
    }
    var a: Operand
    var b: Operand

    func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

struct IsArrayStatement: Statement, Codable, Equatable {
    var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case source
    }

    var source: Operand

    func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

struct IsDefinedStatement: Statement, Codable, Equatable {
    var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case source
    }
    // NOTE: There is a mistake upstream in the spec, which specifies this as an operand (https://www.openpolicyagent.org/docs/latest/ir/#isdefinedstmt)
    var source: Local

    func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

struct IsObjectStatement: Statement, Codable, Equatable {
    var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case source
    }

    var source: Operand

    func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

struct IsSetStatement: Statement, Codable, Equatable {
    var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case source
    }

    var source: Operand

    func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

struct IsUndefinedStatement: Statement, Codable, Equatable {
    var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case source
    }
    // NOTE: There is a mistake upstream in the spec, which specifies this as an operand (https://www.openpolicyagent.org/docs/latest/ir/#isundefinedstmt)
    var source: Local

    func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

struct LenStatement: Statement, Codable, Equatable {
    var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case source
        case target
    }

    var source: Operand
    var target: Local

    func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

struct MakeArrayStatement: Statement, Codable, Equatable {
    var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case capacity
        case target
    }

    var capacity: Int32
    var target: Local

    func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

struct MakeNullStatement: Statement, Codable, Equatable {
    var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case target
    }

    var target: Local

    func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

struct MakeNumberStatement: Statement, Codable, Equatable {
    var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case value
        case target
    }

    var value: Int64
    var target: Local

    func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

struct MakeNumberRefStatement: Statement, Codable, Equatable {
    var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        // According to the Java SDK - "yup, it's capitalized"
        case index = "Index"
        case target
    }

    var index: Int32
    var target: Local

    func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

struct MakeObjectStatement: Statement, Codable, Equatable {
    var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case target
    }

    var target: Local

    func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

struct MakeSetStatement: Statement, Codable, Equatable {
    var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case target
    }

    var target: Local

    func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

struct NopStatement: Statement, Codable, Equatable {
    var location: Location = Location()

    // Workaround - NopStatement has no fields aside from the Location fields, which
    // are decoded generically in Block's decode initializer.
    // Since we can' provide an empty CodingKeys, and we don't want the default magic
    // behavior of looking for a "location" key, we override the decoding initializer
    // and do nothing.
    init(from decoder: Decoder) throws {
    }
    
    func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

struct NotStatement: Statement, Codable, Equatable {
    var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case block
    }

    var block: Block

    func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

struct NotEqualStatement: Statement, Codable, Equatable {
    var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case a
        case b
    }

    var a: Operand
    var b: Operand

    func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

struct ObjectInsertOnceStatement: Statement, Codable, Equatable {
    var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case key
        case value
        case object
    }

    var key: Operand
    var value: Operand
    var object: Local

    func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

struct ObjectInsertStatement: Statement, Codable, Equatable {
    var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case key
        case value
        case object
    }

    var key: Operand
    var value: Operand
    var object: Local

    func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

struct ObjectMergeStatement: Statement, Codable, Equatable {
    var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case a
        case b
        case target
    }

    var a: Local
    var b: Local
    var target: Local

    func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

struct ResetLocalStatement: Statement, Codable, Equatable {
    var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case target
    }

    var target: Local

    func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}
struct ResultSetAddStatement: Statement, Codable, Equatable {
    var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case value
    }
    var value: Local

    func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

struct ReturnLocalStatement: Statement, Codable, Equatable {
    var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case source
    }
    var source: Local

    func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}
struct ScanStatement: Statement, Codable, Equatable {
    var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case source
        case key
        case value
        case block
    }

    var source: Local
    var key: Local
    var value: Local
    var block: Block

    func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

struct SetAddStatement: Statement, Codable, Equatable {
    var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case value
        case set
    }

    var value: Operand
    var set: Local

    func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}

struct WithStatement: Statement, Codable, Equatable {
    var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case local
        case path
        case value
        case block
    }

    var local: Local
    var path: [Int32]
    var value: Operand
    var block: Block

    func isEqual(to other: any Statement) -> Bool {
        guard let rhs = other as? Self else {
            return false
        }
        return self == rhs
    }
}



