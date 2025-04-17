import Foundation

public enum RegoTypeLabels: String, Codable, Sendable {
    case any = "any"
    case array = "array"
    case boolean = "boolean"
    case function = "function"
    case null = "null"
    case number = "number"
    case object = "object"
    case set = "set"
    case string = "string"
}

public struct AnyTypeDecl: Encodable, Equatable, Sendable {
    public let type = RegoTypeLabels.any
    public let name: String?
    public let description: String?
    public let of: [RegoTypeDecl]?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case type
        case of
    }

    // Represents an unnamed "any" type.
    public init() {
        self.name = nil
        self.description = nil
        self.of = nil
    }

    public init(name: String?, description: String?, of: [RegoTypeDecl]? = nil) {
        self.name = name
        self.description = description
        self.of = of
    }
}

public struct ArrayTypeDecl: Encodable, Equatable, Sendable {
    public let type = RegoTypeLabels.array
    public let name: String?
    public let description: String?
    public let staticItems: [RegoTypeDecl]?
    public let dynamicItems: RegoTypeDecl?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case type
        case staticItems = "static"
        case dynamicItems = "dynamic"
    }

    // Represents an array of any types
    public init() {
        self.name = nil
        self.description = nil
        self.staticItems = nil
        self.dynamicItems = nil
    }

    public init(
        name: String? = nil,
        description: String? = nil,
        staticItems: [RegoTypeDecl]? = nil,
        dynamicItems: RegoTypeDecl? = nil
    ) {
        self.name = name
        self.description = description
        self.staticItems = staticItems
        self.dynamicItems = dynamicItems
    }
}

public struct BooleanTypeDecl: Codable, Equatable, Sendable {
    public let type = RegoTypeLabels.boolean
    public let name: String?
    public let description: String?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case type
    }
}

public struct FunctionTypeDecl: Encodable, Equatable, Sendable {
    public let type = RegoTypeLabels.function
    public let name: String?
    public let description: String?

    public var args: [RegoTypeDecl]?
    public var result: RegoTypeDecl?
    public var variadic: RegoTypeDecl?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case type
        case args
        case result
        case variadic
    }

    public init(
        name: String? = nil,
        description: String? = nil,
        args: [RegoTypeDecl]? = nil,
        result: RegoTypeDecl? = nil,
        variadic: RegoTypeDecl? = nil
    ) {
        self.name = name
        self.description = description
        self.args = args
        self.result = result
        self.variadic = variadic
    }
}

public struct NullTypeDecl: Codable, Equatable, Sendable {
    public let type = RegoTypeLabels.null
    public let name: String?
    public let description: String?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case type
    }

    public init(name: String? = nil, description: String? = nil) {
        self.name = name
        self.description = description
    }
}

public struct NumberTypeDecl: Codable, Equatable, Sendable {
    public let type = RegoTypeLabels.number
    public let name: String?
    public let description: String?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case type
    }

    public init(name: String? = nil, description: String? = nil) {
        self.name = name
        self.description = description
    }
}

public struct ObjectTypeDecl: Codable, Equatable, Sendable {
    public let type = RegoTypeLabels.object
    public let name: String?
    public let description: String?
    public var staticProps: [StaticPropertyDecl]?
    public var dynamicProps: DynamicPropertyDecl?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case type
        case staticProps = "static"
        case dynamicProps = "dynamic"
    }

    public init(
        name: String? = nil,
        description: String? = nil,
        staticProps: [StaticPropertyDecl]? = nil,
        dynamicProps: DynamicPropertyDecl? = nil
    ) {
        self.name = name
        self.description = description
        self.staticProps = staticProps
        self.dynamicProps = dynamicProps
    }
}

public struct StaticPropertyDecl: Encodable, Equatable, Sendable {
    public let key: String
    public let value: RegoTypeDecl

    enum CodingKeys: String, CodingKey {
        case key
        case value
    }

    public init(key: String, value: RegoTypeDecl) {
        self.key = key
        self.value = value
    }
}

public struct DynamicPropertyDecl: Encodable, Equatable, Sendable {
    public let key: RegoTypeDecl
    public let value: RegoTypeDecl

    enum CodingKeys: String, CodingKey {
        case key
        case value
    }

    public init(key: RegoTypeDecl, value: RegoTypeDecl) {
        self.key = key
        self.value = value
    }
}

public struct SetTypeDecl: Encodable, Equatable, Sendable {
    public let type = RegoTypeLabels.set
    public let name: String?
    public let description: String?
    public let of: RegoTypeDecl?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case type
        case of
    }

    public init(name: String? = nil, description: String? = nil, of: RegoTypeDecl? = nil) {
        self.name = name
        self.description = description
        self.of = of
    }
}

public struct StringTypeDecl: Codable, Equatable, Sendable {
    public let type = RegoTypeLabels.string
    public let name: String?
    public let description: String?

    enum CodingKeys: String, CodingKey {
        case name
        case description
        case type
    }

    // Represents an unnamed string type
    public init() {
        self.name = nil
        self.description = nil
    }

    public init(name: String? = nil, description: String? = nil) {
        self.name = name
        self.description = description
    }
}

public indirect enum RegoTypeDecl: Equatable, Sendable {
    case any(AnyTypeDecl)
    case array(ArrayTypeDecl)
    case boolean(BooleanTypeDecl)
    case function(FunctionTypeDecl)
    case null(NullTypeDecl)
    case number(NumberTypeDecl)
    case object(ObjectTypeDecl)
    case set(SetTypeDecl)
    case string(StringTypeDecl)
    case unknown(String)

    public init(from: Any) {
        switch from {
        case let a as AnyTypeDecl:
            self = .any(a)
        case let array as ArrayTypeDecl:
            self = .array(array)
        case let bool as BooleanTypeDecl:
            self = .boolean(bool)
        case let funcType as FunctionTypeDecl:
            self = .function(funcType)
        case let null as NullTypeDecl:
            self = .null(null)
        case let num as NumberTypeDecl:
            self = .number(num)
        case let obj as ObjectTypeDecl:
            self = .object(obj)
        case let set as SetTypeDecl:
            self = .set(set)
        case let str as StringTypeDecl:
            self = .string(str)
        default:
            self = .unknown("<unknown>")
        }
    }

    public enum Error: Swift.Error {
        case unknownType(String)
    }
}
