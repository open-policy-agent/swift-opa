import Foundation

public struct Policy: Codable, Equatable, Sendable {
    public var staticData: Static?
    public var plans: Plans? = nil
    public var funcs: Funcs? = nil

    enum CodingKeys: String, CodingKey {
        case staticData = "static"
        case plans
        case funcs
    }
}

public struct Static: Codable, Equatable, Sendable {
    public var strings: [ConstString]?
    public var builtinFuncs: [BuiltinFunc]?
    public var files: [ConstString]?

    enum CodingKeys: String, CodingKey {
        case strings
        case builtinFuncs = "builtin_funcs"
        case files
    }
}

public struct ConstString: Codable, Equatable, Sendable {
    public var value: String
}

public struct Plans: Codable, Equatable, Sendable {
    public var plans: [Plan] = []
}

public struct Plan: Codable, Equatable, Sendable {
    public var name: String
    public var blocks: [Block]
}

public struct Block: Equatable, Sendable {
    public var statements: [any Statement]

    // Equatable, we need a custom implementation for dynamic dispatch
    // to our heterogenous extistential type instances (statements)
    public static func == (lhs: Self, rhs: Self) -> Bool {
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
    public init(from decoder: Decoder) throws {
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
                outStmt = try inner.decode(ArrayAppendStatement.self, forKey: .innerStatement)
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
                outStmt = try inner.decode(MakeNumberIntStatement.self, forKey: .innerStatement)
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

    public func encode(to encoder: any Encoder) throws {
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
public struct AnyInnerStatement: Codable, Equatable {
    public var location: Location {
        Location(row: row, col: col, file: file)
    }

    public var row: Int = 0
    public var col: Int = 0
    public var file: Int = 0
}

public struct Location: Codable, Equatable, Sendable {
    public var row: Int = 0
    public var col: Int = 0
    public var file: Int = 0
}

public enum StatementError: Error {
    case unknown(String)
}

public enum EncodingError: Error {
    case unsupported
}

// Statement is implemented by each conctete statement type
public protocol Statement: Sendable, Codable {
    // Location coordinates, shared by all concrete statement
    var location: Location { get set }

    // This will be used to implement Equatable dynamically between heterogenous statement types
    func isEqual(to other: any Statement) -> Bool
}

extension Statement {
    public var debugString: String {
        do {
            return String(data: try JSONEncoder().encode(self), encoding: .utf8)!
        } catch {
            return "\(type(of: self)) statement encoding failed"
        }
    }
}

public struct Funcs: Codable, Equatable, Sendable {
    public var funcs: [Func] = []
}

public struct Func: Codable, Equatable, Sendable {
    public var name: String
    public var path: [String]
    public var params: [Local]
    public var returnVar: Local
    public var blocks: [Block]

    enum CodingKeys: String, CodingKey {
        case name
        case path
        case params
        case returnVar = "return"
        case blocks
    }
}

public typealias Local = UInt32

public struct Operand: Equatable, Sendable {
    public enum OpType: String, Codable, Equatable, Sendable {
        case local = "local"
        case bool = "bool"
        case stringIndex = "string_index"
    }

    public enum Value: Equatable, Sendable {
        case localIndex(Int)
        case bool(Bool)
        case stringIndex(Int)
    }

    public var type: OpType
    public var value: Value

    public init(type: OpType, value: Value) {
        self.type = type
        self.value = value
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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(OpType.self, forKey: .type)

        switch self.type {
        case .local:
            let v = try container.decode(Int.self, forKey: .value)
            self.value = Value.localIndex(v)
        case .bool:
            let v = try container.decode(Bool.self, forKey: .value)
            self.value = Value.bool(v)
        case .stringIndex:
            let v = try container.decode(Int.self, forKey: .value)
            self.value = Value.stringIndex(v)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        throw EncodingError.unsupported
    }
}
