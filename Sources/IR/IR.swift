import AST
import Foundation

public struct Policy: Codable, Hashable, Sendable {
    public var staticData: Static? = nil
    public var plans: Plans? = nil
    public var funcs: Funcs? = nil

    public init(staticData: Static? = nil, plans: Plans? = nil, funcs: Funcs? = nil) {
        self.staticData = staticData
        self.plans = plans
        self.funcs = funcs
    }

    enum CodingKeys: String, CodingKey {
        case staticData = "static"
        case plans
        case funcs
    }
}

public struct Static: Codable, Hashable, Sendable {
    public var strings: [ConstString]?
    public var builtinFuncs: [BuiltinFunc]?
    public var files: [ConstString]?

    public init(strings: [ConstString]? = nil, builtinFuncs: [BuiltinFunc]? = nil, files: [ConstString]? = nil) {
        self.strings = strings
        self.builtinFuncs = builtinFuncs
        self.files = files
    }

    enum CodingKeys: String, CodingKey {
        case strings
        case builtinFuncs = "builtin_funcs"
        case files
    }
}

public struct BuiltinFunc: Codable, Hashable, Sendable {
    package var name: String
    package var decl: AST.FunctionTypeDecl
}

public struct ConstString: Codable, Hashable, Sendable {
    public var value: String

    public init(value: String) {
        self.value = value
    }
}

public struct Plans: Codable, Hashable, Sendable {
    public var plans: [Plan] = []

    public init(plans: [Plan]) {
        self.plans = plans
    }
}

public struct Plan: Codable, Hashable, Sendable {
    public var name: String
    public var blocks: [Block]

    public init(name: String, blocks: [Block]) {
        self.name = name
        self.blocks = blocks
    }
}

public struct Block: Hashable, Sendable {
    public var statements: [AnyStatement]

    public init(statements: [any Statement]) {
        self.statements = statements.map { AnyStatement($0) }
    }

    public mutating func appendStatement(_ stmt: any Statement) {
        self.statements.append(AnyStatement(stmt))
    }

    // Hashable, we need a custom implementation for dynamic dispatch
    // to our heterogenous extistential type instances (statements)
    public static func == (lhs: Self, rhs: Self) -> Bool {
        guard lhs.statements.count == rhs.statements.count else {
            return false
        }

        return zip(lhs.statements, rhs.statements).allSatisfy { $0 == $1 }
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

        var out: [AnyStatement] = []
        while !peek.isAtEnd {
            let partial = try peek.decode(PartialStatement.self)
            let inner = try iter.nestedContainer(keyedBy: InnerCodingKeys.self)

            var outStmt: any Statement

            switch partial.type {
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
            }

            // Set location properties shared by any statement type
            outStmt.location = partial.inner.location

            out.append(AnyStatement(outStmt))
        }

        self.statements = out
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode("block(stmt_count=\(statements.count))")
    }
}

// PartialStatement represents the generic parts of a statement - its type and location.
// This is used for partial decoding of polymorphic statements preceding the concrete
// statement decoding.
struct PartialStatement: Codable, Hashable {
    // KnownStatements are all allowed values for the "type" field of
    // serialized IR Statements (https://www.openpolicyagent.org/docs/latest/ir/#statements)
    // NOTE: This must be kept in sync with the corresponding cases in AnyStatement.
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

// AnyStatement is an enum over all supported statements
public enum AnyStatement: Sendable, Hashable {
    case arrayAppendStmt(ArrayAppendStatement)
    case assignIntStmt(AssignIntStatement)
    case assignVarOnceStmt(AssignVarOnceStatement)
    case assignVarStmt(AssignVarStatement)
    case blockStmt(BlockStatement)
    case breakStmt(BreakStatement)
    case callDynamicStmt(CallDynamicStatement)
    case callStmt(CallStatement)
    case dotStmt(DotStatement)
    case equalStmt(EqualStatement)
    case isArrayStmt(IsArrayStatement)
    case isDefinedStmt(IsDefinedStatement)
    case isObjectStmt(IsObjectStatement)
    case isSetStmt(IsSetStatement)
    case isUndefinedStmt(IsUndefinedStatement)
    case lenStmt(LenStatement)
    case makeArrayStmt(MakeArrayStatement)
    case makeNullStmt(MakeNullStatement)
    case makeNumberIntStmt(MakeNumberIntStatement)
    case makeNumberRefStmt(MakeNumberRefStatement)
    case makeObjectStmt(MakeObjectStatement)
    case makeSetStmt(MakeSetStatement)
    case nopStmt(NopStatement)
    case notEqualStmt(NotEqualStatement)
    case notStmt(NotStatement)
    case objectInsertOnceStmt(ObjectInsertOnceStatement)
    case objectInsertStmt(ObjectInsertStatement)
    case objectMergeStmt(ObjectMergeStatement)
    case resetLocalStmt(ResetLocalStatement)
    case resultSetAddStmt(ResultSetAddStatement)
    case returnLocalStmt(ReturnLocalStatement)
    case scanStmt(ScanStatement)
    case setAddStmt(SetAddStatement)
    case withStmt(WithStatement)

