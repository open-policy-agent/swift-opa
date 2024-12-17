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
    var strings: [ConstString]?
    var builtinFuncs: [BuiltinFunc]?
    var files: [ConstString]?

    enum CodingKeys: String, CodingKey {
        case strings
        case builtinFuncs = "builtin_funcs"
        case files
    }
}

struct ConstString: Codable, Equatable {
    var value: String
}

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
            case .arrayAppendStmt:
                outStmt = try inner.decode(AssignAppendStatement.self, forKey: .innerStatement)
            case .assignIntStmt:
                outStmt = try inner.decode(AssignIntStatement.self, forKey: .innerStatement)
            case .assignVarOnceStmt:
                outStmt = try inner.decode(AssignVarOnceStatement.self, forKey: .innerStatement)
            case .assignVarStmt:
                outStmt = try inner.decode(AssignVarStatement.self, forKey: .innerStatement)
            case .blockStmt:
                outStmt = try inner.decode(BlockStatement.self, forKey: .innerStatement)
            case .breakStmt:
                outStmt = try inner.decode(BreakStatement.self, forKey: .innerStatement)
            case .callStmt:
                outStmt = try inner.decode(CallStatement.self, forKey: .innerStatement)
            case .callDynamicStmt:
                outStmt = try inner.decode(CallDynamicStatement.self, forKey: .innerStatement)
            case .dotStmt:
                outStmt = try inner.decode(DotStatement.self, forKey: .innerStatement)
            case .equalStmt:
                outStmt = try inner.decode(EqualStatement.self, forKey: .innerStatement)
            case .isArrayStmt:
                outStmt = try inner.decode(IsArrayStatement.self, forKey: .innerStatement)
            case .isDefinedStmt:
                outStmt = try inner.decode(IsDefinedStatement.self, forKey: .innerStatement)
            case .isObjectStmt:
                outStmt = try inner.decode(IsObjectStatement.self, forKey: .innerStatement)
            case .isSetStmt:
                outStmt = try inner.decode(IsSetStatement.self, forKey: .innerStatement)
            case .isUndefinedStmt:
                outStmt = try inner.decode(IsUndefinedStatement.self, forKey: .innerStatement)
            case .lenStmt:
                outStmt = try inner.decode(LenStatement.self, forKey: .innerStatement)
            case .makeArrayStmt:
                outStmt = try inner.decode(MakeArrayStatement.self, forKey: .innerStatement)
            case .makeNullStmt:
                outStmt = try inner.decode(MakeNullStatement.self, forKey: .innerStatement)
            case .makeNumberIntStmt:
                outStmt = try inner.decode(MakeNumberStatement.self, forKey: .innerStatement)
            case .makeNumberRefStmt:
                outStmt = try inner.decode(MakeNumberRefStatement.self, forKey: .innerStatement)
            case .makeObjectStmt:
                outStmt = try inner.decode(MakeObjectStatement.self, forKey: .innerStatement)
            case .makeSetStmt:
                outStmt = try inner.decode(MakeSetStatement.self, forKey: .innerStatement)
            case .nopStmt:
                outStmt = try inner.decode(NopStatement.self, forKey: .innerStatement)
            case .notEqualStmt:
                outStmt = try inner.decode(NotEqualStatement.self, forKey: .innerStatement)
            case .notStmt:
                outStmt = try inner.decode(NotStatement.self, forKey: .innerStatement)
            case .objectInsertOnceStmt:
                outStmt = try inner.decode(ObjectInsertOnceStatement.self, forKey: .innerStatement)
            case .objectInsertStmt:
                outStmt = try inner.decode(ObjectInsertStatement.self, forKey: .innerStatement)
            case .objectMergeStmt:
                outStmt = try inner.decode(ObjectMergeStatement.self, forKey: .innerStatement)
            case .resetLocalStmt:
                outStmt = try inner.decode(ResetLocalStatement.self, forKey: .innerStatement)
            case .resultSetAddStmt:
                outStmt = try inner.decode(ResultSetAddStatement.self, forKey: .innerStatement)
            case .returnLocalStmt:
                outStmt = try inner.decode(ReturnLocalStatement.self, forKey: .innerStatement)
            case .scanStmt:
                outStmt = try inner.decode(ScanStatement.self, forKey: .innerStatement)
            case .setAddStmt:
                outStmt = try inner.decode(SetAddStatement.self, forKey: .innerStatement)
            case .withStmt:
                outStmt = try inner.decode(WithStatement.self, forKey: .innerStatement)
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
        case arrayAppendStmt = "ArrayAppendStmt"
        case assignIntStmt = "AssignIntStmt"
        case assignVarOnceStmt = "AssignVarOnceStmt"
        case assignVarStmt = "AssignVarStmt"
        case blockStmt = "BlockStmt"
        case breakStmt = "BreakStmt"
        case callDynamicStmt = "CallDynamicStmt"
        case callStmt = "CallStmt"
        case dotStmt = "DotStmt"
        case equalStmt = "EqualStmt"
        case isArrayStmt = "IsArrayStmt"
        case isDefinedStmt = "IsDefinedStmt"
        case isObjectStmt = "IsObjectStmt"
        case isSetStmt = "IsSetStmt"
        case isUndefinedStmt = "IsUndefinedStmt"
        case lenStmt = "LenStmt"
        case makeArrayStmt = "MakeArrayStmt"
        case makeNullStmt = "MakeNullStmt"
        case makeNumberIntStmt = "MakeNumberIntStmt"
        case makeNumberRefStmt = "MakeNumberRefStmt"
        case makeObjectStmt = "MakeObjectStmt"
        case makeSetStmt = "MakeSetStmt"
        case nopStmt = "NopStmt"
        case notEqualStmt = "NotEqualStmt"
        case notStmt = "NotStmt"
        case objectInsertOnceStmt = "ObjectInsertOnceStmt"
        case objectInsertStmt = "ObjectInsertStmt"
        case objectMergeStmt = "ObjectMergeStmt"
        case resetLocalStmt = "ResetLocalStmt"
        case resultSetAddStmt = "ResultSetAddStmt"
        case returnLocalStmt = "ReturnLocalStmt"
        case scanStmt = "ScanStmt"
        case setAddStmt = "SetAddStmt"
        case withStmt = "WithStmt"
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

typealias Local = UInt32

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
