struct Policy: Codable, Equatable {
    var staticData: Static?
    var plans: Plans? = nil
    var funcs: Funcs? = nil

    enum CodingKeys: String, CodingKey {
        case staticData = "static"
        case plans
        case funcs
    }
}

struct Static: Codable, Equatable {
    var strings: [ConstString]
    var builtinFuncs: [BuiltinFunc]?
    var files: [ConstString]

    enum CodingKeys: String, CodingKey {
        case strings
        case builtinFuncs = "builtin_funcs"
        case files
    }
}

struct ConstString: Codable, Equatable {
    var value: String
}

struct BuiltinFunc: Codable, Equatable {
    var name: String
    //    var decl : FunctionDecl
}

// struct FunctionDecl : Codable {
// var args [Type]
// var result Type
// var variadic Type
// }
//
// struct Type : Codable {
//
// }

struct Plans: Codable, Equatable {
    var plans: [Plan] = []
}

struct Plan: Codable, Equatable {
    var name: String
    var blocks: [Block]
}

struct Block: Sendable, Equatable {
    var statements: [any Statement]

    // Equatable, we need a custom implementation for dynamic dispatch
    // to our heterogenous extistential type instances (statements)
    static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.statements.count == rhs.statements.count else {
            return false
        }

        for i in 0..<lhs.statements.count {
            guard lhs.statements[i].isEqual(to: rhs.statements[i]) else {
                return false
            }
        }

        return true
    }

}

extension Block: Codable {
    enum CodingKeys: String, CodingKey {
        case statements = "stmts"
    }
    // Each abstract statement has a stmt with the polymorphic contents
    enum InnerCodingKeys: String, CodingKey {
        case innerStatement = "stmt"
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var iter = try container.nestedUnkeyedContainer(forKey: .statements)
        var peek = iter

        var out = [any Statement]()
        while !peek.isAtEnd {
            let anyStmt = try peek.decode(AnyStatement.self)
            let inner = try iter.nestedContainer(keyedBy: InnerCodingKeys.self)

            var outStmt: any Statement

            switch anyStmt.type {
            case .callStmt:
                outStmt = try inner.decode(CallStatement.self, forKey: .innerStatement)
            case .assignVarStmt:
                outStmt = try inner.decode(AssignVarStatement.self, forKey: .innerStatement)
            case .makeObjectStmt:
                outStmt = try inner.decode(MakeObjectStatement.self, forKey: .innerStatement)
            case .objectInsertStmt:
                outStmt = try inner.decode(ObjectInsertStatement.self, forKey: .innerStatement)
            case .resultSetAddStmt:
                outStmt = try inner.decode(ResultSetAddStatement.self, forKey: .innerStatement)
            case .resetLocalStmt:
                outStmt = try inner.decode(ResetLocalStatement.self, forKey: .innerStatement)
            case .dotStmt:
                outStmt = try inner.decode(DotStatement.self, forKey: .innerStatement)
            case .equalStmt:
                outStmt = try inner.decode(EqualStatement.self, forKey: .innerStatement)
            case .isDefinedStmt:
                outStmt = try inner.decode(IsDefinedStatement.self, forKey: .innerStatement)
            case .isUndefinedStmt:
                outStmt = try inner.decode(IsUndefinedStatement.self, forKey: .innerStatement)
            case .assignVarOnceStmt:
                outStmt = try inner.decode(AssignVarOnceStatement.self, forKey: .innerStatement)
            case .returnLocalStmt:
                outStmt = try inner.decode(ReturnLocalStatement.self, forKey: .innerStatement)
            //            default:
            //                // TODO This wouldn't get here if the type was unknown :/
            //                throw StatementError.unknown(anyStmt.type.rawValue)
            }

            // Set location properties shared by any statement type
            outStmt.location = anyStmt.inner.location

            out.append(outStmt)
        }

        self.statements = out
    }

