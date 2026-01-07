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

    /// Maximum local index used in this plan (computed via static analysis).
    /// Used to pre-allocate locals arrays to avoid runtime growth.
    public var maxLocal: Int = -1

    public init(name: String, blocks: [Block]) {
        self.name = name
        self.blocks = blocks
        self.maxLocal = -1
    }

    enum CodingKeys: String, CodingKey {
        case name
        case blocks
        // maxLocal is computed, not decoded
    }
}

public struct Block: Hashable, Sendable {
    public var statements: [Statement]

    public init(statements: [Statement]) {
        self.statements = statements
    }

    public mutating func appendStatement(_ stmt: Statement) {
        self.statements.append(stmt)
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

        var out: [Statement] = []
        while !peek.isAtEnd {
            let partial = try peek.decode(PartialStatement.self)
            let inner = try iter.nestedContainer(keyedBy: InnerCodingKeys.self)

            var wrapped: Statement

            switch partial.type {
            case .arrayAppendStmt:
                let stmt = try inner.decode(ArrayAppendStatement.self, forKey: .innerStatement)
                wrapped = .arrayAppendStmt(stmt)
            case .assignIntStmt:
                let stmt = try inner.decode(AssignIntStatement.self, forKey: .innerStatement)
                wrapped = .assignIntStmt(stmt)
            case .assignVarOnceStmt:
                let stmt = try inner.decode(AssignVarOnceStatement.self, forKey: .innerStatement)
                wrapped = .assignVarOnceStmt(stmt)
            case .assignVarStmt:
                let stmt = try inner.decode(AssignVarStatement.self, forKey: .innerStatement)
                wrapped = .assignVarStmt(stmt)
            case .blockStmt:
                let stmt = try inner.decode(BlockStatement.self, forKey: .innerStatement)
                wrapped = .blockStmt(stmt)
            case .breakStmt:
                let stmt = try inner.decode(BreakStatement.self, forKey: .innerStatement)
                wrapped = .breakStmt(stmt)
            case .callStmt:
                let stmt = try inner.decode(CallStatement.self, forKey: .innerStatement)
                wrapped = .callStmt(stmt)
            case .callDynamicStmt:
                let stmt = try inner.decode(CallDynamicStatement.self, forKey: .innerStatement)
                wrapped = .callDynamicStmt(stmt)
            case .dotStmt:
                let stmt = try inner.decode(DotStatement.self, forKey: .innerStatement)
                wrapped = .dotStmt(stmt)
            case .equalStmt:
                let stmt = try inner.decode(EqualStatement.self, forKey: .innerStatement)
                wrapped = .equalStmt(stmt)
            case .isArrayStmt:
                let stmt = try inner.decode(IsArrayStatement.self, forKey: .innerStatement)
                wrapped = .isArrayStmt(stmt)
            case .isDefinedStmt:
                let stmt = try inner.decode(IsDefinedStatement.self, forKey: .innerStatement)
                wrapped = .isDefinedStmt(stmt)
            case .isObjectStmt:
                let stmt = try inner.decode(IsObjectStatement.self, forKey: .innerStatement)
                wrapped = .isObjectStmt(stmt)
            case .isSetStmt:
                let stmt = try inner.decode(IsSetStatement.self, forKey: .innerStatement)
                wrapped = .isSetStmt(stmt)
            case .isUndefinedStmt:
                let stmt = try inner.decode(IsUndefinedStatement.self, forKey: .innerStatement)
                wrapped = .isUndefinedStmt(stmt)
            case .lenStmt:
                let stmt = try inner.decode(LenStatement.self, forKey: .innerStatement)
                wrapped = .lenStmt(stmt)
            case .makeArrayStmt:
                let stmt = try inner.decode(MakeArrayStatement.self, forKey: .innerStatement)
                wrapped = .makeArrayStmt(stmt)
            case .makeNullStmt:
                let stmt = try inner.decode(MakeNullStatement.self, forKey: .innerStatement)
                wrapped = .makeNullStmt(stmt)
            case .makeNumberIntStmt:
                let stmt = try inner.decode(MakeNumberIntStatement.self, forKey: .innerStatement)
                wrapped = .makeNumberIntStmt(stmt)
            case .makeNumberRefStmt:
                let stmt = try inner.decode(MakeNumberRefStatement.self, forKey: .innerStatement)
                wrapped = .makeNumberRefStmt(stmt)
            case .makeObjectStmt:
                let stmt = try inner.decode(MakeObjectStatement.self, forKey: .innerStatement)
                wrapped = .makeObjectStmt(stmt)
            case .makeSetStmt:
                let stmt = try inner.decode(MakeSetStatement.self, forKey: .innerStatement)
                wrapped = .makeSetStmt(stmt)
            case .nopStmt:
                let stmt = try inner.decode(NopStatement.self, forKey: .innerStatement)
                wrapped = .nopStmt(stmt)
            case .notEqualStmt:
                let stmt = try inner.decode(NotEqualStatement.self, forKey: .innerStatement)
                wrapped = .notEqualStmt(stmt)
            case .notStmt:
                let stmt = try inner.decode(NotStatement.self, forKey: .innerStatement)
                wrapped = .notStmt(stmt)
            case .objectInsertOnceStmt:
                let stmt = try inner.decode(ObjectInsertOnceStatement.self, forKey: .innerStatement)
                wrapped = .objectInsertOnceStmt(stmt)
            case .objectInsertStmt:
                let stmt = try inner.decode(ObjectInsertStatement.self, forKey: .innerStatement)
                wrapped = .objectInsertStmt(stmt)
            case .objectMergeStmt:
                let stmt = try inner.decode(ObjectMergeStatement.self, forKey: .innerStatement)
                wrapped = .objectMergeStmt(stmt)
            case .resetLocalStmt:
                let stmt = try inner.decode(ResetLocalStatement.self, forKey: .innerStatement)
                wrapped = .resetLocalStmt(stmt)
            case .resultSetAddStmt:
                let stmt = try inner.decode(ResultSetAddStatement.self, forKey: .innerStatement)
                wrapped = .resultSetAddStmt(stmt)
            case .returnLocalStmt:
                let stmt = try inner.decode(ReturnLocalStatement.self, forKey: .innerStatement)
                wrapped = .returnLocalStmt(stmt)
            case .scanStmt:
                let stmt = try inner.decode(ScanStatement.self, forKey: .innerStatement)
                wrapped = .scanStmt(stmt)
            case .setAddStmt:
                let stmt = try inner.decode(SetAddStatement.self, forKey: .innerStatement)
                wrapped = .setAddStmt(stmt)
            case .withStmt:
                let stmt = try inner.decode(WithStatement.self, forKey: .innerStatement)
                wrapped = .withStmt(stmt)
            }

            // Set location properties shared by any statement type using the setter
            wrapped.location = partial.inner.location

            out.append(wrapped)
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
    // NOTE: This must be kept in sync with the corresponding cases in Statement.
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

// Statement is an enum over all supported statements
public enum Statement: Sendable, Hashable {
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

    public var location: Location {
        get {
            switch self {
            case .arrayAppendStmt(let s):
                return s.location
            case .assignIntStmt(let s):
                return s.location
            case .assignVarOnceStmt(let s):
                return s.location
            case .assignVarStmt(let s):
                return s.location
            case .blockStmt(let s):
                return s.location
            case .breakStmt(let s):
                return s.location
            case .callDynamicStmt(let s):
                return s.location
            case .callStmt(let s):
                return s.location
            case .dotStmt(let s):
                return s.location
            case .equalStmt(let s):
                return s.location
            case .isArrayStmt(let s):
                return s.location
            case .isDefinedStmt(let s):
                return s.location
            case .isObjectStmt(let s):
                return s.location
            case .isSetStmt(let s):
                return s.location
            case .isUndefinedStmt(let s):
                return s.location
            case .lenStmt(let s):
                return s.location
            case .makeArrayStmt(let s):
                return s.location
            case .makeNullStmt(let s):
                return s.location
            case .makeNumberIntStmt(let s):
                return s.location
            case .makeNumberRefStmt(let s):
                return s.location
            case .makeObjectStmt(let s):
                return s.location
            case .makeSetStmt(let s):
                return s.location
            case .nopStmt(let s):
                return s.location
            case .notEqualStmt(let s):
                return s.location
            case .notStmt(let s):
                return s.location
            case .objectInsertOnceStmt(let s):
                return s.location
            case .objectInsertStmt(let s):
                return s.location
            case .objectMergeStmt(let s):
                return s.location
            case .resetLocalStmt(let s):
                return s.location
            case .resultSetAddStmt(let s):
                return s.location
            case .returnLocalStmt(let s):
                return s.location
            case .scanStmt(let s):
                return s.location
            case .setAddStmt(let s):
                return s.location
            case .withStmt(let s):
                return s.location
            case .unknown(let loc):
                return loc
            }
        }
        set {
            switch self {
            case .arrayAppendStmt(var s):
                s.location = newValue
                self = .arrayAppendStmt(s)
            case .assignIntStmt(var s):
                s.location = newValue
                self = .assignIntStmt(s)
            case .assignVarOnceStmt(var s):
                s.location = newValue
                self = .assignVarOnceStmt(s)
            case .assignVarStmt(var s):
                s.location = newValue
                self = .assignVarStmt(s)
            case .blockStmt(var s):
                s.location = newValue
                self = .blockStmt(s)
            case .breakStmt(var s):
                s.location = newValue
                self = .breakStmt(s)
            case .callDynamicStmt(var s):
                s.location = newValue
                self = .callDynamicStmt(s)
            case .callStmt(var s):
                s.location = newValue
                self = .callStmt(s)
            case .dotStmt(var s):
                s.location = newValue
                self = .dotStmt(s)
            case .equalStmt(var s):
                s.location = newValue
                self = .equalStmt(s)
            case .isArrayStmt(var s):
                s.location = newValue
                self = .isArrayStmt(s)
            case .isDefinedStmt(var s):
                s.location = newValue
                self = .isDefinedStmt(s)
            case .isObjectStmt(var s):
                s.location = newValue
                self = .isObjectStmt(s)
            case .isSetStmt(var s):
                s.location = newValue
                self = .isSetStmt(s)
            case .isUndefinedStmt(var s):
                s.location = newValue
                self = .isUndefinedStmt(s)
            case .lenStmt(var s):
                s.location = newValue
                self = .lenStmt(s)
            case .makeArrayStmt(var s):
                s.location = newValue
                self = .makeArrayStmt(s)
            case .makeNullStmt(var s):
                s.location = newValue
                self = .makeNullStmt(s)
            case .makeNumberIntStmt(var s):
                s.location = newValue
                self = .makeNumberIntStmt(s)
            case .makeNumberRefStmt(var s):
                s.location = newValue
                self = .makeNumberRefStmt(s)
            case .makeObjectStmt(var s):
                s.location = newValue
                self = .makeObjectStmt(s)
            case .makeSetStmt(var s):
                s.location = newValue
                self = .makeSetStmt(s)
            case .nopStmt(var s):
                s.location = newValue
                self = .nopStmt(s)
            case .notEqualStmt(var s):
                s.location = newValue
                self = .notEqualStmt(s)
            case .notStmt(var s):
                s.location = newValue
                self = .notStmt(s)
            case .objectInsertOnceStmt(var s):
                s.location = newValue
                self = .objectInsertOnceStmt(s)
            case .objectInsertStmt(var s):
                s.location = newValue
                self = .objectInsertStmt(s)
            case .objectMergeStmt(var s):
                s.location = newValue
                self = .objectMergeStmt(s)
            case .resetLocalStmt(var s):
                s.location = newValue
                self = .resetLocalStmt(s)
            case .resultSetAddStmt(var s):
                s.location = newValue
                self = .resultSetAddStmt(s)
            case .returnLocalStmt(var s):
                s.location = newValue
                self = .returnLocalStmt(s)
            case .scanStmt(var s):
                s.location = newValue
                self = .scanStmt(s)
            case .setAddStmt(var s):
                s.location = newValue
                self = .setAddStmt(s)
            case .withStmt(var s):
                s.location = newValue
                self = .withStmt(s)
            case .unknown:
                self = .unknown(newValue)
            }
        }
    }
}

extension Statement {
    // called while serializing trace events
    public var debugString: String {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            let data: Data

            switch self {
            case .arrayAppendStmt(let s): data = try encoder.encode(s)
            case .assignIntStmt(let s): data = try encoder.encode(s)
            case .assignVarOnceStmt(let s): data = try encoder.encode(s)
            case .assignVarStmt(let s): data = try encoder.encode(s)
            case .blockStmt(let s): data = try encoder.encode(s)
            case .breakStmt(let s): data = try encoder.encode(s)
            case .callDynamicStmt(let s): data = try encoder.encode(s)
            case .callStmt(let s): data = try encoder.encode(s)
            case .dotStmt(let s): data = try encoder.encode(s)
            case .equalStmt(let s): data = try encoder.encode(s)
            case .isArrayStmt(let s): data = try encoder.encode(s)
            case .isDefinedStmt(let s): data = try encoder.encode(s)
            case .isObjectStmt(let s): data = try encoder.encode(s)
            case .isSetStmt(let s): data = try encoder.encode(s)
            case .isUndefinedStmt(let s): data = try encoder.encode(s)
            case .lenStmt(let s): data = try encoder.encode(s)
            case .makeArrayStmt(let s): data = try encoder.encode(s)
            case .makeNullStmt(let s): data = try encoder.encode(s)
            case .makeNumberIntStmt(let s): data = try encoder.encode(s)
            case .makeNumberRefStmt(let s): data = try encoder.encode(s)
            case .makeObjectStmt(let s): data = try encoder.encode(s)
            case .makeSetStmt(let s): data = try encoder.encode(s)
            case .nopStmt(let s): data = try encoder.encode(s)
            case .notEqualStmt(let s): data = try encoder.encode(s)
            case .notStmt(let s): data = try encoder.encode(s)
            case .objectInsertOnceStmt(let s): data = try encoder.encode(s)
            case .objectInsertStmt(let s): data = try encoder.encode(s)
            case .objectMergeStmt(let s): data = try encoder.encode(s)
            case .resetLocalStmt(let s): data = try encoder.encode(s)
            case .resultSetAddStmt(let s): data = try encoder.encode(s)
            case .returnLocalStmt(let s): data = try encoder.encode(s)
            case .scanStmt(let s): data = try encoder.encode(s)
            case .setAddStmt(let s): data = try encoder.encode(s)
            case .withStmt(let s): data = try encoder.encode(s)
            case .unknown: return "<unknown>"
            }

            return String(data: data, encoding: .utf8) ?? "<invalid>"
        } catch {
            return "statement encoding failed: \(error)"
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

    /// Maximum local index used in this function (computed via static analysis).
    /// Includes params, return var, and all locals used in blocks.
    /// Used to pre-allocate locals arrays to avoid runtime growth.
    public var maxLocal: Int = -1

    public init(name: String, path: [String], params: [Local], returnVar: Local, blocks: [Block]) {
        self.name = name
        self.path = path
        self.params = params
        self.returnVar = returnVar
        self.blocks = blocks
        self.maxLocal = -1
    }

    enum CodingKeys: String, CodingKey {
        case name
        case path
        case params
        case returnVar = "return"
        case blocks
        // maxLocal is computed, not decoded
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
    public struct WasmABIVersion: Codable, Hashable, Sendable {
        public let version: Int
        public let minorVersion: Int

        enum CodingKeys: String, CodingKey {
            case version
            case minorVersion = "minor_version"
        }
    }

    public let builtins: [BuiltinFunc]
    // properties below are not actually used for validation by swift-opa (yet)
    public let allowNet: [String]?
    public let features: [String]?
    public let futureKeywords: [String]?
    public let wasmABIVersions: [WasmABIVersion]?

    enum CodingKeys: String, CodingKey {
        case builtins
        case allowNet = "allow_net"
        case features
        case futureKeywords = "future_keywords"
        case wasmABIVersions = "wasm_abi_versions"
    }
}