    case unknown(Location)

    // Constructor to wrap any concrete statement in an AnyStatment
    // NOTE: This is O(N) where N is the number of possible statements
    public init(_ v: any Statement) {
        switch v {
        case let stmt as IR.ArrayAppendStatement:
            self = .arrayAppendStmt(stmt)
        case let stmt as IR.AssignIntStatement:
            self = .assignIntStmt(stmt)
        case let stmt as IR.AssignVarOnceStatement:
            self = .assignVarOnceStmt(stmt)
        case let stmt as IR.AssignVarStatement:
            self = .assignVarStmt(stmt)
        case let stmt as IR.BlockStatement:
            self = .blockStmt(stmt)
        case let stmt as IR.BreakStatement:
            self = .breakStmt(stmt)
        case let stmt as IR.CallDynamicStatement:
            self = .callDynamicStmt(stmt)
        case let stmt as IR.CallStatement:
            self = .callStmt(stmt)
        case let stmt as IR.DotStatement:
            self = .dotStmt(stmt)
        case let stmt as IR.EqualStatement:
            self = .equalStmt(stmt)
        case let stmt as IR.IsArrayStatement:
            self = .isArrayStmt(stmt)
        case let stmt as IR.IsDefinedStatement:
            self = .isDefinedStmt(stmt)
        case let stmt as IR.IsObjectStatement:
            self = .isObjectStmt(stmt)
        case let stmt as IR.IsSetStatement:
            self = .isSetStmt(stmt)
        case let stmt as IR.IsUndefinedStatement:
            self = .isUndefinedStmt(stmt)
        case let stmt as IR.LenStatement:
            self = .lenStmt(stmt)
        case let stmt as IR.MakeArrayStatement:
            self = .makeArrayStmt(stmt)
        case let stmt as IR.MakeNullStatement:
            self = .makeNullStmt(stmt)
        case let stmt as IR.MakeNumberIntStatement:
            self = .makeNumberIntStmt(stmt)
        case let stmt as IR.MakeNumberRefStatement:
            self = .makeNumberRefStmt(stmt)
        case let stmt as IR.MakeObjectStatement:
            self = .makeObjectStmt(stmt)
        case let stmt as IR.MakeSetStatement:
            self = .makeSetStmt(stmt)
        case let stmt as IR.NotEqualStatement:
            self = .notEqualStmt(stmt)
        case let stmt as IR.NotStatement:
            self = .notStmt(stmt)
        case let stmt as IR.ObjectInsertOnceStatement:
            self = .objectInsertOnceStmt(stmt)
        case let stmt as IR.ObjectInsertStatement:
            self = .objectInsertStmt(stmt)
        case let stmt as IR.ObjectMergeStatement:
            self = .objectMergeStmt(stmt)
        case let stmt as IR.ResetLocalStatement:
            self = .resetLocalStmt(stmt)
        case let stmt as IR.ResultSetAddStatement:
            self = .resultSetAddStmt(stmt)
        case let stmt as IR.ReturnLocalStatement:
            self = .returnLocalStmt(stmt)
        case let stmt as IR.ScanStatement:
            self = .scanStmt(stmt)
        case let stmt as IR.SetAddStatement:
            self = .setAddStmt(stmt)
        case let stmt as IR.WithStatement:
            self = .withStmt(stmt)
        default:
            self = .unknown(v.location)
        }
    }