    func encode(to encoder: any Encoder) throws {
        throw EncodingError.unsupported
    }
}

// AnyStatement represents the generic parts of a statement - its type and location.
// This is used for partial decoding of polymorphic statements preceding the concrete
// statement decoding.
struct AnyStatement: Codable, Equatable {
    enum KnownStatements: String, Codable {
        case callStmt = "CallStmt"
        case assignVarStmt = "AssignVarStmt"
        case makeObjectStmt = "MakeObjectStmt"
        case objectInsertStmt = "ObjectInsertStmt"
        case resultSetAddStmt = "ResultSetAddStmt"
        case dotStmt = "DotStmt"
        case equalStmt = "EqualStmt"
        case isDefinedStmt = "IsDefinedStmt"
        case isUndefinedStmt = "IsUndefinedStmt"
        case assignVarOnceStmt = "AssignVarOnceStmt"
        case resetLocalStmt = "ResetLocalStmt"
        case returnLocalStmt = "ReturnLocalStmt"
    }
    enum CodingKeys: String, CodingKey {
        case type
        case inner = "stmt"
    }
    var type: KnownStatements
    var inner: AnyInnerStatement
}

// AnyInnerStatement represents the generic stmt field, which should always contain location fields.
struct AnyInnerStatement: Codable, Equatable {
    var location: Location {
        Location(row: row, col: col, file: file)
    }

    var row: Int = 0
    var col: Int = 0
    var file: Int = 0
}

struct Location: Codable, Equatable {
    var row: Int = 0
    var col: Int = 0
    var file: Int = 0
}

enum StatementError: Error {
    case unknown(String)
}
enum EncodingError: Error {
    case unsupported
}

// Statement is implemented by each conctete statement type
protocol Statement: Sendable {
    // Location coordinates, shared by all concrete statement
    var location: Location { get set }

    // This will be used to implement Equatable dynamically between heterogenous statement types
    func isEqual(to other: any Statement) -> Bool
}

// -=-=-=-= CallStatement -=-=-=-=
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

struct Argument: Codable, Equatable {
    var type: String
    var value: Int
}

struct Funcs: Codable, Equatable {
    var funcs: [Func] = []
}

struct Func: Codable, Equatable {
    var name: String
    var path: [String]
    var params: [Int]
    var returnVar: Local
    var blocks: [Block]

    enum CodingKeys: String, CodingKey {
        case name
        case path
        case params
        case returnVar = "return"
        case blocks
    }
}
// -=-=-=-= End CallStatement -=-=-=-=

typealias Local = UInt32
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

struct Operand: Equatable {
    enum OpType: String, Codable, Equatable {
        case local = "local"
        case bool = "bool"
        case stringIndex = "string_index"
    }

    enum Value: Equatable {
        case number(Int)
        case bool(Bool)
        case stringIndex(Int)
    }

    var type: OpType
    var value: Value
}
// -=-=-=-= End Assign*Statement -=-=-=-=

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

struct ReturnLocalStmt: Statement, Codable, Equatable {
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

// Apparently, when defining a custom initializer in the struct, it suppresses generation
// of the default memberwise initializer, whereas when it is defined in an extension, we
// get both.
// ref: https://docs.swift.org/swift-book/documentation/the-swift-programming-language/initialization/#Memberwise-Initializers-for-Structure-Types
extension Operand: Codable {
    enum CodingKeys: String, CodingKey {
        case type
        case value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(OpType.self, forKey: .type)

        switch self.type {
        case .local:
            let v = try container.decode(Int.self, forKey: .value)
            self.value = Value.number(v)
        case .bool:
            let v = try container.decode(Bool.self, forKey: .value)
            self.value = Value.bool(v)
        case .stringIndex:
            let v = try container.decode(Int.self, forKey: .value)
            self.value = Value.stringIndex(v)
        }
    }

    func encode(to encoder: any Encoder) throws {
        throw EncodingError.unsupported
    }

}
