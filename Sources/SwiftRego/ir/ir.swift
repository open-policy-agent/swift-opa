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

struct Block: Equatable {
    var statements: [any Statement]

    // TODO TODO
    static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.statements.count == rhs.statements.count else {
            return false
        }

        //        for i in 0..<lhs.statements.count {
        //            guard lhs.statements[i] == rhs.statements[i] else {
        //                return false
        //            }
        //        }

        // TODO

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
protocol Statement: Codable, Equatable {
    // Location coordinates, shared by all concrete statement
    var location: Location { get set }
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
    var returnVar: Int
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
}

struct ResultSetAddStatement: Statement, Codable, Equatable {
    var location: Location = Location()

    enum CodingKeys: String, CodingKey {
        case value
    }
    var value: Local
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