    public var statement: Statement? {
        switch self {
        case .arrayAppendStmt(let s):
            return s
        case .assignIntStmt(let s):
            return s
        case .assignVarOnceStmt(let s):
            return s
        case .assignVarStmt(let s):
            return s
        case .blockStmt(let s):
            return s
        case .breakStmt(let s):
            return s
        case .callDynamicStmt(let s):
            return s
        case .callStmt(let s):
            return s
        case .dotStmt(let s):
            return s
        case .equalStmt(let s):
            return s
        case .isArrayStmt(let s):
            return s
        case .isDefinedStmt(let s):
            return s
        case .isObjectStmt(let s):
            return s
        case .isSetStmt(let s):
            return s
        case .isUndefinedStmt(let s):
            return s
        case .lenStmt(let s):
            return s
        case .makeArrayStmt(let s):
            return s
        case .makeNullStmt(let s):
            return s
        case .makeNumberIntStmt(let s):
            return s
        case .makeNumberRefStmt(let s):
            return s
        case .makeObjectStmt(let s):
            return s
        case .makeSetStmt(let s):
            return s
        case .nopStmt(let s):
            return s
        case .notEqualStmt(let s):
            return s
        case .notStmt(let s):
            return s
        case .objectInsertOnceStmt(let s):
            return s
        case .objectInsertStmt(let s):
            return s
        case .objectMergeStmt(let s):
            return s
        case .resetLocalStmt(let s):
            return s
        case .resultSetAddStmt(let s):
            return s
        case .returnLocalStmt(let s):
            return s
        case .scanStmt(let s):
            return s
        case .setAddStmt(let s):
            return s
        case .withStmt(let s):
            return s
        case .unknown:
            return nil
        }
    }

    public var location: Location {
        switch self {
        case .unknown(let loc):
            return loc
        default:
            if let stmt = self as? Statement {
                return stmt.location
            }
            return Location()
        }
    }
}

// AnyInnerStatement represents the generic stmt field, which should always contain location fields.
public struct AnyInnerStatement: Codable, Hashable {
    public var row: Int = 0
    public var col: Int = 0
    public var file: Int = 0

    public var location: Location {
        Location(row: row, col: col, file: file)
    }
}

public struct Location: Codable, Hashable, Sendable {
    public var row: Int
    public var col: Int
    public var file: Int

    public init(row: Int = 0, col: Int = 0, file: Int = 0) {
        self.row = row
        self.col = col
        self.file = file
    }
}

// Statement is implemented by each conctete statement type
public protocol Statement: Sendable, Codable {
    // Location coordinates, shared by all concrete statement
    var location: Location { get set }
}

extension Statement {
    // called while serializing trace events
    public var debugString: String {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(self)
            return String(data: data, encoding: .utf8) ?? "<invalid>"
        } catch {
            return "\(type(of: self)) statement encoding failed: \(error)"
        }
    }
}

public struct Funcs: Codable, Hashable, Sendable {
    public var funcs: [Func]? = []

    public init(funcs: [Func]) {
        self.funcs = funcs
    }
}

public struct Func: Codable, Hashable, Sendable {
    public var name: String
    public var path: [String]
    public var params: [Local]
    public var returnVar: Local
    public var blocks: [Block]

    public init(name: String, path: [String], params: [Local], returnVar: Local, blocks: [Block]) {
        self.name = name
        self.path = path
        self.params = params
        self.returnVar = returnVar
        self.blocks = blocks
    }

    enum CodingKeys: String, CodingKey {
        case name
        case path
        case params
        case returnVar = "return"
        case blocks
    }
}

public typealias Local = UInt32

public struct Operand: Hashable, Sendable {
    public enum OpType: String, Codable, Hashable, Sendable {
        case local = "local"
        case bool = "bool"
        case stringIndex = "string_index"
    }

    public enum Value: Codable, Hashable, Sendable {
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
}

/// Represents an OPA capabilities definition, see https://www.openpolicyagent.org/docs/deployments#capabilities
///
/// Capabilities restrict which built-in functions and language features a policy
/// is allowed to use. When a policy depends on a builtin not listed in the
/// capabilities, `opa check` or `opa build` will fail. This enables reproducible
/// builds across OPA versions and allows programs embedding OPA to enforce a
/// controlled feature set.
public struct Capabilities: Codable, Hashable, Sendable {
    public let builtins: [BuiltinFunc]
    // properties below are not actually used for validation by swift-opa (yet)
    public let allowNet: Bool?
    public let features: [String]?
    public let futureKeywords: [String]?
    public let wasmABIVersions: [Int]?
    public let opaVersion: String?
}
