// TypeDecoder is used for partial decoding of polymorphic types
// to determine the concrete type, which is then decoded in the type member.
struct TypeDecoder: Decodable {
    let typeMarker: RegoTypeLabels
    let type: RegoTypeDecl

    private enum CodingKeys: String, CodingKey {
        case typeMarker = "type"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        typeMarker = try container.decode(RegoTypeLabels.self, forKey: .typeMarker)

        self.type =
            switch typeMarker {
            case .any:
                try RegoTypeDecl(from: AnyTypeDecl(from: decoder))
            case .array:
                try RegoTypeDecl(from: ArrayTypeDecl(from: decoder))
            case .boolean:
                try RegoTypeDecl(from: BooleanTypeDecl(from: decoder))
            case .function:
                try RegoTypeDecl(from: FunctionTypeDecl(from: decoder))
            case .null:
                try RegoTypeDecl(from: NullTypeDecl(from: decoder))
            case .number:
                try RegoTypeDecl(from: NumberTypeDecl(from: decoder))
            case .object:
                try RegoTypeDecl(from: ObjectTypeDecl(from: decoder))
            case .set:
                try RegoTypeDecl(from: SetTypeDecl(from: decoder))
            case .string:
                try RegoTypeDecl(from: StringTypeDecl(from: decoder))
            }
    }
}

extension AnyTypeDecl: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let argsDecoder = try container.decodeIfPresent(
            [TypeDecoder].self,
            forKey: .of)
        self.of = argsDecoder?.map { $0.type }
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
    }
}

extension ArrayTypeDecl: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let argsDecoder = try container.decodeIfPresent(
            [TypeDecoder].self,
            forKey: .staticItems)
        self.staticItems = argsDecoder?.map { $0.type }
        self.dynamicItems = try container.decodeIfPresent(TypeDecoder.self, forKey: .dynamicItems)?.type
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
    }

}

extension FunctionTypeDecl: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let argsDecoder = try container.decodeIfPresent(
            [TypeDecoder].self,
            forKey: .args)
        self.args = argsDecoder?.map { $0.type }
        self.result = try container.decodeIfPresent(TypeDecoder.self, forKey: .result)?.type
        self.variadic = try container.decodeIfPresent(TypeDecoder.self, forKey: .variadic)?.type
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
    }
}

extension StaticPropertyDecl: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decode(String.self, forKey: .key)
        value = try container.decode(TypeDecoder.self, forKey: .value).type
    }
}

extension DynamicPropertyDecl: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decode(TypeDecoder.self, forKey: .key).type
        value = try container.decode(TypeDecoder.self, forKey: .value).type
    }
}

extension SetTypeDecl: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let argsDecoder = try container.decodeIfPresent(
            TypeDecoder.self,
            forKey: .of
        )

        self.of = argsDecoder?.type ?? nil
        self.name = try container.decodeIfPresent(String.self, forKey: .name)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
    }
}

extension RegoTypeDecl: Encodable {
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .any(let a):
            try container.encode(a)
        case .array(let a):
            try container.encode(a)
        case .boolean(let b):
            try container.encode(b)
        case .function(let f):
            try container.encode(f)
        case .null(let n):
            try container.encode(n)
        case .number(let n):
            try container.encode(n)
        case .object(let o):
            try container.encode(o)
        case .set(let s):
            try container.encode(s)
        case .string(let s):
            try container.encode(s)
        default:
            try container.encode("<unknown>")
        }
    }
}
